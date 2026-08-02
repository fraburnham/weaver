defmodule Weaver.MixProject do
  use Mix.Project

  def project do
    [
      app: :weaver,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
      # https://github.com/burrito-elixir/burrito <- this is probalby better for the release
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Weaver.Application, []}
    ]
  end

  defp deps do
    [
      {:phoenix_pubsub, "~> 2.0"},
      {:marcli, "~> 0.1.0"},
      {:makeup_syntect, "~> 0.1.4"},
      {:rustler_precompiled, "~> 0.8.2"},
      {:makeup_elixir, "~> 1.0.1"},
      {:makeup_erlang, "~> 1.1.0"},
      {:makeup_eex, "~> 2.0.2"}
    ]
  end
end
