defmodule DuckdbEx.Port do
  @moduledoc """
  Manages the DuckDB CLI process using erlexec.

  This module provides a simple wrapper around the DuckDB CLI binary,
  managing it as an OS process via erlexec. Communication happens through
  JSON-formatted commands and responses.

  ## Architecture

  Instead of using Rust NIFs, we use the DuckDB CLI in JSON mode to
  communicate with the database:

      Elixir Process <--> DuckDB CLI (JSON mode)

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
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts)

  @doc """
  Executes a SQL query and returns the result.

  ## Examples

      DuckdbEx.Port.execute(port, "SELECT 1 as num, 'hello' as text")
      #=> {:ok, %{"columns" => ["num", "text"], "rows" => [[1, "hello"]]}}
  """
  @spec execute(t(), String.t()) :: {:ok, map()} | {:error, term()}
  def execute(port, sql) when is_binary(sql), do: GenServer.call(port, {:execute, sql}, :infinity)

  @doc """
  Stops the DuckDB process.
  """
  @spec stop(t()) :: :ok
  def stop(port) when is_pid(port), do: Process.alive?(port) && GenServer.stop(port, :normal) || :ok
  def stop(_port), do: :ok

  ## Server Callbacks

  @impl true
  def init(opts) do
    database = Keyword.get(opts, :database, ":memory:")
    read_only = Keyword.get(opts, :read_only, false)

    db_path =
      case database do
        :memory -> ":memory:"
        path when is_binary(path) -> path
      end

    [duckdb_path | cmd_args] = build_command_args(db_path, read_only)

    try do
      port = Port.open({:spawn_executable, duckdb_path}, [{:args, cmd_args}, :stderr_to_stdout])
      Port.monitor(port)
      Logger.debug("Started DuckDB process: port=#{inspect(port)}")
      state = %{
          port: port,
          database: db_path,
          buffer: <<>>,
          error_buffer: <<>>
        }

        {:ok, state}
    catch
      {l, r} -> {l, r}
    end
  end

  @completion_marker "__DUCKDB_COMPLETE__"

  @impl true
  def handle_call({:execute, sql}, from, state) do
    command = build_command_with_marker(sql)

    Logger.debug("QUERY: #{command}")

    case Port.command(state.port, command) do
      true ->
        # Store the caller to respond later when output arrives
        new_state = Map.put(state, :pending_call, {from, sql})
        {:noreply, new_state}

      false ->
        {:reply, {:error, :command_return_false}, state}
    end
  end

  defp build_command_with_marker(sql) do
    sql = String.trim(sql)
    sql = if String.ends_with?(sql, ";"), do: sql, else: sql <> ";"
    # Add marker query to signal completion
    sql <> "\nSELECT '#{@completion_marker}' as __status__;\n"
  end

  @impl true
  def handle_info({port, {:data, data}}, state) when port == state.port do
    Logger.debug("INCOME: #{data}")

    new_state = Map.put(state, :buffer, state.buffer <> to_string(data))
    (String.contains?(new_state.buffer, @completion_marker) || Regex.match?(~r/please ROLLBACK/, new_state.buffer)) && (
      {:noreply, process_result(new_state)}
    ) || (
      {:noreply, new_state}
    )
  end

  def process_result(%{pending_call: {from, _}} = state) do
    string_data = to_string(state.buffer)

    cond do
      Regex.match?(~r/please ROLLBACK/, string_data) ->
        GenServer.reply(from, {:error, :rollback})

      (r = Regex.run(~r/\w+ Error: (.*)?/, string_data)) != nil ->
        GenServer.reply(from, {:error, List.first(r)})

      true ->
        state.error_buffer != "" && (
          error = parse_error(state.error_buffer)
          GenServer.reply(from, {:error, error})
        ) || (
          result = parse_and_strip_marker(state.buffer)
          GenServer.reply(from, {:ok, result})
        )
    end

    new_state =
      state
      |> Map.put(:buffer, "")
      |> Map.put(:error_buffer, "")
      |> Map.delete(:pending_call)

    new_state
  end

  def handle_info({:DOWN, _ref, :port, port, reason}, state)
      when state.port == port do
    Logger.info("DuckDB process terminated: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  def handle_info(msg, state) do
    Logger.debug("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp build_command_args(database, read_only) do
    duckdb_path = System.get_env("DUCKDB_PATH", nil) || (
      # Windows must die
      {output, 0} = System.shell("whereis duckdb")
      String.split(output) |> Enum.at(1)
    )
    args = [duckdb_path, "-json", "-batch", "-init", "/dev/null"]

    args = if read_only, do: args ++ ["-readonly"], else: args
    args = args ++ [database]

    args
  end

  defp parse_and_strip_marker(data) when is_binary(data) do
    lines = String.split(data, "\n", trim: true)
    user_result_lines = Enum.reject(lines, &String.contains?(&1, @completion_marker))
    user_data = Enum.join(user_result_lines, "\n")

    parse_output(user_data)
  end

  defp parse_output(""), do: %{rows: [], row_count: 0}

  defp parse_output(data) when is_binary(data) do
    trimmed = String.trim(data)

    if trimmed == "" do
      %{rows: [], row_count: 0}
    else
      case Jason.decode(trimmed) do
        {:ok, rows} when is_list(rows) ->
          %{rows: rows, row_count: length(rows)}

        {:ok, row} when is_map(row) ->
          %{rows: [row], row_count: 1}

        {:error, reason} ->
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
