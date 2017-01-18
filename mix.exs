defmodule Bootloader.Mixfile do
  use Mix.Project

  def project do
    [app: :bootloader,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     elixirc_paths: elixirc_paths(Mix.env),
     deps: deps()]
  end

  def application do
    [extra_applications: [],
     mod: {Bootloader, []}]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [{:distillery, "~> 1.0", runtime: false}]
  end
end