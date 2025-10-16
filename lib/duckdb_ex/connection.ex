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
