# DuckDB Python API Reference for Porting

## Purpose

This document provides a quick reference for the agent implementing the Elixir port. It catalogs the complete Python API surface that must be ported.

## Source Location

**Primary Source**: `duckdb-python/` directory

**Key Files to Reference**:
- `duckdb-python/duckdb/__init__.py` - Module-level API exports
- `duckdb-python/src/duckdb_py/include/duckdb_python/pyconnection/pyconnection.hpp` - Connection API
- `duckdb-python/src/duckdb_py/include/duckdb_python/pyrelation.hpp` - Relation API
- `duckdb-python/src/duckdb_py/include/duckdb_python/pyresult.hpp` - Result API
- `duckdb-python/duckdb/typing/__init__.py` - Type system
- `duckdb-python/tests/` - Comprehensive test suite

## How to Use This Reference

1. When implementing a module, find the corresponding section below
2. Reference the Python source file location
3. Check all methods, parameters, and return types
4. Port the exact semantics and behavior
5. Refer to Python tests for expected behavior

## Module-Level API (duckdb module)

**Source**: `duckdb-python/duckdb/__init__.py`

### Functions Exported at Module Level

```python
# Connection management
connect(database: str = ":memory:", read_only: bool = False, config: dict = None) -> DuckDBPyConnection
default_connection() -> DuckDBPyConnection
set_default_connection(conn: DuckDBPyConnection) -> None

# Query execution (uses default connection)
execute(query: str, params: list = None) -> DuckDBPyConnection
executemany(query: str, params: list = None) -> DuckDBPyConnection
close() -> None
interrupt() -> None

# Query and relation creation
query(query: str) -> DuckDBPyRelation
sql(query: str) -> DuckDBPyRelation
table(name: str) -> DuckDBPyRelation
view(name: str) -> DuckDBPyRelation
values(values: list) -> DuckDBPyRelation
from_query(query: str) -> DuckDBPyRelation

# Data source readers
read_csv(path: str, **kwargs) -> DuckDBPyRelation
read_json(path: str, **kwargs) -> DuckDBPyRelation
read_parquet(path: str, **kwargs) -> DuckDBPyRelation
from_df(df: DataFrame) -> DuckDBPyRelation
from_arrow(arrow: Table) -> DuckDBPyRelation
from_parquet(path: str, **kwargs) -> DuckDBPyRelation
from_csv_auto(path: str, **kwargs) -> DuckDBPyRelation

# Fetch methods
fetchall() -> list
fetchone() -> tuple | None
fetchmany(size: int) -> list
fetchdf() -> DataFrame
fetchnumpy() -> dict

# Utility
extract_statements(query: str) -> list
get_table_names(query: str) -> set

# Object registration
register(name: str, obj: Any) -> DuckDBPyConnection
unregister(name: str) -> DuckDBPyConnection

# Type creation functions
list_type(type: DuckDBPyType) -> DuckDBPyType
array_type(type: DuckDBPyType, size: int) -> DuckDBPyType
map_type(key: DuckDBPyType, value: DuckDBPyType) -> DuckDBPyType
struct_type(fields: dict) -> DuckDBPyType
row_type(fields: dict) -> DuckDBPyType
union_type(members: dict) -> DuckDBPyType
enum_type(name: str, type: DuckDBPyType, values: list) -> DuckDBPyType
decimal_type(width: int, scale: int) -> DuckDBPyType
string_type(collation: str = None) -> DuckDBPyType

# Filesystem
register_filesystem(filesystem: AbstractFileSystem) -> None
unregister_filesystem(name: str) -> None
list_filesystems() -> list
filesystem_is_registered(name: str) -> bool

# Extensions
install_extension(name: str, **kwargs) -> None
load_extension(name: str) -> None

# UDF
create_function(name: str, func: Callable, **kwargs) -> DuckDBPyConnection
remove_function(name: str) -> DuckDBPyConnection

# Transactions
begin() -> DuckDBPyConnection
commit() -> DuckDBPyConnection
rollback() -> DuckDBPyConnection
checkpoint() -> DuckDBPyConnection

# Misc
query_progress() -> float
```

