defmodule EctoTimexDuration.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_timex_duration,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:postgrex, "~> 0.14.0 or ~> 0.15.0 or ~> 0.16.0", optional: true},
      {:ecto, "~> 3.0", optional: true},
      {:phoenix_html, "~> 3.0", optional: true},
      {:timex, "~> 3.7"}
    ]
  end
end
