# DuckDB Elixir Port - Implementation Agent Instructions

## Mission

You are implementing a **100% exact port** of the DuckDB Python client to Elixir. This is not an adaptation or interpretation—it is a faithful recreation of the Python API with Elixir idioms.

## Critical Rules

1. **ALWAYS** reference `duckdb-python/` directory for implementation details
2. **NEVER** guess or invent behavior—check the Python source first
3. **MUST** use Test-Driven Development (TDD) approach
4. **MUST** port tests from `duckdb-python/tests/` before implementing features
5. **MUST** use Mox for mocking during Elixir-side development
6. **MUST** verify Docker environment builds before implementing
7. **MUST** write implementation stubs that fail tests initially

## Required Reading

Before starting ANY implementation work, you MUST read:

1. **`docs/TECHNICAL_DESIGN.md`** - Complete technical architecture
2. **`docs/IMPLEMENTATION_ROADMAP.md`** - Phased implementation plan
3. **`docs/PYTHON_API_REFERENCE.md`** - Complete Python API catalog

## Development Methodology: Test-Driven Development

### TDD Workflow (MANDATORY)

For every feature you implement, follow this EXACT sequence:

#### Step 1: Port Python Tests
```elixir
# 1. Find relevant test in duckdb-python/tests/
# Example: duckdb-python/tests/fast/test_connection.py

# 2. Port to ExUnit format
defmodule DuckdbEx.ConnectionTest do
  use ExUnit.Case

  # Port each Python test function to Elixir
  test "connect to memory database" do
    # This WILL fail initially
    {:ok, conn} = DuckdbEx.connect(:memory)
    assert conn != nil
  end
end
```

#### Step 2: Create Implementation Stubs
```elixir
# lib/duckdb_ex/connection.ex
defmodule DuckdbEx.Connection do
  @moduledoc """
  DuckDB connection management.

  Reference: duckdb-python/src/duckdb_py/include/duckdb_python/pyconnection/pyconnection.hpp
  """

  @type t :: reference()

  @spec connect(String.t() | :memory, keyword()) :: {:ok, t()} | {:error, term()}
  def connect(_database, _opts \\\\ []) do
    # Stub implementation - SHOULD FAIL TESTS
    raise "Not implemented yet"
  end
end
```

#### Step 3: Run Tests (They MUST Fail)
```bash
mix test
# Expected: Failures because stubs raise/return wrong values
```

#### Step 4: Implement NIF Layer (Rust)
```rust
// native/duckdb_nif/src/connection.rs

use rustler::{Encoder, Env, Error, ResourceArc, Term};
use duckdb::Connection as DuckDBConnection;

#[derive(Debug)]
pub struct ConnectionResource {
    inner: Mutex<DuckDBConnection>,
}

#[rustler::nif]
fn new_connection(path: String) -> Result<ResourceArc<ConnectionResource>, Error> {
    let conn = DuckDBConnection::open(&path)
        .map_err(|e| Error::Term(Box::new(e.to_string())))?;

    Ok(ResourceArc::new(ConnectionResource {
        inner: Mutex::new(conn),
    }))
}
```

#### Step 5: Implement Elixir Wrapper
```elixir
defmodule DuckdbEx.Connection do
  alias DuckdbEx.Native

  def connect(database, opts \\\\ []) do
    path = case database do
      :memory -> ":memory:"
      str when is_binary(str) -> str
    end

    case Native.new_connection(path) do
      {:ok, conn_ref} -> {:ok, conn_ref}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

#### Step 6: Run Tests Again
```bash
mix test
# Expected: Tests now pass
```

#### Step 7: Verify Against Python Behavior
```bash
# Run equivalent Python code to verify exact behavior
python3 -c "import duckdb; conn = duckdb.connect(':memory:'); print(conn)"
```

## Docker Environment Setup (DO THIS FIRST)

### Create Dockerfile

```dockerfile
# Dockerfile
FROM elixir:1.18-alpine

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    curl \
    rust \
    cargo \
    sqlite-dev

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set working directory
WORKDIR /app

# Copy project files
COPY mix.exs mix.lock ./
COPY config ./config
RUN mix deps.get
RUN mix deps.compile

COPY . .

# Compile project
RUN mix compile

