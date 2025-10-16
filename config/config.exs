import Config

# Configure DuckDB Elixir defaults
config :duckdb_ex,
  # Default connection settings
  default_connection: [
    database: ":memory:",
    config: [
      threads: 4,
      max_memory: "1GB"
    ]
  ]

# Import environment specific config
import_config "#{config_env()}.exs"