## DuckDBPyConnection Class

**Source**: `duckdb-python/src/duckdb_py/include/duckdb_python/pyconnection/pyconnection.hpp`

### Constructor
```python
__init__(database: str = ":memory:", read_only: bool = False, config: dict = None)
```

### Connection Management
```python
close() -> None
interrupt() -> None
```

### Context Manager
```python
__enter__() -> DuckDBPyConnection
__exit__(exc_type, exc_val, exc_tb) -> None
```

### Query Execution
```python
execute(query: str | Statement, params: list | dict = None) -> DuckDBPyConnection
executemany(query: str, params: list) -> DuckDBPyConnection
sql(query: str) -> DuckDBPyRelation
query(query: str, alias: str = "", params: list = None) -> DuckDBPyRelation
extract_statements(query: str) -> list
```

### Table/View Access
```python
table(name: str) -> DuckDBPyRelation
view(name: str) -> DuckDBPyRelation
values(*args) -> DuckDBPyRelation
table_function(name: str, *params) -> DuckDBPyRelation
```

### Data Source Readers
```python
read_csv(path: str | list, **kwargs) -> DuckDBPyRelation
read_json(path: str | list, **kwargs) -> DuckDBPyRelation
read_parquet(path: str | list, **kwargs) -> DuckDBPyRelation
from_df(df: DataFrame) -> DuckDBPyRelation
from_arrow(arrow_obj) -> DuckDBPyRelation
from_csv_auto(path: str, **kwargs) -> DuckDBPyRelation
from_parquet(path: str, **kwargs) -> DuckDBPyRelation
from_query(query: str) -> DuckDBPyRelation
```

### Result Fetching
```python
fetchone() -> tuple | None
fetchmany(size: int = 1) -> list[tuple]
fetchall() -> list[tuple]
fetchdf(date_as_object: bool = False) -> DataFrame
fetch_df(date_as_object: bool = False) -> DataFrame
fetch_df_chunk(vectors_per_chunk: int = 1, date_as_object: bool = False) -> DataFrame
fetchnumpy() -> dict
fetch_arrow_table(rows_per_batch: int) -> Table
fetch_record_batch(rows_per_batch: int) -> RecordBatchReader
pl() -> LazyFrame  # Polars
torch() -> dict  # PyTorch
tf() -> dict  # TensorFlow
```

### Result Description
```python
description -> list[tuple] | None
rowcount -> int
```

### Transactions
```python
begin() -> DuckDBPyConnection
commit() -> DuckDBPyConnection
rollback() -> DuckDBPyConnection
checkpoint() -> DuckDBPyConnection
```

### Object Registration
```python
register(name: str, obj: Any) -> DuckDBPyConnection
unregister(name: str) -> DuckDBPyConnection
append(table_name: str, df: DataFrame, by_name: bool = False) -> DuckDBPyConnection
```

### Type Creation
```python
map_type(key_type: DuckDBPyType, value_type: DuckDBPyType) -> DuckDBPyType
struct_type(fields: dict) -> DuckDBPyType
list_type(type: DuckDBPyType) -> DuckDBPyType
array_type(type: DuckDBPyType, size: int) -> DuckDBPyType
union_type(members: dict) -> DuckDBPyType
enum_type(name: str, type: DuckDBPyType, values: list) -> DuckDBPyType
decimal_type(width: int, scale: int) -> DuckDBPyType
string_type(collation: str = "") -> DuckDBPyType
type(type_str: str) -> DuckDBPyType
dtype(obj) -> DuckDBPyType
```

### UDF Management
```python
create_function(
    name: str,
    function: Callable,
    parameters: list = None,
    return_type: DuckDBPyType = None,
    type: PythonUDFType = PythonUDFType.NATIVE,
    null_handling: FunctionNullHandling = FunctionNullHandling.DEFAULT_NULL_HANDLING,
    exception_handling: PythonExceptionHandling = PythonExceptionHandling.FORWARD_ERROR,
    side_effects: bool = False
) -> DuckDBPyConnection

remove_function(name: str) -> DuckDBPyConnection
```

