defmodule DuckdbEx.Port do
  @moduledoc """
  Manages the DuckDB CLI process using erlexec.

  This module provides a simple wrapper around the DuckDB CLI binary,
  managing it as an OS process via erlexec. Communication happens through
  JSON-formatted commands and responses.

  ## Architecture

  Instead of using Rust NIFs, we use the DuckDB CLI in JSON mode to
  communicate with the database:

      Elixir Process <--> erlexec <--> DuckDB CLI (JSON mode)

  This approach is simpler and avoids the complexity of NIF development
  while still providing full DuckDB functionality.
  """

  use GenServer
  require Logger

  @type t :: pid()

  ## Client API

  @doc """
  Starts a DuckDB process.

  ## Options

    * `:database` - Path to database file or `:memory:` (default: `:memory:`)
    * `:read_only` - Open database in read-only mode (default: `false`)

  ## Examples

      {:ok, port} = DuckdbEx.Port.start_link()
      {:ok, port} = DuckdbEx.Port.start_link(database: "/path/to/db.duckdb")
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Executes a SQL query and returns the result.

  ## Examples

      DuckdbEx.Port.execute(port, "SELECT 1 as num, 'hello' as text")
      #=> {:ok, %{"columns" => ["num", "text"], "rows" => [[1, "hello"]]}}
  """
  @spec execute(t(), String.t()) :: {:ok, map()} | {:error, term()}
  def execute(port, sql) when is_binary(sql) do
    GenServer.call(port, {:execute, sql}, :infinity)
  end

  @doc """
  Stops the DuckDB process.
  """
  @spec stop(t()) :: :ok
  def stop(port) when is_pid(port) do
    if Process.alive?(port) do
      GenServer.stop(port, :normal)
    else
      :ok
    end
  end

  def stop(_port), do: :ok

  ## Server Callbacks

  @impl true
  def init(opts) do
    # Start erlexec if not already running
    # Run as root and set effective user to root (required in Docker)
    case :exec.start_link([{:root, true}, {:user, "root"}]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> throw(error)
    end

    database = Keyword.get(opts, :database, ":memory:")
    read_only = Keyword.get(opts, :read_only, false)

    db_path =
      case database do
        :memory -> ":memory:"
        path when is_binary(path) -> path
      end

    # Build DuckDB command
    # Use JSON mode for easier parsing
    cmd_args = build_command_args(db_path, read_only)

    # Start DuckDB CLI process with erlexec
    exec_opts = [
      :stdin,
      :stdout,
      :stderr,
      :monitor
    ]

    case :exec.run_link(cmd_args, exec_opts) do
      {:ok, exec_pid, os_pid} ->
        Logger.debug("Started DuckDB process: exec_pid=#{inspect(exec_pid)}, os_pid=#{os_pid}")

        state = %{
          exec_pid: exec_pid,
          os_pid: os_pid,
          database: db_path,
          buffer: ""
        }

        {:ok, state}

      {:error, reason} ->
        {:stop, {:failed_to_start_duckdb, reason}}
    end
  end

  @impl true
  def handle_call({:execute, sql}, from, state) do
    # Send SQL to DuckDB process
    # Ensure the SQL ends with a semicolon and newline
    command = ensure_terminated(sql)

    case :exec.send(state.os_pid, command) do
      :ok ->
        # Store the caller to respond later when output arrives
        # Set a timeout to handle cases where DuckDB doesn't respond
        new_state =
          Map.put(state, :pending_call, {from, sql, System.monotonic_time(:millisecond)})

        # Schedule timeout check (1 second)
        Process.send_after(self(), :check_timeout, 1000)
        {:noreply, new_state}

      error ->
        {:reply, {:error, error}, state}
    end
  end

  defp ensure_terminated(sql) do
    sql = String.trim(sql)
    sql = if String.ends_with?(sql, ";"), do: sql, else: sql <> ";"
    sql <> "\n"
  end

  @impl true
  def handle_info({:stdout, os_pid, data}, %{os_pid: os_pid} = state) do
    # Accumulate output
    buffer = state.buffer <> data

    # DuckDB in JSON mode outputs:
    # - SELECT queries: One JSON array like [{"col":val}, ...]
    # - DDL statements (CREATE, DROP): No output
    # We detect completion when we have a complete JSON array ending with ]\n
    case Map.get(state, :pending_call) do
      {from, _sql, timestamp} ->
        time_elapsed = System.monotonic_time(:millisecond) - timestamp

        # Check if we have a complete JSON response (ends with ]\n or ]<whitespace>)
        # OR if enough time has passed for DDL statements that produce no output
        trimmed = String.trim(buffer)
        has_complete_json = String.ends_with?(trimmed, "]")
        is_timeout = time_elapsed > 50

        if (has_complete_json and String.contains?(buffer, "\n")) or is_timeout do
          result = parse_output(buffer)
          GenServer.reply(from, {:ok, result})
          new_state = state |> Map.put(:buffer, "") |> Map.delete(:pending_call)
          {:noreply, new_state}
        else
          # Continue accumulating
          {:noreply, %{state | buffer: buffer}}
        end

      nil ->
        {:noreply, %{state | buffer: buffer}}
    end
  end

  def handle_info({:stderr, os_pid, data}, %{os_pid: os_pid} = state) do
    Logger.error("DuckDB stderr: #{data}")

    case Map.get(state, :pending_call) do
      {from, _sql, _timestamp} ->
        # Parse error message and create appropriate exception
        error = parse_error(data)
        GenServer.reply(from, {:error, error})
        new_state = state |> Map.put(:buffer, "") |> Map.delete(:pending_call)
        {:noreply, new_state}

      nil ->
        {:noreply, state}
    end
  end

  def handle_info(:check_timeout, state) do
    # Check if we have a pending call that's timed out
    case Map.get(state, :pending_call) do
      {from, _sql, timestamp} ->
        time_elapsed = System.monotonic_time(:millisecond) - timestamp

        if time_elapsed > 1000 do
          # Timeout - respond with whatever we have or empty result
          result = parse_output(state.buffer)
          GenServer.reply(from, {:ok, result})
          new_state = state |> Map.put(:buffer, "") |> Map.delete(:pending_call)
          {:noreply, new_state}
        else
          {:noreply, state}
        end

      nil ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, os_pid, :process, exec_pid, reason}, state)
      when os_pid == state.os_pid and exec_pid == state.exec_pid do
    Logger.info("DuckDB process terminated: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  def handle_info(msg, state) do
    Logger.debug("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  ## Private Functions

  defp build_command_args(database, read_only) do
    # Use DuckDB in JSON mode with line-mode output for easier parsing
    # -json flag outputs results as newline-delimited JSON
    # -batch flag runs in batch mode (non-interactive)
    # -init /dev/null prevents loading .duckdbrc
    duckdb_path = System.get_env("DUCKDB_PATH", "/usr/local/bin/duckdb")
    args = [duckdb_path, "-json", "-batch", "-init", "/dev/null"]

    args = if read_only, do: args ++ ["-readonly"], else: args
    args = args ++ [database]

    args
  end

  defp parse_output(""), do: %{rows: [], row_count: 0}

  defp parse_output(data) when is_binary(data) do
    # DuckDB -json mode outputs a JSON array for each query result
    # Format: [{"col1": val1, "col2": val2}, ...]
    # For DDL/DML statements (CREATE, INSERT, etc.), there may be no output
    trimmed = String.trim(data)

    if trimmed == "" do
      # Empty response (e.g., DDL statement)
      %{rows: [], row_count: 0}
    else
      # Parse the JSON array
      case Jason.decode(trimmed) do
        {:ok, rows} when is_list(rows) ->
          # Successfully parsed JSON array
          %{rows: rows, row_count: length(rows)}

        {:ok, row} when is_map(row) ->
          # Single row returned as object (shouldn't happen but handle it)
          %{rows: [row], row_count: 1}

        {:error, reason} ->
          # JSON parse error - log and return empty
          Logger.warning(
            "Failed to parse DuckDB output: #{inspect(reason)}, data: #{inspect(trimmed)}"
          )

          %{rows: [], row_count: 0}

        _ ->
          %{rows: [], row_count: 0}
      end
    end
  end

  defp parse_error(data) when is_binary(data) do
    # Try to extract error type and message from DuckDB error output
    # DuckDB errors typically look like: "Error: <type>: <message>"
    case Regex.run(~r/Error: ([^:]+): (.+)/, data) do
      [_, type, message] ->
        error_string = "#{String.trim(type)}:#{String.trim(message)}"
        DuckdbEx.Exceptions.from_error_string(error_string)

      _ ->
        # Fallback to generic error
        %DuckdbEx.Exceptions.Error{message: String.trim(data)}
    end
  end
end
