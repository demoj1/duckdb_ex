defmodule DuckdbEx.ConnectionTest do
  use ExUnit.Case

  # Reference: duckdb-python/tests/fast/test_connection.py

  describe "connect/2" do
    test "connects to memory database" do
      assert {:ok, conn} = DuckdbEx.Connection.connect(:memory)
      assert is_pid(conn)
      DuckdbEx.Connection.close(conn)
    end

    test "connects with read_only option" do
      assert {:ok, conn} = DuckdbEx.Connection.connect(:memory, read_only: true)
      assert is_pid(conn)
      DuckdbEx.Connection.close(conn)
    end
  end

  describe "execute/3" do
    setup do
      {:ok, conn} = DuckdbEx.Connection.connect(:memory)
      on_exit(fn -> DuckdbEx.Connection.close(conn) end)
      {:ok, conn: conn}
    end

    test "executes SELECT 1", %{conn: conn} do
      assert {:ok, _result} = DuckdbEx.Connection.execute(conn, "SELECT 1")
    end

    test "executes CREATE TABLE", %{conn: conn} do
      assert {:ok, _result} =
               DuckdbEx.Connection.execute(conn, "CREATE TABLE test (id INTEGER, name VARCHAR)")
    end

    test "executes INSERT", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE test (id INTEGER, name VARCHAR)")

      assert {:ok, _result} =
               DuckdbEx.Connection.execute(conn, "INSERT INTO test VALUES (1, 'Alice')")
    end

    test "executes SELECT from table", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE test (id INTEGER, name VARCHAR)")
      DuckdbEx.Connection.execute(conn, "INSERT INTO test VALUES (1, 'Alice')")
      assert {:ok, _result} = DuckdbEx.Connection.execute(conn, "SELECT * FROM test")
    end
  end

  describe "close/1" do
    test "closes connection successfully" do
      {:ok, conn} = DuckdbEx.Connection.connect(:memory)
      assert :ok = DuckdbEx.Connection.close(conn)
    end
  end
end