### Filesystem
```python
register_filesystem(filesystem: AbstractFileSystem) -> None
unregister_filesystem(name: str) -> None
list_filesystems() -> list
filesystem_is_registered(name: str) -> bool
```

### Extensions
```python
install_extension(
    extension: str,
    force_install: bool = False,
    repository: str = None,
    repository_url: str = None,
    version: str = None
) -> None

load_extension(extension: str) -> None
```

### Metadata
```python
get_table_names(query: str = "", qualified: bool = False) -> set[str]
```

### Utility
```python
cursor() -> DuckDBPyConnection  # Returns a new cursor (connection)
query_progress() -> float
```

## DuckDBPyRelation Class

**Source**: `duckdb-python/src/duckdb_py/include/duckdb_python/pyrelation.hpp`

### Properties
```python
alias -> str
columns -> list[str]
types -> list[str]
type -> str  # Relation type
dtypes -> list[str]
```

### Basic Operations
```python
project(*args, groups: str = "") -> DuckDBPyRelation
filter(condition: str | Expression) -> DuckDBPyRelation
limit(n: int, offset: int = 0) -> DuckDBPyRelation
order(expr: str) -> DuckDBPyRelation
sort(*args) -> DuckDBPyRelation
distinct() -> DuckDBPyRelation
unique(aggr_columns: str) -> DuckDBPyRelation
```

### Aliasing
```python
set_alias(alias: str) -> DuckDBPyRelation
alias(alias: str) -> DuckDBPyRelation  # Same as set_alias
```

### Aggregations
```python
aggregate(expr: str | list, groups: str = "") -> DuckDBPyRelation
any_value(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
arg_max(arg: str, val: str, groups: str = "", **kwargs) -> DuckDBPyRelation
arg_min(arg: str, val: str, groups: str = "", **kwargs) -> DuckDBPyRelation
avg(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
bit_and(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
bit_or(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
bit_xor(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
bit_string_agg(column: str, **kwargs) -> DuckDBPyRelation
bool_and(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
bool_or(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
count(column: str = "*", groups: str = "", **kwargs) -> DuckDBPyRelation
favg(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
first(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
fsum(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
geo_mean(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
histogram(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
last(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
list(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
max(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
median(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
min(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
mode(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
product(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
quantile_cont(column: str, q: float | list, **kwargs) -> DuckDBPyRelation
quantile_disc(column: str, q: float | list, **kwargs) -> DuckDBPyRelation
stddev_pop(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
stddev_samp(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
string_agg(column: str, sep: str = ",", **kwargs) -> DuckDBPyRelation
sum(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
value_counts(column: str, groups: str = "") -> DuckDBPyRelation
var_pop(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
var_samp(column: str, groups: str = "", **kwargs) -> DuckDBPyRelation
```

### Window Functions
```python
row_number(window_spec: str, projected_columns: str = "") -> DuckDBPyRelation
rank(window_spec: str, projected_columns: str = "") -> DuckDBPyRelation
dense_rank(window_spec: str, projected_columns: str = "") -> DuckDBPyRelation
percent_rank(window_spec: str, projected_columns: str = "") -> DuckDBPyRelation
cume_dist(window_spec: str, projected_columns: str = "") -> DuckDBPyRelation
ntile(window_spec: str, num_buckets: int, projected_columns: str = "") -> DuckDBPyRelation
lag(column: str, window_spec: str, offset: int = 1, **kwargs) -> DuckDBPyRelation
lead(column: str, window_spec: str, offset: int = 1, **kwargs) -> DuckDBPyRelation
first_value(column: str, window_spec: str = "", **kwargs) -> DuckDBPyRelation
last_value(column: str, window_spec: str = "", **kwargs) -> DuckDBPyRelation
nth_value(column: str, window_spec: str, offset: int, **kwargs) -> DuckDBPyRelation
```

