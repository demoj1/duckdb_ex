# TDD Implementation Plan for DuckDB-Elixir

## Overview

The document shows that only ~3% of the Python API is implemented (15 out of ~500 APIs). I'll create a phased TDD approach focusing on the highest-impact features first, following the Red-Green-Refactor cycle for each feature.

## TDD Methodology

For each feature, we'll follow:

1.  **RED**: Write failing tests first (based on Python duckdb behavior)
2.  **GREEN**: Implement minimal code to pass tests
3.  **REFACTOR**: Improve implementation while keeping tests green
4.  **DOCUMENT**: Add comprehensive docs and examples

---

## Phase 1: Core Relation API (Critical Priority)

*Estimated: 4-6 weeks | Impact: Highest*

### Why First?

The Relation API is the most distinctive feature of DuckDB and enables lazy, composable query building. This is what users expect when migrating from Python.

### Test Structure

#### 1.1 Module Setup - `test/duckdb_ex/relation_test.exs`

```elixir
# Create test file following existing pattern
# Reference: duckdb-python/tests/fast/test_relation_api.py
```

#### 1.2 TDD Cycle for Basic Operations

**Test 1.2.1: Relation Creation from SQL**

```elixir
describe "sql/2" do
  test "creates relation from SQL query", %{conn: conn} do
    # RED: Write test first
    relation = DuckdbEx.Connection.sql(conn, "SELECT 1 as x")
    assert %DuckdbEx.Relation{} = relation

    # Should not execute immediately (lazy)
    result = DuckdbEx.Relation.execute(relation)
    assert {:ok, %{rows: [%{"x" => 1}]}} = result
  end
end
```

**Test 1.2.2: Table References**

```elixir
describe "table/2" do
  test "creates relation from table name", %{conn: conn} do
    DuckdbEx.execute(conn, "CREATE TABLE test (id INT, name VARCHAR)")
    DuckdbEx.execute(conn, "INSERT INTO test VALUES (1, 'Alice')")

    relation = DuckdbEx.Connection.table(conn, "test")
    assert %DuckdbEx.Relation{} = relation
    {:ok, result} = DuckdbEx.Relation.fetch_all(relation)
    assert length(result) == 1
  end
end
```

**Test 1.2.3: Project (SELECT)**

```elixir
describe "project/2" do
  test "selects specific columns", %{conn: conn} do
    rel = conn
    |> DuckdbEx.Connection.sql("SELECT 1 as x, 2 as y, 3 as z")
    |> DuckdbEx.Relation.project(["x", "y"])

    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)
    assert [%{"x" => 1, "y" => 2}] = rows
    refute Map.has_key?(hd(rows), "z")
  end

  test "projects with expressions" do
    rel = conn
    |> DuckdbEx.Connection.table("test")
    |> DuckdbEx.Relation.project(["id", "upper(name) as upper_name"])

    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)
    assert %{"upper_name" => "ALICE"} = hd(rows)
  end
end
```

**Test 1.2.4: Filter (WHERE)**

```elixir
describe "filter/2" do
  test "filters rows with simple condition", %{conn: conn} do
    DuckdbEx.execute(conn, "CREATE TABLE nums (x INT)")
    DuckdbEx.execute(conn, "INSERT INTO nums SELECT * FROM range(10)")

    rel = conn
    |> DuckdbEx.Connection.table("nums")
    |> DuckdbEx.Relation.filter("x > 5")

    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)
    assert length(rows) == 4  # 6,7,8,9
  end

  test "chains multiple filters" do
    rel = conn
    |> DuckdbEx.Connection.table("nums")
    |> DuckdbEx.Relation.filter("x > 5")
    |> DuckdbEx.Relation.filter("x < 8")

    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)
    assert length(rows) == 2  # 6,7
  end
end
```

**Test 1.2.5: Limit and Order**

```elixir
describe "limit/2 and order/2" do
  test "limits result rows", %{conn: conn} do
    rel = conn
    |> DuckdbEx.Connection.sql("SELECT * FROM range(100)")
    |> DuckdbEx.Relation.limit(5)

    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)
    assert length(rows) == 5
  end

  test "orders results", %{conn: conn} do
    rel = conn
    |> DuckdbEx.Connection.sql("SELECT * FROM (VALUES (3), (1), (2)) t(x)")
    |> DuckdbEx.Relation.order("x ASC")

    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)
    assert [%{"x" => 1}, %{"x" => 2}, %{"x" => 3}] = rows
  end

  test "combines order and limit", %{conn: conn} do
    rel = conn
    |> DuckdbEx.Connection.sql("SELECT * FROM range(10)")
    |> DuckdbEx.Relation.order("range DESC")
    |> DuckdbEx.Relation.limit(3)

    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)
    assert [%{"range" => 9}, %{"range" => 8}, %{"range" => 7}] = rows
  end
end
```

