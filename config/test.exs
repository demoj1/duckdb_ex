import Config

# Test configuration
config :duckdb_ex,
  default_connection: [
    database: ":memory:",
    config: [
      threads: 2,
      max_memory: "512MB"
    ]
  ]
