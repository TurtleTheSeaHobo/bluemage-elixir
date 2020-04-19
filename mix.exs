defmodule Bluemage.MixProject do
  use Mix.Project

  def project do
    [
      app: :bluemage,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Bluemage.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:circuits_gpio, "~> 0.4"},
      {:circuits_i2c, "~> 0.1"},
      {:jason, "~> 1.2"},
      {:quantum, "~> 3.0-rc"}
    ]
  end
end
