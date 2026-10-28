defmodule HelloLayer.MixProject do
  use Mix.Project

  @app :hello_layer
  @version "0.1.0"
  @all_targets [:rpi4, :rpi5]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.19",
      archives: [nerves_bootstrap: "~> 1.15"],
      listeners: listeners(Mix.target(), Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: [{@app, release()}]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {HelloLayer.Application, []}
    ]
  end

  def cli do
    [preferred_targets: [run: :host, test: :host]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dependencies for all targets
      {:nerves, "~> 1.13", runtime: false},
      {:shoehorn, "~> 0.9.1"},
      {:ring_logger, "~> 0.11.0"},
      {:toolshed, "~> 0.4.0"},

      # Allow Nerves.Runtime on host to support development, testing and CI.
      # See config/host.exs for usage.
      {:nerves_runtime, "~> 0.13.12"},

      # Layers build nothing for the host, so a layer with runtime helpers
      # can be a dependency on every target.
      {:nerves_layer_hifiberry_dacplus, path: "../nerves_layer_hifiberry_dacplus"},

      # Dependencies for all targets except :host
      {:nerves_pack, "~> 0.7.1", targets: @all_targets},
      {:hello_led, path: "layers/hello_led", targets: @all_targets},

      # Dependencies for specific targets
      # NOTE: It's generally low risk and recommended to follow minor version
      # bumps to Nerves systems. Since these include Linux kernel and Erlang
      # version updates, please review their release notes in case
      # changes to your application are needed.
      {:nerves_system_rpi4, "~> 2.1", runtime: false, targets: :rpi4},
      {:nerves_system_rpi5, "~> 2.1", runtime: false, targets: :rpi5}
    ]
  end

  # Layers and NBPR packages are installed while the firmware is built, after
  # compilation and before `mix firmware` assembles the image.
  defp aliases do
    [firmware: ["nbpr.fetch", "nerves_layer.install", "firmware"]]
  end

  def release do
    [
      overwrite: true,
      # Erlang distribution is not started automatically.
      # See https://nerves-pack.hexdocs.pm/readme.html#erlang-distribution
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod or [keep: ["Docs"]]
    ]
  end

  # Uncomment the following line if using Phoenix > 1.8.
  # defp listeners(:host, :dev), do: [Phoenix.CodeReloader]
  defp listeners(_, _), do: []
end
