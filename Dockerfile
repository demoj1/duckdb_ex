# DuckDB Elixir - Development Dockerfile
# Use official DuckDB image as base, then add Elixir
FROM duckdb/duckdb:latest as duckdb

# Now build on Elixir base (use Debian for glibc compatibility with DuckDB)
FROM elixir:1.18

# Copy DuckDB binary from official image (it's at /duckdb in that image)
COPY --from=duckdb /duckdb /usr/local/bin/duckdb
RUN chmod +x /usr/local/bin/duckdb

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set working directory
WORKDIR /app

# Set environment variables
ENV MIX_ENV=dev
ENV SHELL=/bin/sh

# Copy mix files first for dependency caching
COPY mix.exs mix.lock ./

# Create config directory structure
RUN mkdir -p config

# Copy config files
COPY config ./config

# Copy the rest of the application first
COPY . .

# Install and compile dependencies
RUN mix deps.get && mix deps.compile

# Compile the project
RUN mix compile

# Default command
CMD ["iex", "-S", "mix"]
