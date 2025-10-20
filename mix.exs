defmodule DuckdbEx.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/nshkrdotcom/duckdb_ex"

  def project do
    [
      app: :duckdb_ex,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      name: "DuckdbEx",
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Decimal precision for DuckDB DECIMAL type
      {:decimal, "~> 2.0"},

      # JSON support
      {:jason, "~> 1.4"},

      # Optional: Explorer integration
      {:explorer, "~> 0.11", optional: true},

      # Optional: Nx integration
      {:nx, "~> 0.9", optional: true},

      # Development and documentation
      {:ex_doc, "~> 0.38.2", only: :dev, runtime: false},

      # Testing
      {:mox, "~> 1.0", only: :test},
      {:stream_data, "~> 1.0", only: :test}
    ]
  end

  defp description do
    """
    A 100% faithful port of the DuckDB Python client to Elixir, using the DuckDB CLI
    for full API compatibility with the official Python client.
    """
  end

  defp docs do
    [
      main: "readme",
      name: "DuckdbEx",
      source_ref: "v#{@version}",
      source_url: @source_url,
      homepage_url: @source_url,
      assets: %{"assets" => "assets"},
      logo: "assets/duckdb_ex.svg",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "AGENT_PROMPT.md",
        "PROJECT_SUMMARY.md",
        "QUICK_START_CHECKLIST.md",
        "docs/TECHNICAL_DESIGN.md",
        "docs/IMPLEMENTATION_ROADMAP.md",
        "docs/PYTHON_API_REFERENCE.md"
      ],
      groups_for_extras: [
        Guides: ["README.md", "CHANGELOG.md", "QUICK_START_CHECKLIST.md"],
        Architecture: [
          "PROJECT_SUMMARY.md",
          "docs/TECHNICAL_DESIGN.md",
          "docs/IMPLEMENTATION_ROADMAP.md"
        ],
        Reference: [
          "AGENT_PROMPT.md",
          "docs/PYTHON_API_REFERENCE.md"
        ]
      ]
    ]
  end

  defp package do
    [
      name: "duckdb_ex",
      description: description(),
      files:
        ~w(lib mix.exs README.md CHANGELOG.md AGENT_PROMPT.md PROJECT_SUMMARY.md QUICK_START_CHECKLIST.md LICENSE docs assets),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Online documentation" => "https://hexdocs.pm/duckdb_ex",
        "DuckDB" => "https://duckdb.org"
      },
      maintainers: ["nshkrdotcom"],
      exclude_patterns: [
        "priv/plts",
        ".DS_Store",
        "duckdb-python"
      ]
    ]
  end
end
