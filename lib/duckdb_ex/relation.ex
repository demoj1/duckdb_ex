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
end
