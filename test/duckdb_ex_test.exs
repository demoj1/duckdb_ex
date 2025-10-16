defmodule DuckdbExTest do
  use ExUnit.Case
  doctest DuckdbEx

  describe "connect/2" do
    test "connects to memory database" do
      assert {:ok, conn} = DuckdbEx.connect(:memory)
      assert is_pid(conn)
      DuckdbEx.close(conn)
    end

    test "connect with default arguments" do
      assert {:ok, conn} = DuckdbEx.connect()
      assert is_pid(conn)
      DuckdbEx.close(conn)
    end
  end

  describe "execute/2" do
    setup do
      {:ok, conn} = DuckdbEx.connect()
      on_exit(fn -> DuckdbEx.close(conn) end)
      {:ok, conn: conn}
    end

    test "executes a simple query", %{conn: conn} do
      assert {:ok, _result} = DuckdbEx.execute(conn, "SELECT 1")
    end
  end

  describe "close/1" do
    test "closes a connection" do
      {:ok, conn} = DuckdbEx.connect()
      assert :ok = DuckdbEx.close(conn)
    end
  end
end
