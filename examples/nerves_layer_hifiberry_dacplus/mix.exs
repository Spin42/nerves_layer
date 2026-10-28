defmodule NervesLayerHifiberryDacplus.MixProject do
  use Mix.Project

  def project do
    [
      app: :nerves_layer_hifiberry_dacplus,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      compilers: Mix.compilers() ++ [:nerves_layer],
      deps: deps(),
      description: "HiFiBerry DAC+ support for stock Raspberry Pi Nerves systems",
      nerves_layer: [
        kernel_fragment: "linux.fragment",
        dt_overlays: ["hifiberry-dacplus"],
        config_txt: ["dtoverlay=hifiberry-dacplus"]
      ]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  # A layer published on its own depends on
  # `{:nerves_layer, github: "spin42/nerves_layer"}` instead.
  defp deps do
    [
      {:nerves_layer, path: "../.."},
      {:nbpr_flac, github: "jimsynz/nbpr", sparse: "packages/nbpr_flac"}
    ] ++ nbpr_workspace_deps()
  end

  # NBPR packages refer to each other by path inside the nbpr repository,
  # which a sparse checkout doesn't have; point them at the same repository.
  defp nbpr_workspace_deps do
    [
      {:nbpr, github: "jimsynz/nbpr", sparse: "nbpr", override: true},
      {:nbpr_libogg, github: "jimsynz/nbpr", sparse: "packages/nbpr_libogg", override: true}
    ]
  end
end
