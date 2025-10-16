import Config

# Development configuration
config :duckdb_ex,
  default_connection: [
    database: ":memory:",
    config: [
      threads: 4,
      max_memory: "2GB"
    ]
  ]
