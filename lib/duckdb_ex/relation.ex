defmodule DuckdbEx.Relation do
  @moduledoc """
  DuckDB Relational API.

  This module implements the DuckDB Relation API, which enables lazy, composable
  query building with method chaining. Relations are not executed until a fetch
  operation is called.

  Reference: duckdb-python/src/duckdb_py/include/duckdb_python/pyrelation.hpp

  ## Overview

  A relation represents a lazy SQL query that can be composed with various
  operations (filter, project, join, etc.) before execution. This enables:

  - **Lazy evaluation**: Queries are only executed when results are needed
  - **Composability**: Operations can be chained in any order
  - **Optimization**: DuckDB can optimize the entire query tree
  - **Reusability**: Base relations can be used in multiple query branches

  ## Examples

      # Create a relation from SQL
      relation = DuckdbEx.Connection.sql(conn, "SELECT * FROM users")

      # Chain operations (lazy - not executed yet)
      result = relation
      |> DuckdbEx.Relation.filter("age > 25")
      |> DuckdbEx.Relation.project(["name", "email"])
      |> DuckdbEx.Relation.order("name ASC")
      |> DuckdbEx.Relation.limit(10)

      # Execute and fetch results
      {:ok, rows} = DuckdbEx.Relation.fetch_all(result)

  ## Lazy Evaluation

  Relations build SQL incrementally. Each operation returns a new relation
  with updated SQL, but nothing is executed until you call:

  - `fetch_all/1` - Fetch all rows
  - `fetch_one/1` - Fetch first row
  - `execute/1` - Execute and return result struct

  This allows DuckDB to optimize the entire query before execution.
  """

  alias DuckdbEx.Connection
  alias DuckdbEx.Result

  @type t :: %__MODULE__{
          conn: Connection.t(),
          sql: String.t(),
          alias: String.t() | nil
        }

  defstruct [:conn, :sql, :alias]

  @doc """
  Creates a new relation.

  This is typically called internally by Connection functions like `sql/2` or
  `table/2`. Users should not need to call this directly.

  ## Parameters

  - `conn` - Database connection
  - `sql` - SQL query string
  - `alias` - Optional table alias

  ## Returns

  A new `%DuckdbEx.Relation{}` struct
  """
  @spec new(Connection.t(), String.t(), String.t() | nil) :: t()
  def new(conn, sql, relation_alias \\ nil) do
    %__MODULE__{
      conn: conn,
      sql: sql,
      alias: relation_alias
    }
  end

  @doc """
  Projects (selects) specific columns from the relation.

  Equivalent to SQL SELECT clause. Returns a new relation with only the
  specified columns or expressions.

  ## Parameters

  - `relation` - The relation to project from
  - `columns` - List of column names or expressions

  ## Examples

      # Select specific columns
      relation |> DuckdbEx.Relation.project(["name", "email"])

      # Use expressions
      relation |> DuckdbEx.Relation.project(["id", "upper(name) as upper_name"])

      # Calculations
      relation |> DuckdbEx.Relation.project(["price", "price * 1.1 as price_with_tax"])

  Reference: DuckDBPyRelation.project() in Python
  """
  @spec project(t(), list(String.t())) :: t()
  def project(%__MODULE__{sql: sql} = relation, columns) when is_list(columns) do
    columns_str = Enum.join(columns, ", ")
    new_sql = "SELECT #{columns_str} FROM (#{sql}) AS _projection"

    %{relation | sql: new_sql}
  end

  @doc """
  Filters rows based on a condition.

  Equivalent to SQL WHERE clause. Returns a new relation with only rows that
  satisfy the condition.

  ## Parameters

  - `relation` - The relation to filter
  - `condition` - SQL WHERE condition as string

  ## Examples

      # Simple condition
      relation |> DuckdbEx.Relation.filter("age > 25")

      # Complex condition
      relation |> DuckdbEx.Relation.filter("age > 25 AND status = 'active'")

      # Chain multiple filters (AND logic)
      relation
      |> DuckdbEx.Relation.filter("age > 25")
      |> DuckdbEx.Relation.filter("status = 'active'")

  ## Notes

  Multiple filters are combined with AND. Each call to filter adds another
  condition to the WHERE clause.

  Reference: DuckDBPyRelation.filter() in Python
  """
  @spec filter(t(), String.t()) :: t()
  def filter(%__MODULE__{sql: sql} = relation, condition) when is_binary(condition) do
    new_sql = "SELECT * FROM (#{sql}) AS _filter WHERE #{condition}"

    %{relation | sql: new_sql}
  end

  @doc """
  Limits the number of rows returned.

  Equivalent to SQL LIMIT clause. Returns a new relation that will return
  at most `n` rows when executed.

  ## Parameters

  - `relation` - The relation to limit
  - `n` - Maximum number of rows to return

  ## Examples

      # Get first 10 rows
      relation |> DuckdbEx.Relation.limit(10)

      # Combine with order for top-N queries
      relation
      |> DuckdbEx.Relation.order("score DESC")
      |> DuckdbEx.Relation.limit(5)

  Reference: DuckDBPyRelation.limit() in Python
  """
  @spec limit(t(), non_neg_integer()) :: t()
  def limit(%__MODULE__{sql: sql} = relation, n) when is_integer(n) and n >= 0 do
    new_sql = "SELECT * FROM (#{sql}) AS _limit LIMIT #{n}"

    %{relation | sql: new_sql}
  end

  @doc """
  Orders (sorts) the rows by specified columns.

  Equivalent to SQL ORDER BY clause. Returns a new relation with rows sorted
  according to the order specification.

  ## Parameters

  - `relation` - The relation to order
  - `order_by` - ORDER BY specification as string

  ## Examples

      # Single column ascending
      relation |> DuckdbEx.Relation.order("name ASC")

      # Single column descending
      relation |> DuckdbEx.Relation.order("age DESC")

      # Multiple columns
      relation |> DuckdbEx.Relation.order("department ASC, salary DESC")

      # Expression
      relation |> DuckdbEx.Relation.order("length(name) DESC")

  Reference: DuckDBPyRelation.order() in Python
  """
  @spec order(t(), String.t()) :: t()
  def order(%__MODULE__{sql: sql} = relation, order_by) when is_binary(order_by) do
    new_sql = "SELECT * FROM (#{sql}) AS _order ORDER BY #{order_by}"

    %{relation | sql: new_sql}
  end

  @doc """
  Executes the relation and returns the result struct.

  This triggers query execution and returns the raw result structure.
  For most use cases, prefer `fetch_all/1` or `fetch_one/1`.

  ## Parameters

  - `relation` - The relation to execute

  ## Returns

  - `{:ok, result}` - Result struct with rows and metadata
  - `{:error, exception}` - Execution failed

  ## Examples

      {:ok, result} = DuckdbEx.Relation.execute(relation)

  Reference: DuckDBPyRelation.execute() in Python
  """
  @spec execute(t()) :: {:ok, term()} | {:error, term()}
  def execute(%__MODULE__{conn: conn, sql: sql}) do
    Connection.execute(conn, sql)
  end

  @doc """
  Fetches all rows from the relation.

  Executes the relation query and returns all rows as a list of maps.

  ## Parameters

  - `relation` - The relation to fetch from

  ## Returns

  - `{:ok, rows}` - List of row maps
  - `{:error, exception}` - Execution failed

  ## Examples

      {:ok, rows} = DuckdbEx.Relation.fetch_all(relation)
      # => [%{"id" => 1, "name" => "Alice"}, ...]

  Reference: DuckDBPyRelation.fetchall() in Python
  """
  @spec fetch_all(t()) :: {:ok, list(map())} | {:error, term()}
  def fetch_all(%__MODULE__{conn: conn, sql: sql}) do
    case Connection.execute(conn, sql) do
      {:ok, result} -> {:ok, Result.fetch_all(result)}
      error -> error
    end
  end

  @doc """
  Fetches one row from the relation.

  Executes the relation query and returns the first row, or nil if the
  result is empty.

  ## Parameters

  - `relation` - The relation to fetch from

  ## Returns

  - `{:ok, row}` - Row map or nil if empty
  - `{:error, exception}` - Execution failed

  ## Examples

      {:ok, row} = DuckdbEx.Relation.fetch_one(relation)
      # => %{"id" => 1, "name" => "Alice"}

      # Empty result
      {:ok, nil} = DuckdbEx.Relation.fetch_one(empty_relation)

  Reference: DuckDBPyRelation.fetchone() in Python
  """
  @spec fetch_one(t()) :: {:ok, map() | nil} | {:error, term()}
  def fetch_one(%__MODULE__{conn: conn, sql: sql}) do
    case Connection.execute(conn, sql) do
      {:ok, result} -> {:ok, Result.fetch_one(result)}
      error -> error
    end
  end

  @doc """
  Fetches multiple rows from the relation.

  Executes the relation query and returns the first N rows.

  ## Parameters

  - `relation` - The relation to fetch from
  - `n` - Number of rows to fetch

  ## Returns

  - `{:ok, rows}` - List of row maps (up to N rows)
  - `{:error, exception}` - Execution failed

  ## Examples

      {:ok, rows} = DuckdbEx.Relation.fetch_many(relation, 5)
      # => [%{"id" => 1}, %{"id" => 2}, ...]

  Reference: DuckDBPyRelation.fetchmany() in Python
  """
  @spec fetch_many(t(), pos_integer()) :: {:ok, list(map())} | {:error, term()}
  def fetch_many(%__MODULE__{conn: conn, sql: sql}, n) when is_integer(n) and n > 0 do
    limited_sql = "SELECT * FROM (#{sql}) AS _fetch_many LIMIT #{n}"

    case Connection.execute(conn, limited_sql) do
      {:ok, result} -> {:ok, Result.fetch_all(result)}
      error -> error
    end
  end

  @doc """
  Performs aggregation on the relation.

  Supports both simple aggregations and GROUP BY aggregations. Aggregation
  expressions can include common functions like COUNT, SUM, AVG, MIN, MAX,
  and any SQL aggregate function supported by DuckDB.

  ## Parameters

  - `relation` - The relation to aggregate
  - `expressions` - Aggregation expression(s) as string or list of strings
  - `opts` - Options (keyword list)
    - `:group_by` - List of columns to group by (optional)

  ## Returns

  A new relation with aggregation applied

  ## Examples

      # Simple aggregation
      relation |> DuckdbEx.Relation.aggregate("count(*) as total")

      # Multiple aggregations
      relation |> DuckdbEx.Relation.aggregate([
        "count(*) as count",
        "sum(amount) as total",
        "avg(amount) as average"
      ])

      # Group by single column
      relation
      |> DuckdbEx.Relation.aggregate("sum(sales) as total", group_by: ["region"])

      # Group by multiple columns
      relation
      |> DuckdbEx.Relation.aggregate(
        ["sum(sales) as total", "count(*) as count"],
        group_by: ["region", "year"]
      )

      # Filter after aggregation (HAVING clause)
      relation
      |> DuckdbEx.Relation.aggregate("sum(amount) as total", group_by: ["category"])
      |> DuckdbEx.Relation.filter("total > 1000")

  Reference: DuckDBPyRelation.aggregate() in Python
  """
  @spec aggregate(t(), String.t() | list(String.t()), keyword()) :: t()
  def aggregate(relation, expressions, opts \\ [])

  def aggregate(%__MODULE__{sql: sql} = relation, expressions, opts) when is_list(expressions) do
    group_by = Keyword.get(opts, :group_by, [])
    agg_str = Enum.join(expressions, ", ")

    new_sql =
      if group_by == [] do
        # Simple aggregation without GROUP BY
        "SELECT #{agg_str} FROM (#{sql}) AS _aggregate"
      else
        # GROUP BY aggregation
        group_cols = Enum.join(group_by, ", ")
        "SELECT #{group_cols}, #{agg_str} FROM (#{sql}) AS _aggregate GROUP BY #{group_cols}"
      end

    %{relation | sql: new_sql}
  end

  def aggregate(%__MODULE__{} = relation, expression, opts) when is_binary(expression) do
    aggregate(relation, [expression], opts)
  end

  @doc """
  Convenience function for COUNT aggregation.

  Returns a relation with a COUNT(*) aggregation. The result will have a
  column named "count".

  ## Parameters

  - `relation` - The relation to count

  ## Returns

  A new relation with COUNT aggregation

  ## Examples

      relation |> DuckdbEx.Relation.count()
      # Equivalent to: aggregate("count(*) as count")

  Reference: DuckDBPyRelation.count() in Python
  """
  @spec count(t()) :: t()
  def count(%__MODULE__{} = relation) do
    aggregate(relation, "count(*) as count")
  end

  @doc """
  Convenience function for SUM aggregation.

  Returns a relation with a SUM aggregation on the specified column.
  The result will have a column named "sum".

  ## Parameters

  - `relation` - The relation to aggregate
  - `column` - Column name or expression to sum

  ## Returns

  A new relation with SUM aggregation

  ## Examples

      relation |> DuckdbEx.Relation.sum("amount")
      # Equivalent to: aggregate("sum(amount) as sum")

  Reference: DuckDBPyRelation.sum() in Python
  """
  @spec sum(t(), String.t()) :: t()
  def sum(%__MODULE__{} = relation, column) when is_binary(column) do
    aggregate(relation, "sum(#{column}) as sum")
  end

  @doc """
  Convenience function for AVG aggregation.

  Returns a relation with an AVG aggregation on the specified column.
  The result will have a column named "avg".

  ## Parameters

  - `relation` - The relation to aggregate
  - `column` - Column name or expression to average

  ## Returns

  A new relation with AVG aggregation

  ## Examples

      relation |> DuckdbEx.Relation.avg("price")
      # Equivalent to: aggregate("avg(price) as avg")

  Reference: DuckDBPyRelation.avg() in Python
  """
  @spec avg(t(), String.t()) :: t()
  def avg(%__MODULE__{} = relation, column) when is_binary(column) do
    aggregate(relation, "avg(#{column}) as avg")
  end

  @doc """
  Convenience function for MIN aggregation.

  Returns a relation with a MIN aggregation on the specified column.
  The result will have a column named "min".

  ## Parameters

  - `relation` - The relation to aggregate
  - `column` - Column name or expression to find minimum

  ## Returns

  A new relation with MIN aggregation

  ## Examples

      relation |> DuckdbEx.Relation.min("temperature")
      # Equivalent to: aggregate("min(temperature) as min")

  Reference: DuckDBPyRelation.min() in Python
  """
  @spec min(t(), String.t()) :: t()
  def min(%__MODULE__{} = relation, column) when is_binary(column) do
    aggregate(relation, "min(#{column}) as min")
  end

  @doc """
  Convenience function for MAX aggregation.

  Returns a relation with a MAX aggregation on the specified column.
  The result will have a column named "max".

  ## Parameters

  - `relation` - The relation to aggregate
  - `column` - Column name or expression to find maximum

  ## Returns

  A new relation with MAX aggregation

  ## Examples

      relation |> DuckdbEx.Relation.max("score")
      # Equivalent to: aggregate("max(score) as max")

  Reference: DuckDBPyRelation.max() in Python
  """
  @spec max(t(), String.t()) :: t()
  def max(%__MODULE__{} = relation, column) when is_binary(column) do
    aggregate(relation, "max(#{column}) as max")
  end

  @doc """
  Removes duplicate rows from the relation.

  Equivalent to SQL DISTINCT. Returns a new relation with duplicate rows removed.

  ## Parameters

  - `relation` - The relation to remove duplicates from

  ## Returns

  A new relation with DISTINCT applied

  ## Examples

      # Remove duplicate rows
      relation |> DuckdbEx.Relation.distinct()

      # Chain with other operations
      relation
      |> DuckdbEx.Relation.filter("age > 25")
      |> DuckdbEx.Relation.distinct()
      |> DuckdbEx.Relation.order("name ASC")

  Reference: DuckDBPyRelation.distinct() in Python
  """
  @spec distinct(t()) :: t()
  def distinct(%__MODULE__{sql: sql} = relation) do
    new_sql = "SELECT DISTINCT * FROM (#{sql}) AS _distinct"
    %{relation | sql: new_sql}
  end

  @doc """
  Unions two relations.

  Equivalent to SQL UNION. Returns a new relation combining rows from both
  relations, with duplicates removed.

  ## Parameters

  - `relation1` - First relation
  - `relation2` - Second relation

  ## Returns

  A new relation with both relations unioned

  ## Examples

      # Union two relations
      rel1 = DuckdbEx.Connection.sql(conn, "SELECT 1 as x")
      rel2 = DuckdbEx.Connection.sql(conn, "SELECT 2 as x")
      combined = DuckdbEx.Relation.union(rel1, rel2)

      # Can be chained
      rel1
      |> DuckdbEx.Relation.union(rel2)
      |> DuckdbEx.Relation.union(rel3)

  ## Notes

  Both relations must have the same number of columns and compatible types.
  UNION automatically removes duplicates. Use UNION ALL if you want to keep duplicates.

  Reference: DuckDBPyRelation.union() in Python
  """
  @spec union(t(), t()) :: t()
  def union(%__MODULE__{conn: conn, sql: sql1}, %__MODULE__{sql: sql2}) do
    new_sql = "(#{sql1}) UNION (#{sql2})"
    %__MODULE__{conn: conn, sql: new_sql, alias: nil}
  end

  @doc """
  Intersects two relations.

  Equivalent to SQL INTERSECT. Returns a new relation containing only rows
  that appear in both relations.

  ## Parameters

  - `relation1` - First relation
  - `relation2` - Second relation

  ## Returns

  A new relation with the intersection

  ## Examples

      # Find common rows
      rel1 = DuckdbEx.Connection.sql(conn, "SELECT * FROM (VALUES (1), (2), (3)) t(x)")
      rel2 = DuckdbEx.Connection.sql(conn, "SELECT * FROM (VALUES (2), (3), (4)) t(x)")
      common = DuckdbEx.Relation.intersect(rel1, rel2)
      # Returns rows with x = 2 and x = 3

  ## Notes

  Both relations must have the same number of columns and compatible types.

  Reference: DuckDBPyRelation.intersect() in Python
  """
  @spec intersect(t(), t()) :: t()
  def intersect(%__MODULE__{conn: conn, sql: sql1}, %__MODULE__{sql: sql2}) do
    new_sql = "(#{sql1}) INTERSECT (#{sql2})"
    %__MODULE__{conn: conn, sql: new_sql, alias: nil}
  end

  @doc """
  Returns rows in the first relation but not in the second.

  Equivalent to SQL EXCEPT. Returns a new relation containing rows from
  the first relation that are not in the second relation.

  ## Parameters

  - `relation1` - First relation
  - `relation2` - Second relation to exclude

  ## Returns

  A new relation with the difference

  ## Examples

      # Find rows only in first relation
      rel1 = DuckdbEx.Connection.sql(conn, "SELECT * FROM (VALUES (1), (2), (3)) t(x)")
      rel2 = DuckdbEx.Connection.sql(conn, "SELECT * FROM (VALUES (2), (3), (4)) t(x)")
      diff = DuckdbEx.Relation.except_(rel1, rel2)
      # Returns row with x = 1

  ## Notes

  Both relations must have the same number of columns and compatible types.

  The function is named `except_` (with underscore) because `except` is a
  reserved keyword in Elixir.

  Reference: DuckDBPyRelation.except_() in Python
  """
  @spec except_(t(), t()) :: t()
  def except_(%__MODULE__{conn: conn, sql: sql1}, %__MODULE__{sql: sql2}) do
    new_sql = "(#{sql1}) EXCEPT (#{sql2})"
    %__MODULE__{conn: conn, sql: new_sql, alias: nil}
  end

  @doc """
  Joins two relations.

  Supports various join types: inner, left, right, and outer joins.
  Returns a new relation combining rows from both relations based on the
  join condition.

  ## Parameters

  - `relation1` - First relation (left side)
  - `relation2` - Second relation (right side)
  - `condition` - Join condition as SQL string
  - `opts` - Options (keyword list)
    - `:type` - Join type (`:inner`, `:left`, `:right`, `:outer`), defaults to `:inner`

  ## Returns

  A new relation with the join applied

  ## Examples

      # Inner join
      users = DuckdbEx.Connection.table(conn, "users")
      orders = DuckdbEx.Connection.table(conn, "orders")
      joined = DuckdbEx.Relation.join(users, orders, "users.id = orders.user_id")

      # Left join
      joined = DuckdbEx.Relation.join(users, orders, "users.id = orders.user_id", type: :left)

      # Right join
      joined = DuckdbEx.Relation.join(users, orders, "users.id = orders.user_id", type: :right)

      # Outer join
      joined = DuckdbEx.Relation.join(users, orders, "users.id = orders.user_id", type: :outer)

      # Chain multiple joins
      users
      |> DuckdbEx.Relation.join(orders, "users.id = orders.user_id")
      |> DuckdbEx.Relation.join(products, "orders.product_id = products.id")

  ## Notes

  The join condition should reference columns with table names or aliases to avoid ambiguity.

  Reference: DuckDBPyRelation.join() in Python
  """
  @spec join(t(), t(), String.t(), keyword()) :: t()
  def join(relation1, relation2, condition, opts \\ [])

  def join(%__MODULE__{conn: conn, sql: sql1}, %__MODULE__{sql: sql2}, condition, opts) do
    join_type =
      case Keyword.get(opts, :type, :inner) do
        :inner -> "INNER JOIN"
        :left -> "LEFT JOIN"
        :right -> "RIGHT JOIN"
        :outer -> "FULL OUTER JOIN"
      end

    # Extract table names from join condition to use as aliases
    # This is a simple heuristic: look for table.column patterns
    {left_alias, right_alias} = extract_table_aliases(condition)

    new_sql = """
    SELECT * FROM (#{sql1}) AS #{left_alias}
    #{join_type} (#{sql2}) AS #{right_alias}
    ON #{condition}
    """

    %__MODULE__{conn: conn, sql: String.trim(new_sql), alias: nil}
  end

  # Extract table names from a join condition like "users.id = orders.user_id"
  defp extract_table_aliases(condition) do
    # Find all table.column patterns
    case Regex.scan(~r/(\w+)\.\w+/, condition) do
      [[_, left] | [[_, right] | _]] -> {left, right}
      [[_, left]] -> {left, "_right"}
      _ -> {"_left", "_right"}
    end
  end

  @doc """
  Performs a cross join (cartesian product) of two relations.

  Returns a new relation containing all possible combinations of rows
  from both relations.

  ## Parameters

  - `relation1` - First relation
  - `relation2` - Second relation

  ## Returns

  A new relation with the cross join

  ## Examples

      rel1 = DuckdbEx.Connection.sql(conn, "SELECT * FROM (VALUES (1), (2)) t(x)")
      rel2 = DuckdbEx.Connection.sql(conn, "SELECT * FROM (VALUES (3), (4)) t(y)")
      crossed = DuckdbEx.Relation.cross(rel1, rel2)
      # Returns 4 rows: (1,3), (1,4), (2,3), (2,4)

  ## Notes

  Cross joins can produce very large result sets (rows1 × rows2).
  Use with caution on large relations.

  Reference: DuckDBPyRelation.cross() in Python
  """
  @spec cross(t(), t()) :: t()
  def cross(%__MODULE__{conn: conn, sql: sql1}, %__MODULE__{sql: sql2}) do
    new_sql = """
    SELECT * FROM (#{sql1}) CROSS JOIN (#{sql2})
    """

    %__MODULE__{conn: conn, sql: String.trim(new_sql), alias: nil}
  end
end