#### 1.3 TDD Cycle for Aggregations

**Test 1.3.1: Basic Aggregates**

```elixir
describe "aggregate/3" do
  test "count aggregate", %{conn: conn} do
    rel = conn
    |> DuckdbEx.Connection.sql("SELECT * FROM range(10)")
    |> DuckdbEx.Relation.aggregate("count(*)", "total")

    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)
    assert [%{"total" => 10}] = rows
  end

  test "sum aggregate", %{conn: conn} do
    rel = conn
    |> DuckdbEx.Connection.sql("SELECT * FROM range(5)")
    |> DuckdbEx.Relation.aggregate("sum(range)", "total")

    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)
    assert [%{"total" => 10}] = rows  # 0+1+2+3+4
  end

  test "multiple aggregates", %{conn: conn} do
    rel = conn
    |> DuckdbEx.Connection.sql("SELECT * FROM range(5)")
    |> DuckdbEx.Relation.aggregate(["sum(range) as total", "avg(range) as average"])

    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)
    assert [%{"total" => 10, "average" => 2.0}] = rows
  end

  test "group by aggregation", %{conn: conn} do
    DuckdbEx.execute(conn, """
      CREATE TABLE sales (product VARCHAR, amount INT)
    """)
    DuckdbEx.execute(conn, """
      INSERT INTO sales VALUES ('A', 100), ('B', 200), ('A', 150)
    """)

    rel = conn
    |> DuckdbEx.Connection.table("sales")
    |> DuckdbEx.Relation.aggregate("sum(amount)", "total", group_by: ["product"])

    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)
    assert length(rows) == 2
    assert Enum.find(rows, &(&1["product"] == "A"))["total"] == 250
  end
end
```

#### 1.4 TDD Cycle for Joins

**Test 1.4.1: Inner Join**

```elixir
describe "join/3" do
  setup %{conn: conn} do
    DuckdbEx.execute(conn, "CREATE TABLE users (id INT, name VARCHAR)")
    DuckdbEx.execute(conn, "CREATE TABLE orders (user_id INT, amount INT)")
    DuckdbEx.execute(conn, "INSERT INTO users VALUES (1, 'Alice'), (2, 'Bob')")
    DuckdbEx.execute(conn, "INSERT INTO orders VALUES (1, 100), (1, 200), (2, 150)")
    :ok
  end

  test "inner join", %{conn: conn} do
    users = DuckdbEx.Connection.table(conn, "users")
    orders = DuckdbEx.Connection.table(conn, "orders")

    rel = DuckdbEx.Relation.join(users, orders, "users.id = orders.user_id")

    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)
    assert length(rows) == 3
  end

  test "left join", %{conn: conn} do
    users = DuckdbEx.Connection.table(conn, "users")
    orders = DuckdbEx.Connection.table(conn, "orders")

    rel = DuckdbEx.Relation.join(users, orders, "users.id = orders.user_id", type: :left)

    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)
    assert length(rows) >= 3  # All users, some with nil orders
  end
end
```

#### 1.5 TDD Cycle for Relation Properties

**Test 1.5.1: Metadata Access**

```elixir
describe "relation metadata" do
  test "columns/1 returns column names", %{conn: conn} do
    rel = DuckdbEx.Connection.sql(conn, "SELECT 1 as x, 2 as y")
    assert ["x", "y"] = DuckdbEx.Relation.columns(rel)
  end

  test "types/1 returns column types", %{conn: conn} do
    rel = DuckdbEx.Connection.sql(conn, "SELECT 1 as x, 'hello' as y")
    types = DuckdbEx.Relation.types(rel)
    assert %{"x" => "INTEGER", "y" => "VARCHAR"} = types
  end

  test "shape/1 returns dimensions", %{conn: conn} do
    rel = conn
    |> DuckdbEx.Connection.sql("SELECT * FROM range(10)")
    |> DuckdbEx.Relation.project(["range"])

    assert {10, 1} = DuckdbEx.Relation.shape(rel)
  end
end
```

