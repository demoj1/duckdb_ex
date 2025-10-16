import Config

# Production configuration
# Users should override these settings in runtime.exs or releases
config :duckdb_ex,
  default_connection: [
    database: ":memory:",
    config: [
      threads: :auto,
      max_memory: "4GB"
    ]
  ]
