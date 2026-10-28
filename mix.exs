defmodule NervesLayer.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/spin42/nerves_layer"

  def project do
    [
      app: :nerves_layer,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "Add kernel modules, device-tree overlays and binaries to a stock Nerves system at firmware build time",
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger, :crypto]]
  end

  def cli do
    [preferred_envs: [docs: :docs, "hex.publish": :docs]]
  end

  defp deps do
    [{:ex_doc, "~> 0.40", only: :docs, runtime: false}]
  end

  defp package do
    [
      files: ~w(lib priv mix.exs README.md CHANGELOG.md LICENSE),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v#{@version}"
    ]
  end
end