### Implementation Strategy for Phase 1

1.  Create `lib/duckdb_ex/relation.ex`
    *   Define `%DuckdbEx.Relation{}` struct
    *   Store SQL generation state (not executed yet)
    *   Implement lazy evaluation
2.  SQL Generation Approach
    *   Build SQL incrementally as operations are chained
    *   Execute only when `fetch_*` or `execute` is called
    *   Use CTE (Common Table Expressions) for complex queries
3.  Example Implementation Structure

```elixir
defmodule DuckdbEx.Relation do
  defstruct [:conn, :sql, :alias]

  # Constructor
  def new(conn, sql, alias \\ nil) do
    %__MODULE__{conn: conn, sql: sql, alias: alias}
  end

  # Lazy operations - build SQL
  def project(relation, columns) do
    # Build SELECT clause
    update_sql(relation, fn sql ->
      "SELECT #{Enum.join(columns, ", ")} FROM (#{sql}) AS _subquery"
    end)
  end

  def filter(relation, condition) do
    # Add WHERE clause
    update_sql(relation, fn sql ->
      "SELECT * FROM (#{sql}) AS _subquery WHERE #{condition}"
    end)
  end

  # Execution - actually run query
  def fetch_all(relation) do
    DuckdbEx.Connection.fetch_all(relation.conn, relation.sql)
  end
end
```

---

## Phase 2: Data Source Integration (High Priority)

*Estimated: 3-4 weeks | Impact: High*

### Test Structure - `test/duckdb_ex/data_sources_test.exs`

#### 2.1 CSV Reading

**Test 2.1.1: Basic CSV Read**

```elixir
describe "read_csv/2" do
  test "reads CSV file", %{conn: conn} do
    csv_path = create_test_csv([
      ["id", "name", "age"],
      ["1", "Alice", "30"],
      ["2", "Bob", "25"]
    ])

    rel = DuckdbEx.Connection.read_csv(conn, csv_path)
    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)

    assert length(rows) == 2
    assert %{"id" => 1, "name" => "Alice", "age" => 30} = hd(rows)
  end

  test "reads CSV with options", %{conn: conn} do
    csv_path = create_test_csv_with_semicolon()

    rel = DuckdbEx.Connection.read_csv(conn, csv_path, delimiter: ";", header: false)
    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)

    assert length(rows) > 0
  end

  test "handles CSV with nulls", %{conn: conn} do
    csv_path = create_csv_with_nulls()

    rel = DuckdbEx.Connection.read_csv(conn, csv_path, null_str: "NULL")
    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)

    assert is_nil(hd(rows)["some_column"])
  end
end
```

#### 2.2 Parquet Reading

**Test 2.2.1: Parquet Integration**

```elixir
describe "read_parquet/2" do
  test "reads parquet file", %{conn: conn} do
    # Create test parquet file
    parquet_path = create_test_parquet()

    rel = DuckdbEx.Connection.read_parquet(conn, parquet_path)
    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)

    assert length(rows) > 0
  end

  test "reads multiple parquet files", %{conn: conn} do
    rel = DuckdbEx.Connection.read_parquet(conn, "test_data/*.parquet")
    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)

    assert length(rows) > 0
  end
end```

#### 2.3 Explorer DataFrame Integration

**Test 2.3.1: Import from Explorer**

```elixir
describe "from_df/2" do
  test "imports Explorer DataFrame", %{conn: conn} do
    df = Explorer.DataFrame.new(%{
      id: [1, 2, 3],
      name: ["Alice", "Bob", "Charlie"],
      age: [30, 25, 35]
    })

    rel = DuckdbEx.Connection.from_df(conn, df)
    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)

    assert length(rows) == 3
    assert %{"id" => 1, "name" => "Alice"} = hd(rows)
  end
end
```

**Test 2.3.2: Export to Explorer**