CMD ["iex", "-S", "mix"]
```

### Create docker-compose.yml

```yaml
# docker-compose.yml
version: '3.8'

services:
  dev:
    build: .
    volumes:
      - .:/app
      - build:/app/_build
      - deps:/app/deps
    environment:
      - MIX_ENV=dev
    command: iex -S mix

  test:
    build: .
    volumes:
      - .:/app
      - build:/app/_build
      - deps:/app/deps
    environment:
      - MIX_ENV=test
    command: mix test

volumes:
  build:
  deps:
```

### Build and Verify
```bash
# Build the Docker environment
docker-compose build

# Run tests (should pass even if empty)
docker-compose run test

# Start dev shell
docker-compose run dev
```

## Project Structure to Create

### Phase 0 Deliverables

```
/home/home/p/g/n/duckdb_ex/
├── Dockerfile                 # CREATE THIS
├── docker-compose.yml         # CREATE THIS
├── mix.exs                    # UPDATE: Add dependencies
├── config/
│   └── config.exs            # CREATE: Basic config
├── lib/
│   └── duckdb_ex/
│       ├── native.ex         # CREATE: NIF wrapper
│       ├── connection.ex     # CREATE: Connection module stub
│       ├── relation.ex       # CREATE: Relation module stub
│       ├── result.ex         # CREATE: Result module stub
│       ├── type.ex           # CREATE: Type module stub
│       └── exceptions.ex     # CREATE: All exception modules
├── native/
│   └── duckdb_nif/
│       ├── Cargo.toml        # CREATE: Rust project
│       └── src/
│           ├── lib.rs        # CREATE: NIF entry point
│           ├── connection.rs # CREATE: Connection resource
│           └── error.rs      # CREATE: Error mapping
├── test/
│   ├── test_helper.exs       # UPDATE: Test setup
│   ├── duckdb_ex_test.exs    # CREATE: Module-level tests
│   ├── connection_test.exs   # CREATE: Connection tests
│   ├── relation_test.exs     # CREATE: Relation tests
│   └── support/
│       └── fixtures/         # CREATE: Test data files
└── docs/
    ├── TECHNICAL_DESIGN.md   # ✓ Already created
    ├── IMPLEMENTATION_ROADMAP.md  # ✓ Already created
    └── PYTHON_API_REFERENCE.md    # ✓ Already created
```

## Dependencies to Add

### mix.exs
```elixir
defmodule DuckdbEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :duckdb_ex,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Add these
      compilers: [:rustler] ++ Mix.compilers(),
      rustler_crates: [
        duckdb_nif: [
          path: "native/duckdb_nif",
          mode: :release
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # NIF framework
      {:rustler, "~> 0.35.0"},

      # Decimal precision
      {:decimal, "~> 2.0"},

      # JSON
      {:jason, "~> 1.4"},

      # Documentation
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},

      # Testing
      {:mox, "~> 1.0", only: :test},
      {:stream_data, "~> 1.0", only: :test},

      # Optional: Explorer integration
      {:explorer, "~> 0.11", optional: true},

      # Optional: Nx integration
      {:nx, "~> 0.9", optional: true}
    ]
  end
end
```

### native/duckdb_nif/Cargo.toml
```toml
[package]
name = "duckdb_nif"
version = "0.1.0"
edition = "2021"

[lib]
name = "duckdb_nif"
crate-type = ["cdylib"]