### Set Operations
```python
union(other: DuckDBPyRelation) -> DuckDBPyRelation
except_(other: DuckDBPyRelation) -> DuckDBPyRelation  # Note: except is keyword
intersect(other: DuckDBPyRelation) -> DuckDBPyRelation
```

### Joins
```python
join(other: DuckDBPyRelation, condition: str | Expression, how: str = "inner") -> DuckDBPyRelation
cross(other: DuckDBPyRelation) -> DuckDBPyRelation
```

### Execution & Fetching
```python
execute() -> DuckDBPyRelation
fetchone() -> tuple | None
fetchmany(size: int = 1) -> list[tuple]
fetchall() -> list[tuple]
fetchdf(date_as_object: bool = False) -> DataFrame
fetch_df(date_as_object: bool = False) -> DataFrame
fetch_df_chunk(vectors_per_chunk: int = 1, date_as_object: bool = False) -> DataFrame
fetchnumpy() -> dict
fetch_arrow_table(rows_per_batch: int) -> Table
fetch_record_batch_reader(rows_per_batch: int) -> RecordBatchReader
pl(rows_per_batch: int = 1000000, lazy: bool = False) -> DataFrame | LazyFrame
torch() -> dict
tf() -> dict
```

### Data Export
```python
to_arrow_table(batch_size: int = 1000000) -> Table
to_record_batch(batch_size: int = 1000000) -> RecordBatchReader
to_csv(filename: str, **kwargs) -> None
to_parquet(filename: str, **kwargs) -> None
```

### Arrow Capsule (PyCapsule Interface)
```python
__arrow_c_stream__(requested_schema=None) -> PyCapsule
```

### Transformations
```python
map(func: Callable, schema=None) -> DuckDBPyRelation
```

### Table/View Operations
```python
create_view(name: str, replace: bool = True) -> DuckDBPyRelation
create(table_name: str) -> None
insert_into(table_name: str) -> None
insert(values: list) -> None
update(set_exprs: dict, where: str = None) -> None
```

### Metadata
```python
describe() -> DuckDBPyRelation
description -> list[tuple]
shape -> tuple[int, int]
len() -> int  # __len__
```

### SQL Generation
```python
query(view_name: str, sql_query: str) -> DuckDBPyRelation
to_sql() -> str
explain(type: ExplainType = ExplainType.PHYSICAL) -> str
```

### Display
```python
show(max_width: int = None, max_rows: int = None, **kwargs) -> None
print(max_width: int = None, max_rows: int = None, **kwargs) -> None
__str__() -> str
__repr__() -> str
```

### Attribute Access
```python
__getattr__(name: str) -> DuckDBPyRelation  # Column access
```

## Type System

**Source**: `duckdb-python/duckdb/typing/__init__.py`

### DuckDBPyType Class
```python
# Properties
id -> str
internal_type -> LogicalType

# Methods
__eq__(other) -> bool
__str__() -> str
__repr__() -> str
```

### Type Constructor Functions
```python
# Located in Connection and module level
list_type(type: DuckDBPyType) -> DuckDBPyType
array_type(type: DuckDBPyType, size: int) -> DuckDBPyType
map_type(key: DuckDBPyType, value: DuckDBPyType) -> DuckDBPyType
struct_type(fields: dict | list) -> DuckDBPyType
row_type(fields: dict | list) -> DuckDBPyType
union_type(members: dict | list) -> DuckDBPyType
enum_type(name: str, type: DuckDBPyType, values: list) -> DuckDBPyType
decimal_type(width: int, scale: int) -> DuckDBPyType
string_type(collation: str = "") -> DuckDBPyType
```

## Expression API

**Source**: `duckdb-python/src/duckdb_py/expression/`

### Base Expression
```python
class Expression:
    __str__() -> str
    __repr__() -> str
    alias(name: str) -> Expression
    cast(type: DuckDBPyType) -> Expression
    isin(*values) -> Expression
    isnotnull() -> Expression
    isnull() -> Expression
    # Operators: ==, !=, <, <=, >, >=, &, |, ~, +, -, *, /, %, **
```