```elixir
describe "fetch_df/1" do
  test "exports relation to Explorer DataFrame", %{conn: conn} do
    rel = DuckdbEx.Connection.sql(conn, "SELECT * FROM range(10)")

    df = DuckdbEx.Relation.fetch_df(rel)

    assert %Explorer.DataFrame{} = df
    assert Explorer.DataFrame.n_rows(df) == 10
  end

  test "preserves column types", %{conn: conn} do
    DuckdbEx.execute(conn, """
      CREATE TABLE test (
        int_col INT,
        varchar_col VARCHAR,
        date_col DATE
      )
    """)
    DuckdbEx.execute(conn, "INSERT INTO test VALUES (1, 'hello', '2024-01-01')")

    df = conn
    |> DuckdbEx.Connection.table("test")
    |> DuckdbEx.Relation.fetch_df()

    schema = Explorer.DataFrame.dtypes(df)
    assert schema[:int_col] == :integer
    assert schema[:varchar_col] == :string
    assert schema[:date_col] == :date
  end
end
```

#### 2.4 JSON Reading

**Test 2.4.1: JSON Support**

```elixir
describe "read_json/2" do
  test "reads JSON lines file", %{conn: conn} do
    json_path = create_test_jsonl([
      %{id: 1, name: "Alice"},
      %{id: 2, name: "Bob"}
    ])

    rel = DuckdbEx.Connection.read_json(conn, json_path)
    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)

    assert length(rows) == 2
  end
end
```

---

## Phase 3: Transaction Management (Medium Priority)

*Estimated: 1 week | Impact: Medium*

### Test Structure - `test/duckdb_ex/transaction_test.exs`

**Test 3.1: Basic Transactions**

```elixir
describe "transactions" do
  test "commit transaction", %{conn: conn} do
    DuckdbEx.execute(conn, "CREATE TABLE test (x INT)")

    assert :ok = DuckdbEx.Connection.begin(conn)
    DuckdbEx.execute(conn, "INSERT INTO test VALUES (1)")
    assert :ok = DuckdbEx.Connection.commit(conn)

    {:ok, rows} = DuckdbEx.Connection.fetch_all(conn, "SELECT * FROM test")
    assert length(rows) == 1
  end

  test "rollback transaction", %{conn: conn} do
    DuckdbEx.execute(conn, "CREATE TABLE test (x INT)")

    DuckdbEx.Connection.begin(conn)
    DuckdbEx.execute(conn, "INSERT INTO test VALUES (1)")
    assert :ok = DuckdbEx.Connection.rollback(conn)

    {:ok, rows} = DuckdbEx.Connection.fetch_all(conn, "SELECT * FROM test")
    assert length(rows) == 0
  end

  test "transaction with macro", %{conn: conn} do
    DuckdbEx.execute(conn, "CREATE TABLE test (x INT)")

    result = DuckdbEx.Connection.transaction(conn, fn ->
      DuckdbEx.execute(conn, "INSERT INTO test VALUES (1)")
      :ok
    end)

    assert {:ok, :ok} = result
    {:ok, rows} = DuckdbEx.Connection.fetch_all(conn, "SELECT * FROM test")
    assert length(rows) == 1
  end
end
```

---

## Phase 4: Advanced Relation Operations (Medium Priority)

*Estimated: 2-3 weeks*

### Test Structure

**Test 4.1: Set Operations**

```elixir
describe "set operations" do
  test "union", %{conn: conn} do
    rel1 = DuckdbEx.Connection.sql(conn, "SELECT 1 as x UNION SELECT 2")
    rel2 = DuckdbEx.Connection.sql(conn, "SELECT 2 as x UNION SELECT 3")

    rel = DuckdbEx.Relation.union(rel1, rel2)
    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)

    assert length(rows) == 3  # 1, 2, 3
  end

  test "intersect", %{conn: conn} do
    rel1 = DuckdbEx.Connection.sql(conn, "SELECT 1 as x UNION SELECT 2")
    rel2 = DuckdbEx.Connection.sql(conn, "SELECT 2 as x UNION SELECT 3")

    rel = DuckdbEx.Relation.intersect(rel1, rel2)
    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)

    assert [%{"x" => 2}] = rows
  end
end
```

**Test 4.2: Window Functions**

```elixir
describe "window functions" do
  test "row_number", %{conn: conn} do
    rel = conn
    |> DuckdbEx.Connection.sql("SELECT * FROM (VALUES (1), (2), (3)) t(x)")
    |> DuckdbEx.Relation.select(["x", "row_number() OVER () as rn"])

    {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)
    assert [1, 2, 3] = Enum.map(rows, & &1["rn"])
  end
end
```

---

## Phase 5: Type System (Lower Priority)

*Estimated: 2-3 weeks*

### Test Structure - `test/duckdb_ex/type_test.exs`

**Test 5.1: Type Constructors**