[dependencies]
rustler = "0.35"
duckdb = { version = "1.1", features = ["bundled"] }
```

## Implementation Sequence

### STOP! Before You Start

1. ✅ Have you read ALL three docs files?
2. ✅ Have you created the Docker environment?
3. ✅ Does `docker-compose run test` work?
4. ✅ Have you added all dependencies to mix.exs?
5. ✅ Have you initialized the Rust NIF project?

If any answer is NO, STOP and complete that step first.

### Phase 0: Infrastructure (START HERE)

**Objective**: Get the build system working

1. **Create Dockerfile and docker-compose.yml**
   - Use templates above
   - Build: `docker-compose build`
   - Verify: `docker-compose run dev`

2. **Initialize Rustler**
   ```bash
   # In project root
   mix rustler.new duckdb_nif
   ```

3. **Update mix.exs**
   - Add all dependencies listed above
   - Configure Rustler compiler
   - Run: `docker-compose run dev mix deps.get`

4. **Create Basic NIF**
   ```rust
   // native/duckdb_nif/src/lib.rs
   use rustler::{Env, Term};

   rustler::init!("Elixir.DuckdbEx.Native", [
       test_nif
   ]);

   #[rustler::nif]
   fn test_nif() -> String {
       "NIF is working!".to_string()
   }
   ```

   ```elixir
   # lib/duckdb_ex/native.ex
   defmodule DuckdbEx.Native do
     use Rustler, otp_app: :duckdb_ex, crate: "duckdb_nif"

     def test_nif(), do: :erlang.nif_error(:nif_not_loaded)
   end
   ```

5. **Verify Build**
   ```bash
   docker-compose run dev mix compile
   docker-compose run dev iex -S mix
   # In IEx:
   iex> DuckdbEx.Native.test_nif()
   "NIF is working!"
   ```

6. **Create Exception Modules**
   ```elixir
   # lib/duckdb_ex/exceptions.ex
   defmodule DuckdbEx.Exceptions do
     # Reference: duckdb-python/duckdb/__init__.py

     defmodule Error do
       defexception [:message]
     end

     # ... create ALL exception types from PYTHON_API_REFERENCE.md
     # Each should be a simple defexception with :message field
   end
   ```

7. **Create Module Stubs**
   - `lib/duckdb_ex/connection.ex` - Empty module with @moduledoc
   - `lib/duckdb_ex/relation.ex` - Empty module with @moduledoc
   - `lib/duckdb_ex/result.ex` - Empty module with @moduledoc
   - `lib/duckdb_ex/type.ex` - Empty module with @moduledoc

8. **Create Test Infrastructure**
   ```elixir
   # test/test_helper.exs
   ExUnit.start()

   # Import Mox for mocking
   Mox.defmock(DuckdbEx.MockNative, for: DuckdbEx.NativeBehaviour)
   ```

9. **CHECKPOINT**: Docker builds, tests run, NIF loads

### Phase 1: Basic Connection (IMPLEMENT THIS AFTER PHASE 0)

**Reference Files**:
- Python: `duckdb-python/src/duckdb_py/pyconnection/`
- Tests: `duckdb-python/tests/fast/test_connection.py`

#### Step 1.1: Port Connection Tests

Create `test/connection_test.exs`:

```elixir
defmodule DuckdbEx.ConnectionTest do
  use ExUnit.Case

  # Reference: duckdb-python/tests/fast/test_connection.py

  describe "connect/2" do
    test "connects to memory database" do
      {:ok, conn} = DuckdbEx.Connection.connect(:memory)
      assert is_reference(conn)
    end

    test "connects to file database" do
      path = "/tmp/test_#{:rand.uniform(10000)}.db"
      {:ok, conn} = DuckdbEx.Connection.connect(path)
      assert is_reference(conn)
      DuckdbEx.Connection.close(conn)
      File.rm(path)
    end

    test "returns error for invalid path" do
      {:error, _reason} = DuckdbEx.Connection.connect("/invalid/path/db.duckdb")
    end

    # Port MORE tests from Python test_connection.py
  end

  describe "close/1" do
    test "closes connection successfully" do
      {:ok, conn} = DuckdbEx.Connection.connect(:memory)
      assert :ok = DuckdbEx.Connection.close(conn)
    end
  end

  # Continue porting tests...
end
```

**RUN TESTS**: `docker-compose run test` - Should FAIL because connect/2 not implemented

#### Step 1.2: Implement NIF Layer

```rust
// native/duckdb_nif/src/connection.rs
use rustler::{Encoder, Env, Error, ResourceArc, Term};
use duckdb::Connection as DuckDBConnection;
use std::sync::Mutex;

pub struct ConnectionResource {
    pub inner: Mutex<DuckDBConnection>,
}

#[rustler::nif]
pub fn new_connection(path: String) -> Result<ResourceArc<ConnectionResource>, Error> {
    let db_path = if path == ":memory:" {
        ":memory:"
    } else {
        &path
    };

    let conn = DuckDBConnection::open(db_path)
        .map_err(|e| Error::Term(Box::new(format!("Connection error: {}", e))))?;

    Ok(ResourceArc::new(ConnectionResource {
        inner: Mutex::new(conn),
    }))
}