### Column Expression
```python
class ColumnExpression(Expression):
    __init__(name: str)
```

### Constant Expression
```python
class ConstantExpression(Expression):
    __init__(value: Any)
```

### Function Expression
```python
class FunctionExpression(Expression):
    __init__(name: str, *args)
```

### Case Expression
```python
class CaseExpression(Expression):
    when(condition: Expression, value: Expression) -> CaseExpression
    otherwise(value: Expression) -> Expression
```

### Star Expression
```python
class StarExpression(Expression):
    exclude(*columns: str) -> StarExpression
    replace(**replacements) -> StarExpression
```

### Coalesce Operator
```python
coalesce(*expressions) -> Expression
```

## Value Types

**Source**: `duckdb-python/duckdb/value/constant/__init__.py`

All value types are subclasses of `Value`:

```python
class Value:
    type: DuckDBPyType

    def __init__(val: Any, type: DuckDBPyType = None)
    def __str__() -> str
    def __repr__() -> str
    def __eq__(other) -> bool

# Specific value types
BooleanValue(val: bool)
TinyIntValue(val: int)  # aka ByteValue
ShortValue(val: int)
IntegerValue(val: int)
BigIntValue(val: int)  # aka LongValue
HugeIntValue(val: int)
UTinyIntValue(val: int)  # aka UnsignedByteValue
USmallIntValue(val: int)  # aka UnsignedShortValue
UIntegerValue(val: int)
UBigIntValue(val: int)  # aka UnsignedLongValue
UHugeIntValue(val: int)
FloatValue(val: float)
DoubleValue(val: float)
DecimalValue(val: Decimal, width: int, scale: int)
StringValue(val: str)
BlobValue(val: bytes)
BitValue(val: str)
DateValue(val: date)
TimeValue(val: time)
TimestampValue(val: datetime)
TimestampSecondValue(val: datetime)
TimestampMillisecondValue(val: datetime)
TimestampNanosecondValue(val: datetime)
TimestampTimeZoneValue(val: datetime)
TimeTimeZoneValue(val: time)
IntervalValue(val)
UUIDValue(val: UUID | str)
ListValue(val: list, type: DuckDBPyType = None)
StructValue(val: dict, type: DuckDBPyType = None)
MapValue(val: dict, type: DuckDBPyType = None)
UnionValue(val: Any, tag: str, type: DuckDBPyType = None)
NullValue()
```

## Statement Class

**Source**: `duckdb-python/src/duckdb_py/include/duckdb_python/pystatement.hpp`

```python
class Statement:
    type: StatementType

    __str__() -> str
    __repr__() -> str
```

## Enums

### StatementType
```python
class StatementType(Enum):
    INVALID = 0
    SELECT = 1
    INSERT = 2
    UPDATE = 3
    EXPLAIN = 4
    DELETE = 5
    PREPARE = 6
    CREATE = 7
    EXECUTE = 8
    ALTER = 9
    TRANSACTION = 10
    COPY = 11
    ANALYZE = 12
    VARIABLE_SET = 13
    CREATE_FUNC = 14
    DROP = 15
    EXPORT = 16
    PRAGMA = 17
    VACUUM = 18
    CALL = 19
    SET = 20
    LOAD = 21
    RELATION = 22
    EXTENSION = 23
    LOGICAL_PLAN = 24
    ATTACH = 25
    DETACH = 26
    MULTI = 27
```

### ExplainType
```python
class ExplainType(Enum):
    STANDARD = "standard"
    ANALYZE = "analyze"
    PHYSICAL = "physical"
    PHYSICAL_ONLY = "physical_only"
    ALL_OPTIMIZATIONS = "all_optimizations"
```

### RenderMode
```python
class RenderMode(Enum):
    ROWS = "rows"
    COLUMNS = "columns"
```

### PythonUDFType
```python
class PythonUDFType(Enum):
    NATIVE = "native"
    ARROW = "arrow"
```

### PythonExceptionHandling
```python
class PythonExceptionHandling(Enum):
    FORWARD_ERROR = "default"
    RETURN_NULL = "return_null"
```

