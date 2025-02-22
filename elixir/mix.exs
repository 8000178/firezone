defmodule Firezone.MixProject do
  use Mix.Project

  def project do
    [
      name: :firezone,
      apps_path: "apps",
      version: String.trim(File.read!("VERSION")),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      docs: [
        logo: "apps/web/assets/static/images/logo.svg",
        extras: ["README.md", "SECURITY.md", "CONTRIBUTING.md"]
      ],
      deps: deps(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
      aliases: aliases(),
      releases: releases()
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      # Shared deps
      {:jason, "~> 1.2"},

      # Shared test deps
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:junit_formatter, "~> 3.3", only: [:test]},
      {:mix_audit, "~> 2.1", only: [:dev, :test]},
      {:sobelow, "~> 0.12", only: [:dev, :test]},

      # Formatter doesn't track dependencies of children applications
      {:phoenix, "~> 1.7.0"},
      {:phoenix_live_view, "~> 0.20.1"}
    ]
  end

  defp aliases do
    [
      "ecto.seed": ["ecto.create", "ecto.migrate", "run apps/domain/priv/repo/seeds.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      sobelow: ["cmd mix sobelow"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"],
      start: ["compile --no-validate-compile-env", "phx.server", "run --no-halt"]
    ]
  end

  defp releases do
    [
      web: [
        include_executables_for: [:unix],
        validate_compile_env: true,
        applications: [
          web: :permanent,
          opentelemetry: :temporary,
          opentelemetry_exporter: :permanent
        ]
      ],
      api: [
        include_executables_for: [:unix],
        validate_compile_env: true,
        applications: [
          api: :permanent,
          opentelemetry: :temporary,
          opentelemetry_exporter: :permanent
        ]
      ]
    ]
  end
end