#[rustler::nif]
pub fn close_connection(conn: ResourceArc<ConnectionResource>) -> Result<(), Error> {
    // Connection is closed when resource is dropped
    drop(conn);
    Ok(())
}
```

```rust
// native/duckdb_nif/src/lib.rs
mod connection;

use rustler::{Env, Term};

fn on_load(env: Env, _info: Term) -> bool {
    rustler::resource!(connection::ConnectionResource, env);
    true
}

rustler::init!(
    "Elixir.DuckdbEx.Native",
    [
        connection::new_connection,
        connection::close_connection,
    ],
    load = on_load
);
```

#### Step 1.3: Implement Elixir Wrapper

```elixir
# lib/duckdb_ex/connection.ex
defmodule DuckdbEx.Connection do
  @moduledoc """
  DuckDB connection management.

  This module provides a faithful port of the DuckDBPyConnection class.

  Reference: duckdb-python/src/duckdb_py/include/duckdb_python/pyconnection/pyconnection.hpp

  ## Examples

      iex> {:ok, conn} = DuckdbEx.Connection.connect(:memory)
      iex> DuckdbEx.Connection.close(conn)
      :ok
  """

  alias DuckdbEx.Native
  alias DuckdbEx.Exceptions

  @type t :: reference()

  @doc """
  Opens a connection to a DuckDB database.

  ## Parameters

  - `database` - Database path or `:memory:` for in-memory database
  - `opts` - Connection options (keyword list)
    - `:read_only` - Open in read-only mode (default: false)
    - `:config` - Database configuration map

  ## Examples

      {:ok, conn} = DuckdbEx.Connection.connect(:memory)
      {:ok, conn} = DuckdbEx.Connection.connect("/path/to/db.duckdb")
      {:ok, conn} = DuckdbEx.Connection.connect(:memory, config: %{"threads" => 4})

  Reference: duckdb.connect() in Python
  """
  @spec connect(String.t() | :memory, keyword()) :: {:ok, t()} | {:error, term()}
  def connect(database, opts \\\\ []) do
    path = database_path(database)

    case Native.new_connection(path) do
      {:ok, conn_ref} -> {:ok, conn_ref}
      {:error, reason} -> {:error, %Exceptions.ConnectionException{message: reason}}
    end
  end

  @doc """
  Closes the database connection.

  Reference: DuckDBPyConnection.close() in Python
  """
  @spec close(t()) :: :ok
  def close(conn) do
    case Native.close_connection(conn) do
      {:ok, _} -> :ok
      {:error, _} -> :ok  # Already closed
    end
  end

  defp database_path(:memory), do: ":memory:"
  defp database_path(path) when is_binary(path), do: path
end
```

#### Step 1.4: Run Tests
```bash
docker-compose run test
# Should now PASS basic connection tests
```

#### Step 1.5: Reference Python for Exact Behavior

Before moving on, verify behavior matches Python:

```bash
# In Python
python3 << EOF
import duckdb
conn = duckdb.connect(':memory:')
print(type(conn))
print(conn)
conn.close()
EOF
```

Compare output with Elixir version. Adjust if needed.

### Continue with Each Feature...

For each subsequent feature (execute, fetch, types, relations, etc.):

1. Read relevant section in PYTHON_API_REFERENCE.md
2. Port tests from `duckdb-python/tests/`
3. Run tests (should fail)
4. Check Python source for exact implementation
5. Implement Rust NIF
6. Implement Elixir wrapper
7. Run tests (should pass)
8. Verify against Python behavior
9. Document any differences

## Testing Guidelines

### Test Categories

1. **Unit Tests**: Test individual functions
2. **Integration Tests**: Test complete workflows
3. **Property Tests**: Use StreamData for property-based testing
4. **Comparison Tests**: Compare results with Python client

### Example Property Test

```elixir
defmodule DuckdbEx.TypePropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  property "round-trip integer values" do
    check all int <- integer() do
      {:ok, conn} = DuckdbEx.Connection.connect(:memory)
      {:ok, result} = DuckdbEx.Connection.execute(conn, "SELECT ?", [int])
      {:ok, [{returned}]} = DuckdbEx.Result.fetch_all(result)
      assert returned == int
    end
  end
