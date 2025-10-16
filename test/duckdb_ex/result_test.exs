defmodule DuckdbEx.ResultTest do
  use ExUnit.Case

  alias DuckdbEx.Result

  describe "fetch_all/1" do
    test "fetches all rows from result" do
      result = %{rows: [%{"a" => 1}, %{"a" => 2}, %{"a" => 3}], row_count: 3}
      assert Result.fetch_all(result) == [%{"a" => 1}, %{"a" => 2}, %{"a" => 3}]
    end

    test "returns empty list for empty result" do
      result = %{rows: [], row_count: 0}
      assert Result.fetch_all(result) == []
    end
  end

  describe "fetch_one/1" do
    test "fetches first row from result" do
      result = %{rows: [%{"a" => 1}, %{"a" => 2}], row_count: 2}
      assert Result.fetch_one(result) == %{"a" => 1}
    end

    test "returns nil for empty result" do
      result = %{rows: [], row_count: 0}
      assert Result.fetch_one(result) == nil
    end
  end

  describe "fetch_many/2" do
    test "fetches N rows from result" do
      result = %{rows: [%{"a" => 1}, %{"a" => 2}, %{"a" => 3}, %{"a" => 4}], row_count: 4}
      assert Result.fetch_many(result, 2) == [%{"a" => 1}, %{"a" => 2}]
    end

    test "fetches all available rows when N exceeds row count" do
      result = %{rows: [%{"a" => 1}, %{"a" => 2}], row_count: 2}
      assert Result.fetch_many(result, 10) == [%{"a" => 1}, %{"a" => 2}]
    end
  end

  describe "row_count/1" do
    test "returns row count from result" do
      result = %{rows: [], row_count: 5}
      assert Result.row_count(result) == 5
    end

    test "calculates row count from rows when not provided" do
      result = %{rows: [%{}, %{}, %{}]}
      assert Result.row_count(result) == 3
    end
  end

  describe "to_tuples/1" do
    test "converts rows to tuples" do
      result = %{rows: [%{"a" => 1, "b" => 2}, %{"a" => 3, "b" => 4}], row_count: 2}
      tuples = Result.to_tuples(result)
      # Note: Map iteration order may vary, but values should be present
      assert length(tuples) == 2
      assert is_tuple(hd(tuples))
    end
  end

  describe "columns/1" do
    test "extracts column names from first row" do
      result = %{rows: [%{"a" => 1, "b" => 2}], row_count: 1}
      columns = Result.columns(result)
      assert is_list(columns)
      assert "a" in columns
      assert "b" in columns
    end

    test "returns nil for empty result" do
      result = %{rows: [], row_count: 0}
      assert Result.columns(result) == nil
    end
  end
end
