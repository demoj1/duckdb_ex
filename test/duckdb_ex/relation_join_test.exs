defmodule DuckdbEx.RelationJoinTest do
  use ExUnit.Case

  # Reference: duckdb-python/tests/fast/test_relation_api.py (join tests)

  setup do
    {:ok, conn} = DuckdbEx.Connection.connect(:memory)
    on_exit(fn -> DuckdbEx.Connection.close(conn) end)

    # Create test tables
    DuckdbEx.Connection.execute(conn, """
      CREATE TABLE users (
        id INTEGER,
        name VARCHAR
      )
    """)

    DuckdbEx.Connection.execute(conn, """
      CREATE TABLE orders (
        order_id INTEGER,
        user_id INTEGER,
        amount DECIMAL
      )
    """)

    DuckdbEx.Connection.execute(conn, """
      INSERT INTO users VALUES
        (1, 'Alice'),
        (2, 'Bob'),
        (3, 'Charlie')
    """)

    DuckdbEx.Connection.execute(conn, """
      INSERT INTO orders VALUES
        (101, 1, 100.00),
        (102, 1, 200.00),
        (103, 2, 150.00)
    """)

    {:ok, conn: conn}
  end

  describe "join/3 - inner join" do
    test "inner join with condition", %{conn: conn} do
      users = DuckdbEx.Connection.table(conn, "users")
      orders = DuckdbEx.Connection.table(conn, "orders")

      relation = DuckdbEx.Relation.join(users, orders, "users.id = orders.user_id")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      # Alice has 2 orders, Bob has 1 order, Charlie has no orders
      assert length(rows) == 3
      assert Enum.any?(rows, &(&1["name"] == "Alice" and &1["amount"] == 100.00))
      assert Enum.any?(rows, &(&1["name"] == "Alice" and &1["amount"] == 200.00))
      assert Enum.any?(rows, &(&1["name"] == "Bob" and &1["amount"] == 150.00))
    end

    test "inner join filters out non-matching rows", %{conn: conn} do
      users = DuckdbEx.Connection.table(conn, "users")
      orders = DuckdbEx.Connection.table(conn, "orders")

      relation = DuckdbEx.Relation.join(users, orders, "users.id = orders.user_id")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      # Charlie should not appear (no orders)
      refute Enum.any?(rows, &(&1["name"] == "Charlie"))
    end

    test "inner join can be chained with other operations", %{conn: conn} do
      users = DuckdbEx.Connection.table(conn, "users")
      orders = DuckdbEx.Connection.table(conn, "orders")

      relation =
        users
        |> DuckdbEx.Relation.join(orders, "users.id = orders.user_id")
        |> DuckdbEx.Relation.filter("amount > 100")
        |> DuckdbEx.Relation.order("amount DESC")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      assert length(rows) == 2
      assert hd(rows)["amount"] == 200.00
    end
  end

  describe "join/3 - left join" do
    test "left join includes all rows from left relation", %{conn: conn} do
      users = DuckdbEx.Connection.table(conn, "users")
      orders = DuckdbEx.Connection.table(conn, "orders")

      relation = DuckdbEx.Relation.join(users, orders, "users.id = orders.user_id", type: :left)

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      # Should include Alice (2 rows), Bob (1 row), and Charlie (1 row with NULL order)
      assert length(rows) == 4

      # Charlie should appear with NULL order values
      charlie_row = Enum.find(rows, &(&1["name"] == "Charlie"))
      assert charlie_row != nil
      assert charlie_row["order_id"] == nil
    end

    test "left join with filter on left table", %{conn: conn} do
      users = DuckdbEx.Connection.table(conn, "users")
      orders = DuckdbEx.Connection.table(conn, "orders")

      relation =
        users
        |> DuckdbEx.Relation.filter("name != 'Charlie'")
        |> DuckdbEx.Relation.join(orders, "users.id = orders.user_id", type: :left)

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      # Only Alice and Bob
      assert length(rows) == 3
      refute Enum.any?(rows, &(&1["name"] == "Charlie"))
    end
  end

  describe "join/3 - right join" do
    test "right join includes all rows from right relation", %{conn: conn} do
      users = DuckdbEx.Connection.table(conn, "users")
      orders = DuckdbEx.Connection.table(conn, "orders")

      relation = DuckdbEx.Relation.join(users, orders, "users.id = orders.user_id", type: :right)

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      # All 3 orders should be included
      assert length(rows) == 3
      # All rows should have order data
      assert Enum.all?(rows, &(&1["order_id"] != nil))
    end
  end

  describe "join/3 - outer join" do
    test "outer join includes all rows from both relations", %{conn: conn} do
      # Create tables with non-overlapping data
      DuckdbEx.Connection.execute(conn, "CREATE TABLE left_table (id INT, value VARCHAR)")
      DuckdbEx.Connection.execute(conn, "CREATE TABLE right_table (id INT, value VARCHAR)")

      DuckdbEx.Connection.execute(conn, "INSERT INTO left_table VALUES (1, 'a'), (2, 'b')")
      DuckdbEx.Connection.execute(conn, "INSERT INTO right_table VALUES (2, 'B'), (3, 'C')")

      left = DuckdbEx.Connection.table(conn, "left_table")
      right = DuckdbEx.Connection.table(conn, "right_table")

      relation =
        DuckdbEx.Relation.join(left, right, "left_table.id = right_table.id", type: :outer)

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      # Should have rows for id=1 (left only), id=2 (both), id=3 (right only)
      assert length(rows) == 3
    end
  end

  describe "cross/1 - cross join" do
    test "cross join returns cartesian product", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, "CREATE TABLE a (x INT)")
      DuckdbEx.Connection.execute(conn, "CREATE TABLE b (y INT)")

      DuckdbEx.Connection.execute(conn, "INSERT INTO a VALUES (1), (2)")
      DuckdbEx.Connection.execute(conn, "INSERT INTO b VALUES (3), (4)")

      rel_a = DuckdbEx.Connection.table(conn, "a")
      rel_b = DuckdbEx.Connection.table(conn, "b")

      relation = DuckdbEx.Relation.cross(rel_a, rel_b)

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      # 2 x 2 = 4 rows
      assert length(rows) == 4
      # Each combination should exist
      assert Enum.any?(rows, &(&1["x"] == 1 and &1["y"] == 3))
      assert Enum.any?(rows, &(&1["x"] == 1 and &1["y"] == 4))
      assert Enum.any?(rows, &(&1["x"] == 2 and &1["y"] == 3))
      assert Enum.any?(rows, &(&1["x"] == 2 and &1["y"] == 4))
    end
  end

  describe "join with aggregation" do
    test "aggregate after join", %{conn: conn} do
      users = DuckdbEx.Connection.table(conn, "users")
      orders = DuckdbEx.Connection.table(conn, "orders")

      relation =
        users
        |> DuckdbEx.Relation.join(orders, "users.id = orders.user_id")
        |> DuckdbEx.Relation.aggregate(
          ["sum(amount) as total_amount", "count(*) as order_count"],
          group_by: ["name"]
        )
        |> DuckdbEx.Relation.order("total_amount DESC")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      # Alice: 100 + 200 = 300, Bob: 150
      assert length(rows) == 2

      alice_row = Enum.find(rows, &(&1["name"] == "Alice"))
      assert alice_row["total_amount"] == 300.00
      assert alice_row["order_count"] == 2

      bob_row = Enum.find(rows, &(&1["name"] == "Bob"))
      assert bob_row["total_amount"] == 150.00
      assert bob_row["order_count"] == 1
    end
  end

  describe "multiple joins" do
    test "chain multiple joins", %{conn: conn} do
      DuckdbEx.Connection.execute(conn, """
        CREATE TABLE products (
          product_id INTEGER,
          product_name VARCHAR
        )
      """)

      DuckdbEx.Connection.execute(conn, """
        CREATE TABLE order_items (
          order_id INTEGER,
          product_id INTEGER,
          quantity INTEGER
        )
      """)

      DuckdbEx.Connection.execute(conn, """
        INSERT INTO products VALUES (1, 'Widget'), (2, 'Gadget')
      """)

      DuckdbEx.Connection.execute(conn, """
        INSERT INTO order_items VALUES
          (101, 1, 5),
          (101, 2, 3),
          (102, 1, 2)
      """)

      orders = DuckdbEx.Connection.table(conn, "orders")
      order_items = DuckdbEx.Connection.table(conn, "order_items")
      products = DuckdbEx.Connection.table(conn, "products")

      relation =
        orders
        |> DuckdbEx.Relation.join(order_items, "orders.order_id = order_items.order_id")
        |> DuckdbEx.Relation.join(products, "order_items.product_id = products.product_id")

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      # Order 101 has 2 items, Order 102 has 1 item
      assert length(rows) == 3
      assert Enum.any?(rows, &(&1["product_name"] == "Widget"))
      assert Enum.any?(rows, &(&1["product_name"] == "Gadget"))
    end
  end
end
