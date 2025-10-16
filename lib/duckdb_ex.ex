defmodule DuckdbEx do
  @moduledoc """
  DuckDB Elixir Client - A 100% faithful port of the Python duckdb client.

  This library provides Elixir bindings to DuckDB, an in-process SQL OLAP database
  management system. It mirrors the Python duckdb API for compatibility and ease of migration.

  Reference: duckdb-python for API compatibility

  ## Quick Start

      # Connect to an in-memory database
      {:ok, conn} = DuckdbEx.connect()

      # Execute a query
      {:ok, result} = DuckdbEx.execute(conn, "SELECT 42 as answer")

      # Close the connection
      DuckdbEx.close(conn)

  ## Architecture

  This implementation uses the DuckDB CLI binary managed through erlexec,
  providing a simpler alternative to NIF-based approaches while maintaining
  full functionality.

  ## Modules

  - `DuckdbEx.Connection` - Connection management
  - `DuckdbEx.Port` - DuckDB CLI process management
  - `DuckdbEx.Exceptions` - Exception types

  ## Future Modules (to be implemented)

  - `DuckdbEx.Relation` - Lazy query builder
  - `DuckdbEx.Result` - Result handling
  - `DuckdbEx.Type` - Type system
  """

  alias DuckdbEx.Connection

  @doc """
  Opens a connection to a DuckDB database.

  This is a convenience function that delegates to `DuckdbEx.Connection.connect/2`.

  ## Examples

      {:ok, conn} = DuckdbEx.connect()
      {:ok, conn} = DuckdbEx.connect(:memory)
      {:ok, conn} = DuckdbEx.connect("/path/to/db.duckdb")
  """
  defdelegate connect(database \\ :memory, opts \\ []), to: Connection

  @doc """
  Executes a SQL query.

  This is a convenience function that delegates to `DuckdbEx.Connection.execute/3`.

  ## Examples

      {:ok, conn} = DuckdbEx.connect()
      {:ok, result} = DuckdbEx.execute(conn, "SELECT 1")
  """
  defdelegate execute(conn, sql, params \\ []), to: Connection

  @doc """
  Closes a database connection.

  This is a convenience function that delegates to `DuckdbEx.Connection.close/1`.

  ## Examples

      {:ok, conn} = DuckdbEx.connect()
      :ok = DuckdbEx.close(conn)
  """
  defdelegate close(conn), to: Connection
end
