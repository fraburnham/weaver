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
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:phoenix_pubsub, "~> 2.0"},
      {:marcli, "~> 0.3.1"},
      {:makeup_syntect, "~> 0.1.4"},
      {:rustler_precompiled, "~> 0.8.2"},
      {:makeup_elixir, "~> 1.0.1"},
      {:makeup_erlang, "~> 1.1.0"},
      {:makeup_eex, "~> 2.0.2"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.7.0"},
      {:ex_aws, "~> 2.1"},
      {:configparser_ex, "~> 4.0"},
      {:ex_aws_bedrock, "~> 2.5"},
      {:hackney, "~> 1.9"},
      {:exile, "~> 0.14"},
      {:anthropix, github: "fraburnham/anthropix", branch: "update-thinking-schema"},
      {:plug, "~> 1.0", only: [:dev, :test]}
    ]
  end
end
