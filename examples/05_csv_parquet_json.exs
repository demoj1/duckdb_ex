# CSV, Parquet, and JSON File Handling
# Run with: mix run examples/05_csv_parquet_json.exs

alias DuckdbEx.Connection

IO.puts("=== Working with Files (CSV, Parquet, JSON) ===\n")

{:ok, conn} = Connection.connect(:memory)

# Create sample CSV data
IO.puts("1. Creating sample CSV file:")

csv_content = """
id,name,age,city
1,Alice,30,New York
2,Bob,25,Los Angeles
3,Carol,35,Chicago
4,David,28,Houston
5,Eve,32,Phoenix
"""

File.write!("/tmp/sample_data.csv", csv_content)
IO.puts("✓ Created /tmp/sample_data.csv")

# Read CSV directly
IO.puts("\n2. Reading CSV file:")

{:ok, rows} =
  Connection.fetch_all(conn, """
    SELECT * FROM read_csv_auto('/tmp/sample_data.csv')
  """)

IO.puts("Found #{length(rows)} rows:")

Enum.each(rows, fn row ->
  IO.puts("  - #{row["name"]}, age #{row["age"]}, lives in #{row["city"]}")
end)

# Query CSV with filters
IO.puts("\n3. Filtering CSV data (age > 30):")

{:ok, rows} =
  Connection.fetch_all(conn, """
    SELECT name, age, city
    FROM read_csv_auto('/tmp/sample_data.csv')
    WHERE age > 30
    ORDER BY age DESC
  """)

Enum.each(rows, fn row ->
  IO.puts("  - #{row["name"]}: #{row["age"]} years old")
end)

# Create a table and export to Parquet
IO.puts("\n4. Exporting to Parquet:")

{:ok, _} =
  Connection.execute(conn, """
    CREATE TABLE users AS
    SELECT * FROM read_csv_auto('/tmp/sample_data.csv')
  """)

{:ok, _} =
  Connection.execute(conn, """
    COPY users TO '/tmp/users.parquet' (FORMAT PARQUET)
  """)

IO.puts("✓ Exported to /tmp/users.parquet")

# Read Parquet file
IO.puts("\n5. Reading Parquet file:")

{:ok, rows} =
  Connection.fetch_all(conn, """
    SELECT city, COUNT(*) as user_count, AVG(age)::INTEGER as avg_age
    FROM read_parquet('/tmp/users.parquet')
    GROUP BY city
    ORDER BY user_count DESC
  """)

Enum.each(rows, fn row ->
  IO.puts("  - #{row["city"]}: #{row["user_count"]} users, avg age #{row["avg_age"]}")
end)

# Export to JSON
IO.puts("\n6. Exporting to JSON:")

{:ok, _} =
  Connection.execute(conn, """
    COPY (SELECT * FROM users WHERE age >= 30) TO '/tmp/users_30plus.json'
  """)

IO.puts("✓ Exported filtered data to /tmp/users_30plus.json")

# Read the JSON file back
json_content = File.read!("/tmp/users_30plus.json")
IO.puts("\nJSON content:")
IO.puts(json_content)

# Read JSON with DuckDB
IO.puts("\n7. Reading JSON file with DuckDB:")

{:ok, rows} =
  Connection.fetch_all(conn, """
    SELECT name, age FROM read_json_auto('/tmp/users_30plus.json')
    ORDER BY age DESC
  """)

Enum.each(rows, fn row ->
  IO.puts("  - #{row["name"]}: #{row["age"]}")
end)

# Multiple file formats in one query
IO.puts("\n8. Combining CSV and Parquet in one query:")

{:ok, rows} =
  Connection.fetch_all(conn, """
    SELECT
      'CSV' as source,
      COUNT(*) as count,
      AVG(age)::INTEGER as avg_age
    FROM read_csv_auto('/tmp/sample_data.csv')
    UNION ALL
    SELECT
      'Parquet' as source,
      COUNT(*) as count,
      AVG(age)::INTEGER as avg_age
    FROM read_parquet('/tmp/users.parquet')
  """)

Enum.each(rows, fn row ->
  IO.puts("  - #{row["source"]}: #{row["count"]} records, avg age #{row["avg_age"]}")
end)

# Cleanup
IO.puts("\n9. Cleaning up temporary files:")
File.rm("/tmp/sample_data.csv")
File.rm("/tmp/users.parquet")
File.rm("/tmp/users_30plus.json")
IO.puts("✓ Temporary files deleted")

Connection.close(conn)
IO.puts("\n✓ Done")
