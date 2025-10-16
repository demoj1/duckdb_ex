# Quick Start Checklist for Implementation Agent

## Pre-Implementation (Must Complete First!)

### Reading (Required)
- [ ] Read `PROJECT_SUMMARY.md` (this gives you the overview)
- [ ] Read `AGENT_PROMPT.md` (complete implementation instructions)
- [ ] Read `docs/TECHNICAL_DESIGN.md` (architecture)
- [ ] Read `docs/IMPLEMENTATION_ROADMAP.md` (phased plan)
- [ ] Read `docs/PYTHON_API_REFERENCE.md` (API catalog)

### Understanding Check
- [ ] I understand this is a 100% exact port, not an adaptation
- [ ] I understand I must reference `duckdb-python/` for all decisions
- [ ] I understand TDD is mandatory (tests first, then implementation)
- [ ] I understand I must use Docker for development
- [ ] I understand I must create stubs that FAIL tests initially

## Phase 0: Infrastructure Setup

### Step 1: Create Docker Environment
- [ ] Create `Dockerfile` (template in AGENT_PROMPT.md)
- [ ] Create `docker-compose.yml` (template in AGENT_PROMPT.md)
- [ ] Run: `docker-compose build`
- [ ] Verify: `docker-compose run dev` starts shell

### Step 2: Initialize Rustler
- [ ] Run: `mix rustler.new duckdb_nif`
- [ ] Accept defaults when prompted

### Step 3: Update Dependencies
- [ ] Update `mix.exs` with all dependencies (see AGENT_PROMPT.md)
- [ ] Add Rustler configuration to `mix.exs`
- [ ] Run: `docker-compose run dev mix deps.get`
- [ ] Run: `docker-compose run dev mix deps.compile`

### Step 4: Create Native/duckdb_nif/Cargo.toml
- [ ] Copy template from AGENT_PROMPT.md
- [ ] Add duckdb dependency with bundled feature

### Step 5: Create Basic NIF
- [ ] Create `native/duckdb_nif/src/lib.rs` with test_nif function
- [ ] Create `lib/duckdb_ex/native.ex` wrapper
- [ ] Run: `docker-compose run dev mix compile`
- [ ] Verify: NIF compiles without errors

### Step 6: Test NIF Loading
- [ ] Run: `docker-compose run dev iex -S mix`
- [ ] In IEx: `DuckdbEx.Native.test_nif()`
- [ ] Expected output: `"NIF is working!"`

### Step 7: Create Exception Modules
- [ ] Create `lib/duckdb_ex/exceptions.ex`
- [ ] Define ALL exception types from PYTHON_API_REFERENCE.md
- [ ] Each should be `defexception [:message]`
- [ ] Total: ~25+ exception types

### Step 8: Create Module Stubs
- [ ] Create `lib/duckdb_ex.ex` (main module)
- [ ] Create `lib/duckdb_ex/connection.ex` (with @moduledoc)
- [ ] Create `lib/duckdb_ex/relation.ex` (with @moduledoc)
- [ ] Create `lib/duckdb_ex/result.ex` (with @moduledoc)
- [ ] Create `lib/duckdb_ex/type.ex` (with @moduledoc)
- [ ] All modules should reference Python source in @moduledoc

### Step 9: Set Up Test Infrastructure
- [ ] Update `test/test_helper.exs` (add Mox setup if needed)
- [ ] Create `test/duckdb_ex_test.exs` (empty for now)
- [ ] Create `test/connection_test.exs` (empty for now)
- [ ] Create `test/support/fixtures/` directory
- [ ] Run: `docker-compose run test`
- [ ] Verify: Tests run (even if all pass because empty)

### Step 10: Phase 0 Checkpoint
- [ ] `docker-compose build` succeeds
- [ ] `docker-compose run dev` starts IEx
- [ ] `DuckdbEx.Native.test_nif()` returns "NIF is working!"
- [ ] `docker-compose run test` runs successfully
- [ ] All exception modules defined
- [ ] All module stubs created with documentation
- [ ] No compilation warnings

