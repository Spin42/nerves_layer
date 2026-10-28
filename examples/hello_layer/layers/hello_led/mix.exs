defmodule HelloLed.MixProject do
  use Mix.Project

  # A layer kept inside the firmware project that only ships its own
  # device-tree overlay source.
  def project do
    [
      app: :hello_led,
      version: "0.1.0",
      elixir: "~> 1.17",
      compilers: Mix.compilers() ++ [:nerves_layer],
      deps: [{:nerves_layer, path: "../../../.."}],
      nerves_layer: [
        dt_overlays: ["hello-led"],
        config_txt: ["dtoverlay=hello-led"]
      ]
    ]
  end
end
