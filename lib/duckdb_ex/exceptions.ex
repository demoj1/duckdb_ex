defmodule DuckdbEx.Exceptions do
  @moduledoc """
  Exception types for DuckDB Elixir.

  This module defines all exception types that can be raised by DuckDB operations.
  The exception hierarchy mirrors the Python duckdb client for API compatibility.

  Reference: duckdb-python/duckdb/__init__.py

  ## Exception Hierarchy

  The exceptions follow the DB-API 2.0 specification with DuckDB-specific extensions:

  - Error (base exception)
    - DatabaseError
      - DataError
      - OperationalError
      - IntegrityError
      - InternalError
      - ProgrammingError
      - NotSupportedError
    - DuckDB-specific exceptions
      - BinderException
      - CatalogException
      - ConnectionException
      - ConstraintException
      - ConversionException
      - DependencyException
      - FatalException
      - HTTPException
      - InternalException
      - InterruptException
      - InvalidInputException
      - InvalidTypeException
      - IOException
      - NotImplementedException
      - OutOfMemoryException
      - OutOfRangeException
      - ParserException
      - PermissionException
      - SequenceException
      - SerializationException
      - SyntaxException
      - TransactionException
      - TypeMismatchException
  - Warning (base warning)
  """

  # Base exceptions
  defmodule Error do
    @moduledoc "Base exception for all DuckDB errors"
    defexception [:message]
  end

  defmodule Warning do
    @moduledoc "Base warning for DuckDB warnings"
    defexception [:message]
  end

  # DB-API 2.0 exceptions
  defmodule DatabaseError do
    @moduledoc "Exception for errors related to the database"
    defexception [:message]
  end

  defmodule DataError do
    @moduledoc "Exception for errors related to data (e.g., division by zero)"
    defexception [:message]
  end

  defmodule OperationalError do
    @moduledoc "Exception for errors related to database operation"
    defexception [:message]
  end

  defmodule IntegrityError do
    @moduledoc "Exception for integrity constraint violations"
    defexception [:message]
  end

  defmodule InternalError do
    @moduledoc "Exception for internal database errors"
    defexception [:message]
  end

  defmodule ProgrammingError do
    @moduledoc "Exception for programming errors (e.g., syntax errors)"
    defexception [:message]
  end

  defmodule NotSupportedError do
    @moduledoc "Exception for features not supported by DuckDB"
    defexception [:message]
  end

  # DuckDB-specific exceptions
  defmodule BinderException do
    @moduledoc "Exception raised during binding phase (e.g., unknown column)"
    defexception [:message]
  end

  defmodule CatalogException do
    @moduledoc "Exception related to catalog operations (e.g., table not found)"
    defexception [:message]
  end

  defmodule ConnectionException do
    @moduledoc "Exception related to database connections"
    defexception [:message]
  end

  defmodule ConstraintException do
    @moduledoc "Exception for constraint violations"
    defexception [:message]
  end

  defmodule ConversionException do
    @moduledoc "Exception for type conversion errors"
    defexception [:message]
  end

  defmodule DependencyException do
    @moduledoc "Exception for dependency-related errors (e.g., dropping used object)"
    defexception [:message]
  end

  defmodule FatalException do
    @moduledoc "Exception for fatal errors that cannot be recovered"
    defexception [:message]
  end

  defmodule HTTPException do
    @moduledoc "Exception for HTTP-related errors"
    defexception [:message]
  end

  defmodule InternalException do
    @moduledoc "Exception for internal DuckDB errors"
    defexception [:message]
  end

  defmodule InterruptException do
    @moduledoc "Exception raised when a query is interrupted"
    defexception [:message]
  end

  defmodule InvalidInputException do
    @moduledoc "Exception for invalid input"
    defexception [:message]
  end

  defmodule InvalidTypeException do
    @moduledoc "Exception for invalid type operations"
    defexception [:message]
  end

  defmodule IOException do
    @moduledoc "Exception for I/O errors"
    defexception [:message]
  end

  defmodule NotImplementedException do
    @moduledoc "Exception for features not yet implemented"
    defexception [:message]
  end

  defmodule OutOfMemoryException do
    @moduledoc "Exception raised when running out of memory"
    defexception [:message]
  end

  defmodule OutOfRangeException do
    @moduledoc "Exception for out of range errors"
    defexception [:message]
  end

  defmodule ParserException do
    @moduledoc "Exception raised during SQL parsing"
    defexception [:message]
  end

  defmodule PermissionException do
    @moduledoc "Exception for permission-related errors"
    defexception [:message]
  end

  defmodule SequenceException do
    @moduledoc "Exception for sequence-related errors"
    defexception [:message]
  end

  defmodule SerializationException do
    @moduledoc "Exception for serialization errors"
    defexception [:message]
  end

  defmodule SyntaxException do
    @moduledoc "Exception for SQL syntax errors"
    defexception [:message]
  end

  defmodule TransactionException do
    @moduledoc "Exception for transaction-related errors"
    defexception [:message]
  end

  defmodule TypeMismatchException do
    @moduledoc "Exception for type mismatch errors"
    defexception [:message]
  end

  @doc """
  Maps an error string from the NIF to the appropriate exception.

  The NIF layer returns errors as strings in the format "ExceptionType:message".
  This function parses that format and returns the appropriate exception struct.

  ## Examples

      iex> DuckdbEx.Exceptions.from_error_string("BinderException:Column 'foo' not found")
      %DuckdbEx.Exceptions.BinderException{message: "Column 'foo' not found"}

      iex> DuckdbEx.Exceptions.from_error_string("CatalogException:Table 'users' not found")
      %DuckdbEx.Exceptions.CatalogException{message: "Table 'users' not found"}

  Reference: Python exception mapping in duckdb-python
  """
  @spec from_error_string(String.t()) :: struct()
  def from_error_string(error_string) when is_binary(error_string) do
    case String.split(error_string, ":", parts: 2) do
      ["BinderException", msg] -> %BinderException{message: msg}
      ["CatalogException", msg] -> %CatalogException{message: msg}
      ["ConnectionException", msg] -> %ConnectionException{message: msg}
      ["ConstraintException", msg] -> %ConstraintException{message: msg}
      ["ConversionException", msg] -> %ConversionException{message: msg}
      ["DependencyException", msg] -> %DependencyException{message: msg}
      ["FatalException", msg] -> %FatalException{message: msg}
      ["HTTPException", msg] -> %HTTPException{message: msg}
      ["InternalException", msg] -> %InternalException{message: msg}
      ["InterruptException", msg] -> %InterruptException{message: msg}
      ["InvalidInputException", msg] -> %InvalidInputException{message: msg}
      ["InvalidTypeException", msg] -> %InvalidTypeException{message: msg}
      ["IOException", msg] -> %IOException{message: msg}
      ["NotImplementedException", msg] -> %NotImplementedException{message: msg}
      ["OutOfMemoryException", msg] -> %OutOfMemoryException{message: msg}
      ["OutOfRangeException", msg] -> %OutOfRangeException{message: msg}
      ["ParserException", msg] -> %ParserException{message: msg}
      ["PermissionException", msg] -> %PermissionException{message: msg}
      ["SequenceException", msg] -> %SequenceException{message: msg}
      ["SerializationException", msg] -> %SerializationException{message: msg}
      ["SyntaxException", msg] -> %SyntaxException{message: msg}
      ["TransactionException", msg] -> %TransactionException{message: msg}
      ["TypeMismatchException", msg] -> %TypeMismatchException{message: msg}
      # DB-API 2.0 exceptions
      ["DatabaseError", msg] -> %DatabaseError{message: msg}
      ["DataError", msg] -> %DataError{message: msg}
      ["OperationalError", msg] -> %OperationalError{message: msg}
      ["IntegrityError", msg] -> %IntegrityError{message: msg}
      ["InternalError", msg] -> %InternalError{message: msg}
      ["ProgrammingError", msg] -> %ProgrammingError{message: msg}
      ["NotSupportedError", msg] -> %NotSupportedError{message: msg}
      # Fallback to generic Error
      _ -> %Error{message: error_string}
    end
  end
end