## Phase 1: Basic Connection (Start After Phase 0)

### Step 1: Port Python Connection Tests
- [ ] Open `duckdb-python/tests/fast/test_connection.py`
- [ ] Port first 5-10 tests to `test/connection_test.exs`
- [ ] Run: `docker-compose run test test/connection_test.exs`
- [ ] Verify: All tests FAIL (because not implemented)

### Step 2: Implement Connection Resource (Rust)
- [ ] Create `native/duckdb_nif/src/connection.rs`
- [ ] Define `ConnectionResource` struct
- [ ] Implement `new_connection` NIF function
- [ ] Implement `close_connection` NIF function
- [ ] Update `native/duckdb_nif/src/lib.rs` to export functions

### Step 3: Implement Connection Module (Elixir)
- [ ] Implement `DuckdbEx.Connection.connect/2`
- [ ] Implement `DuckdbEx.Connection.close/1`
- [ ] Add proper type specs
- [ ] Add comprehensive documentation
- [ ] Reference Python source in docs

### Step 4: Run Connection Tests
- [ ] Run: `docker-compose run test test/connection_test.exs`
- [ ] Verify: Tests now PASS
- [ ] Fix any failing tests

### Step 5: Verify Against Python
- [ ] Run equivalent Python code
- [ ] Compare behavior (connection type, error messages, etc.)
- [ ] Adjust Elixir implementation if needed

### Step 6: Port More Tests
- [ ] Continue porting tests from test_connection.py
- [ ] Implement features to make tests pass
- [ ] Repeat until all connection tests ported

## Common Commands

### Docker
```bash
# Build environment
docker-compose build

# Run tests
docker-compose run test

# Run specific test file
docker-compose run test test/connection_test.exs

# Start dev shell
docker-compose run dev

# Compile
docker-compose run dev mix compile

# Format code
docker-compose run dev mix format

# Generate docs
docker-compose run dev mix docs
```

### In IEx (docker-compose run dev)
```elixir
# Test NIF loading
DuckdbEx.Native.test_nif()

# Recompile
recompile()

# Run tests
ExUnit.run()
```

### Checking Python Behavior
```bash
# Run Python interactively
python3

# In Python
import duckdb
conn = duckdb.connect(':memory:')
print(type(conn))
# ... test specific behavior
```

## Before Moving to Next Feature

- [ ] All tests for current feature passing
- [ ] Code formatted: `docker-compose run dev mix format`
- [ ] Documentation complete
- [ ] Verified against Python behavior
- [ ] No memory leaks (check with long-running tests)
- [ ] No compiler warnings

## When You Get Stuck

### Implementation Questions
1. Check `duckdb-python/` source code
2. Run Python version to see exact behavior
3. Check Python tests for edge cases
4. Reference PYTHON_API_REFERENCE.md

### Build Issues
1. Check Dockerfile and docker-compose.yml
2. Rebuild: `docker-compose build --no-cache`
3. Check Rust version in container
4. Check duckdb-rs compatibility

### Test Failures
1. Compare with Python test output
2. Check exact error messages
3. Verify type conversions
4. Check parameter handling

### NIF Issues
1. Check Rustler documentation
2. Verify resource lifecycle
3. Check error mapping
4. Test with `:observer.start()` for memory leaks

## Remember

- **TDD is mandatory**: Tests first, implementation second
- **Reference Python always**: Never guess behavior
- **Docker for everything**: Consistent environment
- **Document as you go**: Every function needs docs
- **Verify against Python**: Run both and compare

## Progress Tracking

Current Phase: ___________

Phase 0 Completion: ___/10 steps
Phase 1 Completion: ___/6 steps

Last completed: _______________
Next task: _______________

## Quick Reference

- Implementation guide: `AGENT_PROMPT.md`
- Architecture: `docs/TECHNICAL_DESIGN.md`
- Roadmap: `docs/IMPLEMENTATION_ROADMAP.md`
- Python API: `docs/PYTHON_API_REFERENCE.md`
- Python source: `duckdb-python/`
