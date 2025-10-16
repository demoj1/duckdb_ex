# Persistent Database Example
# Run with: mix run examples/07_persistent_database.exs

alias DuckdbEx.Connection

IO.puts("=== Persistent Database ===\n")

db_path = "/tmp/myapp.duckdb"

# Clean up any existing database
if File.exists?(db_path) do
  File.rm!(db_path)
  IO.puts("✓ Cleaned up existing database")
end

# Connect to persistent database
IO.puts("1. Creating persistent database at #{db_path}:")
{:ok, conn} = Connection.connect(db_path)
IO.puts("✓ Connected to persistent database")

# Create and populate table
IO.puts("\n2. Creating table and inserting data:")

{:ok, _} =
  Connection.execute(conn, """
    CREATE TABLE users (
      id INTEGER PRIMARY KEY,
      username VARCHAR UNIQUE,
      email VARCHAR,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  """)

{:ok, _} =
  Connection.execute(conn, """
    INSERT INTO users (id, username, email) VALUES
      (1, 'alice', 'alice@example.com'),
      (2, 'bob', 'bob@example.com'),
      (3, 'carol', 'carol@example.com')
  """)

{:ok, rows} = Connection.fetch_all(conn, "SELECT * FROM users")
IO.puts("✓ Inserted #{length(rows)} users")

# Close connection
Connection.close(conn)
IO.puts("\n3. Closed connection")

# Verify database file exists
file_size = File.stat!(db_path).size
IO.puts("✓ Database file size: #{file_size} bytes")

# Reconnect and verify data persists
IO.puts("\n4. Reopening database to verify persistence:")
{:ok, conn2} = Connection.connect(db_path)
{:ok, rows} = Connection.fetch_all(conn2, "SELECT * FROM users ORDER BY id")

IO.puts("✓ Data persisted! Found #{length(rows)} users:")

Enum.each(rows, fn user ->
  IO.puts("  - #{user["username"]} (#{user["email"]})")
end)

# Add more data in second session
IO.puts("\n5. Adding more data:")

{:ok, _} =
  Connection.execute(conn2, """
    INSERT INTO users (id, username, email) VALUES
      (4, 'david', 'david@example.com'),
      (5, 'eve', 'eve@example.com')
  """)

{:ok, [count]} = Connection.fetch_all(conn2, "SELECT COUNT(*) as total FROM users")
IO.puts("✓ Now have #{count["total"]} users total")

# Read-only connection
IO.puts("\n6. Opening read-only connection:")
{:ok, readonly_conn} = Connection.connect(db_path, read_only: true)
{:ok, rows} = Connection.fetch_all(readonly_conn, "SELECT username FROM users ORDER BY id")
IO.puts("✓ Read-only access successful, users:")

Enum.each(rows, fn user ->
  IO.puts("  - #{user["username"]}")
end)

# Try to write with read-only connection (should fail)
IO.puts("\n7. Attempting write with read-only connection:")

case Connection.execute(
       readonly_conn,
       "INSERT INTO users (id, username, email) VALUES (6, 'frank', 'frank@example.com')"
     ) do
  {:error, error} ->
    IO.puts("✗ Write correctly blocked: #{error.message}")

  {:ok, _} ->
    IO.puts("⚠ Warning: Write should have been blocked!")
end

# Checkpoint to flush WAL
IO.puts("\n8. Creating checkpoint:")
{:ok, _} = Connection.checkpoint(conn2)
IO.puts("✓ Checkpoint created")

Connection.close(conn2)
Connection.close(readonly_conn)

# Final size
final_size = File.stat!(db_path).size
IO.puts("\n9. Final database file size: #{final_size} bytes")

# Show database info
IO.puts("\n10. Database info:")
{:ok, conn3} = Connection.connect(db_path)

{:ok, tables} =
  Connection.fetch_all(conn3, """
    SELECT table_name, estimated_size
    FROM duckdb_tables()
    WHERE schema_name = 'main'
  """)

Enum.each(tables, fn table ->
  IO.puts("  - Table '#{table["table_name"]}': ~#{table["estimated_size"]} rows")
end)

Connection.close(conn3)

IO.puts("\n✓ Done")
IO.puts("\nDatabase saved at: #{db_path}")
IO.puts("You can explore it with: duckdb #{db_path}")
