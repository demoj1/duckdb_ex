defmodule DuckdbEx.Connection do
  @moduledoc """
  DuckDB connection management.

  This module provides the primary interface to DuckDB databases, mirroring the
  functionality of the Python DuckDBPyConnection class.

  Reference: duckdb-python/src/duckdb_py/include/duckdb_python/pyconnection/pyconnection.hpp

  ## Overview

  A connection represents an active session with a DuckDB database using the
  DuckDB CLI managed through erlexec. Connections can be:
  - In-memory (`:memory:`)
  - Persistent (file path)
  - Read-only or read-write

  ## Examples

      # Connect to an in-memory database
      {:ok, conn} = DuckdbEx.Connection.connect(:memory)

      # Execute a query
      {:ok, result} = DuckdbEx.Connection.execute(conn, "SELECT 1")

      # Close connection
      DuckdbEx.Connection.close(conn)
  """

  alias DuckdbEx.Port
  alias DuckdbEx.Result
  alias DuckdbEx.Relation

  @type t :: Port.t()

  @doc """
  Opens a connection to a DuckDB database.

  ## Parameters

  - `database` - Database path or `:memory:` for in-memory database
  - `opts` - Connection options (keyword list)
    - `:read_only` - Open in read-only mode (default: false)
    - `:config` - Database configuration map (for future use)

  ## Returns

  - `{:ok, conn}` - Successfully opened connection
  - `{:error, exception}` - Connection failed

  ## Examples

      {:ok, conn} = DuckdbEx.Connection.connect(:memory)
      {:ok, conn} = DuckdbEx.Connection.connect("/path/to/db.duckdb")
      {:ok, conn} = DuckdbEx.Connection.connect(:memory, read_only: true)

  Reference: duckdb.connect() in Python
  """
  @spec connect(String.t() | :memory, keyword()) :: {:ok, t()} | {:error, term()}
  def connect(database \\ :memory, opts \\ []) do
    port_opts = Keyword.put(opts, :database, database)
    Port.start_link(port_opts)
  end

  @doc """
  Executes a SQL query.

  ## Parameters

  - `conn` - The connection
  - `sql` - SQL query string
  - `params` - Query parameters (not yet implemented)

  ## Returns

  - `{:ok, result}` - Query executed successfully
  - `{:error, exception}` - Query failed

  ## Examples

      {:ok, result} = DuckdbEx.Connection.execute(conn, "SELECT 1")

  Reference: DuckDBPyConnection.execute() in Python
  """
  @spec execute(t(), String.t(), list()) :: {:ok, term()} | {:error, term()}
  def execute(conn, sql, _params \\ []) when is_binary(sql) do
    Port.execute(conn, sql)
  end

  @doc """
  Fetches all rows from a query result.

  This is a convenience function that executes a query and returns all rows.

  ## Parameters

  - `conn` - The connection
  - `sql` - SQL query string

  ## Returns

  - `{:ok, rows}` - List of row maps
  - `{:error, exception}` - Query failed

  ## Examples

      {:ok, rows} = DuckdbEx.Connection.fetch_all(conn, "SELECT * FROM users")

  Reference: DuckDBPyConnection.execute().fetchall() in Python
  """
  @spec fetch_all(t(), String.t()) :: {:ok, list(map())} | {:error, term()}
  def fetch_all(conn, sql) do
    case execute(conn, sql) do
      {:ok, result} -> {:ok, Result.fetch_all(result)}
      error -> error
    end
  end

  @doc """
  Fetches one row from a query result.

  This is a convenience function that executes a query and returns the first row.

  ## Parameters

  - `conn` - The connection
  - `sql` - SQL query string

  ## Returns

  - `{:ok, row}` - Row map or nil
  - `{:error, exception}` - Query failed

  ## Examples

      {:ok, row} = DuckdbEx.Connection.fetch_one(conn, "SELECT * FROM users LIMIT 1")

  Reference: DuckDBPyConnection.execute().fetchone() in Python
  """
  @spec fetch_one(t(), String.t()) :: {:ok, map() | nil} | {:error, term()}
  def fetch_one(conn, sql) do
    case execute(conn, sql) do
      {:ok, result} -> {:ok, Result.fetch_one(result)}
      error -> error
    end
  end

  @doc """
  Creates a relation from a SQL query.

  Returns a lazy relation that can be composed with other operations before
  execution. The SQL is not executed until a fetch operation is called.

  ## Parameters

  - `conn` - The connection
  - `sql` - SQL query string

  ## Returns

  A `%DuckdbEx.Relation{}` struct

  ## Examples

      # Create relation (not executed yet)
      relation = DuckdbEx.Connection.sql(conn, "SELECT * FROM users")

      # Chain operations
      result = relation
      |> DuckdbEx.Relation.filter("age > 25")
      |> DuckdbEx.Relation.fetch_all()

  Reference: DuckDBPyConnection.sql() in Python
  """
  @spec sql(t(), String.t()) :: Relation.t()
  def sql(conn, sql) when is_binary(sql) do
    Relation.new(conn, sql)
  end

  @doc """
  Creates a relation from a table or view name.

  Returns a lazy relation representing the entire table or view. The table
  is not queried until a fetch operation is called.

  ## Parameters

  - `conn` - The connection
  - `table_name` - Name of the table or view

  ## Returns

  A `%DuckdbEx.Relation{}` struct

  ## Examples

      # Create relation from table
      relation = DuckdbEx.Connection.table(conn, "users")

      # Chain operations
      active_users = relation
      |> DuckdbEx.Relation.filter("status = 'active'")
      |> DuckdbEx.Relation.fetch_all()

  Reference: DuckDBPyConnection.table() in Python
  """
  @spec table(t(), String.t()) :: Relation.t()
  def table(conn, table_name) when is_binary(table_name) do
    sql = "SELECT * FROM #{table_name}"
    Relation.new(conn, sql)
  end

  @doc """
  Begins a transaction.

  Starts a new transaction on the connection. All subsequent queries will be
  executed within the transaction context until commit or rollback is called.

  ## Parameters

  - `conn` - The connection

  ## Returns

  - `{:ok, result}` - Transaction started successfully
  - `{:error, exception}` - Failed to start transaction

  ## Examples

      {:ok, conn} = DuckdbEx.Connection.connect(:memory)
      {:ok, _} = DuckdbEx.Connection.begin(conn)
      {:ok, _} = DuckdbEx.Connection.execute(conn, "INSERT INTO users VALUES (1, 'Alice')")
      {:ok, _} = DuckdbEx.Connection.commit(conn)

  Reference: DuckDBPyConnection.begin() in Python
  """
  @spec begin(t()) :: {:ok, term()} | {:error, term()}
  def begin(conn) do
    execute(conn, "BEGIN TRANSACTION")
  end

  @doc """
  Commits the current transaction.

  Commits all changes made within the current transaction, making them permanent.

  ## Parameters

  - `conn` - The connection

  ## Returns

  - `{:ok, result}` - Transaction committed successfully
  - `{:error, exception}` - Failed to commit transaction

  ## Examples

      {:ok, _} = DuckdbEx.Connection.begin(conn)
      {:ok, _} = DuckdbEx.Connection.execute(conn, "INSERT INTO users VALUES (1, 'Alice')")
      {:ok, _} = DuckdbEx.Connection.commit(conn)

  Reference: DuckDBPyConnection.commit() in Python
  """
  @spec commit(t()) :: {:ok, term()} | {:error, term()}
  def commit(conn) do
    execute(conn, "COMMIT")
  end

  @doc """
  Rolls back the current transaction.

  Reverts all changes made within the current transaction.

  ## Parameters

  - `conn` - The connection

  ## Returns

  - `{:ok, result}` - Transaction rolled back successfully
  - `{:error, exception}` - Failed to rollback transaction

  ## Examples

      {:ok, _} = DuckdbEx.Connection.begin(conn)
      {:ok, _} = DuckdbEx.Connection.execute(conn, "INSERT INTO users VALUES (1, 'Alice')")
      {:ok, _} = DuckdbEx.Connection.rollback(conn)

  Reference: DuckDBPyConnection.rollback() in Python
  """
  @spec rollback(t()) :: {:ok, term()} | {:error, term()}
  def rollback(conn) do
    execute(conn, "ROLLBACK")
  end

  @doc """
  Executes a function within a managed transaction.

  This is the recommended way to use transactions. The function is executed
  within a transaction context. If the function completes successfully, the
  transaction is committed. If an exception is raised or an error occurs, the
  transaction is automatically rolled back.

  ## Parameters

  - `conn` - The connection
  - `fun` - A function that takes the connection as an argument

  ## Returns

  - `{:ok, result}` - Transaction completed successfully, returns the function's result
  - `{:error, exception}` - Transaction failed or was rolled back

  ## Examples

      # Successful transaction
      {:ok, result} = DuckdbEx.Connection.transaction(conn, fn conn ->
        {:ok, _} = DuckdbEx.Connection.execute(conn, "INSERT INTO users VALUES (1, 'Alice')")
        {:ok, _} = DuckdbEx.Connection.execute(conn, "INSERT INTO users VALUES (2, 'Bob')")
        :success
      end)

      # Transaction with automatic rollback on error
      {:error, _} = DuckdbEx.Connection.transaction(conn, fn conn ->
        {:ok, _} = DuckdbEx.Connection.execute(conn, "INSERT INTO users VALUES (1, 'Alice')")
        raise "Something went wrong!"
      end)

  Reference: Similar to Python context manager pattern with DuckDB transactions
  """
  @spec transaction(t(), (t() -> term())) :: {:ok, term()} | {:error, term()}
  def transaction(conn, fun) when is_function(fun, 1) do
    case begin(conn) do
      {:ok, _} ->
        try do
          result = fun.(conn)

          # Check if the result is an error tuple - if so, rollback
          case result do
            {:error, _} = error ->
              rollback(conn)
              error

            _ ->
              case commit(conn) do
                {:ok, _} -> {:ok, result}
                error -> error
              end
          end
        rescue
          exception ->
            rollback(conn)
            {:error, exception}
        end

      error ->
        error
    end
  end

  @doc """
  Creates a checkpoint.

  Forces a checkpoint of the write-ahead log (WAL) to the database file.
  This ensures all changes are persisted to disk.

  ## Parameters

  - `conn` - The connection

  ## Returns

  - `{:ok, result}` - Checkpoint created successfully
  - `{:error, exception}` - Failed to create checkpoint

  ## Examples

      {:ok, _} = DuckdbEx.Connection.checkpoint(conn)

  Reference: DuckDBPyConnection.checkpoint() in Python
  """
  @spec checkpoint(t()) :: {:ok, term()} | {:error, term()}
  def checkpoint(conn) do
    execute(conn, "CHECKPOINT")
  end

  @doc """
  Closes the database connection.

  After closing, the connection should not be used for any operations.

  ## Parameters

  - `conn` - The connection to close

  ## Returns

  - `:ok`

  ## Examples

      {:ok, conn} = DuckdbEx.Connection.connect(:memory)
      :ok = DuckdbEx.Connection.close(conn)

  Reference: DuckDBPyConnection.close() in Python
  """
  @spec close(t()) :: :ok
  def close(conn) do
    Port.stop(conn)
  end
end