```elixir
describe "type system" do
  test "list_type/1", %{conn: conn} do
    list_type = DuckdbEx.Type.list_type("INTEGER")
    assert %DuckdbEx.Type{name: "INTEGER[]"} = list_type
  end

  test "map_type/2", %{conn: conn} do
    map_type = DuckdbEx.Type.map_type("VARCHAR", "INTEGER")
    assert %DuckdbEx.Type{} = map_type
  end

  test "struct_type/1", %{conn: conn} do
    struct_type = DuckdbEx.Type.struct_type(%{
      name: "VARCHAR",
      age: "INTEGER"
    })
    assert %DuckdbEx.Type{} = struct_type
  end
end
```

---

## Test Organization Structure

```text
test/
├── duckdb_ex_test.exs                    # Module-level API tests
├── duckdb_ex/
│   ├── connection_test.exs               # ✅ Already exists
│   ├── result_test.exs                   # ✅ Already exists
│   ├── exceptions_test.exs               # ✅ Already exists
│   ├── relation_test.exs                 # NEW - Phase 1
│   ├── relation_aggregate_test.exs       # NEW - Phase 1
│   ├── relation_join_test.exs            # NEW - Phase 1
│   ├── data_sources_test.exs             # NEW - Phase 2
│   ├── csv_test.exs                      # NEW - Phase 2
│   ├── parquet_test.exs                  # NEW - Phase 2
│   ├── explorer_integration_test.exs     # NEW - Phase 2
│   ├── transaction_test.exs              # NEW - Phase 3
│   ├── type_test.exs                     # NEW - Phase 5
│   └── window_functions_test.exs         # NEW - Phase 4
└── support/
    ├── test_helpers.ex                   # Shared test utilities
    ├── fixtures/                         # Test data files
    │   ├── test.csv
    │   ├── test.parquet
    │   └── test.json
    └── python_comparison/                # Compare with Python results
        └── generate_expected.py
```

---

## Testing Best Practices for This Project

### 1. Reference Python Tests

Each test file should reference the corresponding Python test:

```elixir
# Reference: duckdb-python/tests/fast/test_relation_api.py
```

### 2. Property-Based Testing

Use StreamData (already a dependency) for:
*   SQL injection safety
*   Type conversion correctness
*   Relation composition properties

```elixir
property "filter is commutative for independent conditions" do
  check all x <- integer(), y <- integer() do
    rel1 = base_rel |> filter("a > #{x}") |> filter("b < #{y}")
    rel2 = base_rel |> filter("b < #{y}") |> filter("a > #{x}")

    assert fetch_all(rel1) == fetch_all(rel2)
  end
end
```

### 3. Python Comparison Tests

Create a test helper that compares results with Python:

```elixir
defmodule TestHelpers do
  def compare_with_python(sql) do
    # Run same query in Python duckdb
    python_result = run_python_query(sql)

    # Run in Elixir
    {:ok, elixir_result} = DuckdbEx.execute(@conn, sql)

    # Compare
    assert normalize(elixir_result) == normalize(python_result)
  end
end
```

### 4. Integration Test Database

Create a shared test database with realistic data:

```elixir
# test/support/test_database.ex
defmodule TestDatabase do
  def setup_test_data(conn) do
    # Create tables with various types
    DuckdbEx.execute(conn, """
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name VARCHAR,
        email VARCHAR,
        created_at TIMESTAMP
      )
    """)

    # Insert test data
    # ...
  end
end
```

---

## Implementation Workflow (Red-Green-Refactor)

Example for `filter/2` function:

### Step 1: RED - Write Failing Test

```elixir
test "filters rows with condition", %{conn: conn} do
  rel = conn
  |> DuckdbEx.Connection.table("test")
  |> DuckdbEx.Relation.filter("x > 5")

  {:ok, rows} = DuckdbEx.Relation.fetch_all(rel)
  assert Enum.all?(rows, fn %{"x" => x} -> x > 5 end)
end
```

Run test: `mix test test/duckdb_ex/relation_test.exs:42`
Expected: ❌ FAIL (function not defined)

### Step 2: GREEN - Minimal Implementation

```elixir
def filter(%Relation{sql: sql} = relation, condition) do
  new_sql = "SELECT * FROM (#{sql}) AS _subquery WHERE #{condition}"
  %{relation | sql: new_sql}
end
```

Run test: `mix test test/duckdb_ex/relation_test.exs:42`
Expected: ✅ PASS