end
```

### Test Fixtures

Copy test data from `duckdb-python/tests/`:

```bash
# Copy CSV/Parquet/JSON fixtures
cp -r duckdb-python/tests/fast/data test/support/fixtures/
```

## Error Handling

### NIF Error Mapping

All DuckDB errors must be mapped to appropriate Elixir exceptions:

```rust
// native/duckdb_nif/src/error.rs

pub fn map_duckdb_error(err: duckdb::Error) -> String {
    match err {
        duckdb::Error::DuckDBFailure(_, msg) => {
            // Parse msg to determine exception type
            if msg.contains("Binder Error") {
                format!("BinderException:{}", msg)
            } else if msg.contains("Catalog Error") {
                format!("CatalogException:{}", msg)
            }
            // ... map all error types
        }
        _ => format!("Error:{}", err)
    }
}
```

```elixir
# lib/duckdb_ex/native.ex
defmodule DuckdbEx.Native do
  # ...

  @doc false
  def handle_error({:error, error_string}) do
    case String.split(error_string, ":", parts: 2) do
      ["BinderException", msg] ->
        {:error, %DuckdbEx.Exceptions.BinderException{message: msg}}
      ["CatalogException", msg] ->
        {:error, %DuckdbEx.Exceptions.CatalogException{message: msg}}
      # ... handle all exception types
      _ ->
        {:error, %DuckdbEx.Exceptions.Error{message: error_string}}
    end
  end
end
```

## Documentation Requirements

Every module must have:

```elixir
defmodule DuckdbEx.SomeModule do
  @moduledoc """
  Brief description of module.

  Longer description explaining purpose and usage.

  Reference: duckdb-python/path/to/corresponding/file.hpp

  ## Examples

      iex> # Working example
      iex> {:ok, result} = DuckdbEx.SomeModule.some_function()
  """

  @doc """
  Function description.

  ## Parameters

  - `param1` - Description
  - `param2` - Description

  ## Returns

  Description of return value

  ## Examples

      iex> DuckdbEx.SomeModule.some_function(arg)
      {:ok, result}

  Reference: Python equivalent function name and location
  """
  @spec some_function(term()) :: {:ok, term()} | {:error, term()}
  def some_function(param) do
    # implementation
  end
end
```

## Common Pitfalls to Avoid

### ❌ DON'T

1. **Don't guess Python behavior** - Always check source
2. **Don't skip tests** - TDD is mandatory
3. **Don't implement without reading docs** - Read ALL reference docs first
4. **Don't change API without documenting** - Any deviation must be justified
5. **Don't use BEAM processes for connections** - Use NIF resources
6. **Don't forget error handling** - Every NIF call can fail

### ✅ DO

1. **Do reference Python source constantly**
2. **Do port tests before implementing**
3. **Do verify behavior against Python**
4. **Do use proper type specs**
5. **Do document everything**
6. **Do write property tests**
7. **Do test concurrent access**
8. **Do check for memory leaks**

## When You Need Help

If you encounter:

1. **Ambiguous Python behavior**: Run Python code to clarify
2. **Rust compilation errors**: Check Rustler documentation
3. **Type conversion issues**: Reference TECHNICAL_DESIGN.md type mapping
4. **Test failures**: Compare with equivalent Python test output
5. **Performance issues**: Profile and compare with Python

## Success Criteria for Each Phase

Before considering a phase complete:

- [ ] All Python tests ported
- [ ] All ported tests passing
- [ ] No memory leaks (test with `:observer`)
- [ ] All public functions documented
- [ ] Type specs complete
- [ ] Behavior verified against Python
- [ ] Code reviewed
- [ ] Integration tests passing

## Final Checklist

Before submitting implementation:

- [ ] Docker environment builds successfully
- [ ] All tests pass: `docker-compose run test`
- [ ] Documentation generates: `mix docs`
- [ ] No compiler warnings
- [ ] Code formatted: `mix format`
- [ ] Dialyzer passes (if configured)
- [ ] CHANGELOG.md updated
- [ ] Example code in README works

## Remember

This is a **port**, not a redesign. When in doubt:

1. Check `duckdb-python/` source
2. Run Python version to see behavior
3. Port that exact behavior to Elixir
4. Document if you must deviate

**Your goal**: An Elixir developer should be able to use DuckDB with the exact same semantics as the Python client, just with Elixir syntax.

Good luck! 🦆