### FunctionNullHandling
```python
class FunctionNullHandling(Enum):
    DEFAULT = "default"
    SPECIAL = "special"
```

### CSVLineTerminator
```python
class CSVLineTerminator(Enum):
    SINGLE = "\n"
    CARRY_RETURN = "\r"
    BOTH = "\r\n"
```

## Exception Hierarchy

**Source**: `duckdb-python/duckdb/__init__.py` (imports from _duckdb)

```python
# Base exceptions
Error(Exception)
Warning(Exception)

# DB-API 2.0 exceptions
DatabaseError(Error)
DataError(DatabaseError)
OperationalError(DatabaseError)
IntegrityError(DatabaseError)
InternalError(DatabaseError)
ProgrammingError(DatabaseError)
NotSupportedError(DatabaseError)

# DuckDB-specific exceptions
BinderException(Error)
CatalogException(Error)
ConnectionException(Error)
ConstraintException(Error)
ConversionException(Error)
DependencyException(Error)
FatalException(Error)
HTTPException(Error)
InternalException(Error)
InterruptException(Error)
InvalidInputException(Error)
InvalidTypeException(Error)
IOException(Error)
NotImplementedException(Error)
OutOfMemoryException(Error)
OutOfRangeException(Error)
ParserException(Error)
PermissionException(Error)
SequenceException(Error)
SerializationException(Error)
SyntaxException(Error)
TransactionException(Error)
TypeMismatchException(Error)
```

## DB-API 2.0 Constants

**Source**: `duckdb-python/duckdb/__init__.py`

```python
apilevel = "2.0"
threadsafety = 1
paramstyle = "qmark"  # Also supports named parameters

# Type objects
BINARY
DATETIME
NUMBER
ROWID
STRING
```

## Filesystem Integration

**Source**: `duckdb-python/src/duckdb_py/pyfilesystem.cpp`

Requires fsspec-compatible filesystem objects:

```python
# Must implement fsspec.AbstractFileSystem protocol
class AbstractFileSystem:
    protocol: str | tuple[str, ...]

    # Required methods
    def open(path, mode, **kwargs)
    def ls(path, detail=True, **kwargs)
    def info(path, **kwargs)
    def exists(path)
    # etc.
```

## Test Files to Reference

**Critical test files** in `duckdb-python/tests/`:

### Core Functionality
- `fast/test_connection.py` - Connection tests
- `fast/test_execute.py` - Query execution
- `fast/test_fetch.py` - Result fetching
- `fast/test_types.py` - Type system
- `fast/test_dbapi.py` - DB-API compatibility

### Relational API
- `fast/relational_api/test_rapi_query.py`
- `fast/relational_api/test_rapi_aggregations.py`
- `fast/relational_api/test_rapi_windows.py`
- `fast/relational_api/test_joins.py`
- `fast/relational_api/test_pivot.py`

### Data Sources
- `fast/test_csv.py`
- `fast/test_parquet.py`
- `fast/test_json.py`
- `fast/arrow/` (directory)

### Advanced Features
- `fast/test_transaction.py`
- `fast/test_prepared.py`
- `fast/test_filesystem.py`
- `fast/udf/` (directory)

## Implementation Notes

### Key Behaviors to Preserve

1. **Lazy Evaluation**: Relations don't execute until materialized
2. **Method Chaining**: All relation methods return new relations
3. **Parameter Binding**: Support both positional (?) and named (:param)
4. **Type Inference**: Automatic type detection from Python/Elixir values
5. **Error Messages**: Preserve DuckDB's detailed error messages
6. **Default Connection**: Module-level functions use default connection
7. **Connection as Cursor**: Connection acts as its own cursor (DB-API)
8. **Context Management**: Connections support with/Enter protocol

### Differences to Document

If any behavior differs from Python (due to language differences), document in:
- Module documentation
- Migration guide
- CHANGELOG.md

### When in Doubt

1. Check the Python source code first
2. Run the Python version to see exact behavior
3. Check Python tests for edge cases
4. Ask for clarification if truly ambiguous