### Step 3: REFACTOR - Improve Implementation

```elixir
def filter(%Relation{} = relation, condition) when is_binary(condition) do
  # Add SQL injection protection
  # Add support for parameterized queries
  # Optimize nested filters
  update_in(relation.sql, fn sql ->
    build_filtered_sql(sql, condition)
  end)
end

defp build_filtered_sql(sql, condition) do
  # More sophisticated SQL building
  # Handle edge cases
  # Optimize multiple filters
end
```

Run all tests: `mix test`
Expected: ✅ All PASS

### Step 4: DOCUMENT

```elixir
@doc """
Filters rows based on a condition.

Returns a new relation with a WHERE clause applied.

## Parameters

- `relation` - The relation to filter
- `condition` - SQL WHERE condition as string

## Examples

    iex> rel = DuckdbEx.Connection.table(conn, "users")
    iex> filtered = DuckdbEx.Relation.filter(rel, "age > 25")
    iex> DuckdbEx.Relation.fetch_all(filtered)
    {:ok, [%{"id" => 2, "name" => "Bob", "age" => 30}, ...]}

## Notes

Filters can be chained. Each filter adds an AND condition.

Reference: DuckDBPyRelation.filter() in Python
"""
@spec filter(t(), String.t()) :: t()
def filter(%Relation{} = relation, condition) when is_binary(condition) do
  # ...
end
```

---

## Priority Order Summary

1.  **CRITICAL** - Relation API basics (Phase 1.1-1.3): 2 weeks
2.  **HIGH** - Explorer integration (Phase 2.3): 1 week
3.  **HIGH** - CSV/Parquet readers (Phase 2.1-2.2): 1 week
4.  **MEDIUM** - Joins and aggregations (Phase 1.4): 1 week
5.  **MEDIUM** - Transactions (Phase 3): 1 week
6.  **MEDIUM** - Advanced relations (Phase 4): 2 weeks
7.  **LOW** - Type system (Phase 5): 2 weeks

---

## Success Metrics

For each phase, track:

*   Test Coverage: >90% for implemented features
*   Python Compatibility: 100% of test cases match Python behavior
*   Documentation: Every public function has `@doc` and `@spec`
*   Performance: Queries within 10% of Python performance (accounting for JSON overhead)

---

## Summary

I've created a comprehensive TDD implementation plan for DuckDB-Elixir based on the gap analysis in `WHAT_REMAINS.md`. Here are the key elements:

### Phased Approach (Aligned with Document Recommendations)

*   **Phase 1: Core Relation API (4-6 weeks, CRITICAL)**
    *   Test-driven implementation of lazy query building
    *   Operations: project, filter, limit, order, aggregate, join
    *   Full test coverage with Python comparison
    *   This is the most impactful missing feature
*   **Phase 2: Data Source Integration (3-4 weeks, HIGH)**
    *   CSV/Parquet/JSON reading with comprehensive tests
    *   Explorer DataFrame integration (import/export)
    *   Critical for Elixir data science ecosystem
*   **Phase 3: Transaction Management (1 week, MEDIUM)**
    *   `begin`, `commit`, `rollback` with isolation tests
    *   Transaction helper macros for ergonomic usage
*   **Phase 4-5: Advanced Features (4-6 weeks, MEDIUM-LOW)**
    *   Set operations, window functions
    *   Type system and constructors

### TDD Methodology

Each feature follows strict Red-Green-Refactor:

1.  **RED**: Write failing test referencing Python behavior
2.  **GREEN**: Minimal implementation to pass
3.  **REFACTOR**: Improve while maintaining green tests
4.  **DOCUMENT**: Add specs, docs, and examples

### Test Organization

*   Dedicated test files per feature area
*   Python comparison tests for compatibility
*   Property-based tests using StreamData
*   Shared test fixtures and helpers
*   Target: >90% coverage, 100% Python compatibility

### Implementation Strategy

The plan builds SQL incrementally for lazy evaluation, only executing when `fetch_*` is called. This matches Python's approach and enables efficient query composition.

### Next Steps to Begin Implementation

1.  Start with Phase 1.1: Basic relation creation (`sql/2`, `table/2`)
2.  Write failing tests first
3.  Implement minimal SQL generation
4.  Add each operation incrementally with full tests

This approach ensures high quality, maintainability, and compatibility with the Python API that users expect.
