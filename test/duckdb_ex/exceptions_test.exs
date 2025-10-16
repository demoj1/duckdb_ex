defmodule DuckdbEx.ExceptionsTest do
  use ExUnit.Case

  alias DuckdbEx.Exceptions

  describe "from_error_string/1" do
    test "parses BinderException" do
      error = Exceptions.from_error_string("BinderException:Column 'foo' not found")
      assert %Exceptions.BinderException{message: "Column 'foo' not found"} = error
    end

    test "parses CatalogException" do
      error = Exceptions.from_error_string("CatalogException:Table 'users' not found")
      assert %Exceptions.CatalogException{message: "Table 'users' not found"} = error
    end

    test "parses SyntaxException" do
      error = Exceptions.from_error_string("SyntaxException:syntax error")
      assert %Exceptions.SyntaxException{message: "syntax error"} = error
    end

    test "falls back to generic Error for unknown type" do
      error = Exceptions.from_error_string("Unknown error message")
      assert %Exceptions.Error{message: "Unknown error message"} = error
    end
  end
end
