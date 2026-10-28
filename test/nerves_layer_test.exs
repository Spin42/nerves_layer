defmodule NervesLayerTest do
  use ExUnit.Case, async: true

  alias NervesLayer.{DeviceTree, Kernel, RaspberryPi}

  defmodule CustomLayer do
    @behaviour NervesLayer.Layer

    @impl NervesLayer.Layer
    def layer(layer, opts) do
      layer
      |> Kernel.add_fragment("linux.fragment")
      |> RaspberryPi.enable_overlay(opts[:overlay])
    end
  end

  defmodule NotALayer do
  end

  defp new(entries), do: NervesLayer.new(:my_layer, "/layer", entries)

  test "runs the entries in order" do
    layer =
      new([
        {Kernel, fragment: ["a.fragment", "b.fragment"], modules_src: "kmod"},
        {DeviceTree, overlays: ["led"]},
        {RaspberryPi, dtoverlays: ["led", {"pwm", pin: 18, func: 2}], config_txt: ["x=1"]},
        {CustomLayer, overlay: "dac"}
      ])

    assert %NervesLayer{
             app: :my_layer,
             root: "/layer",
             target: :host,
             kernel_fragments: ["a.fragment", "b.fragment", "linux.fragment"],
             kernel_modules_srcs: ["kmod"],
             dt_overlays: ["led"],
             config_txt: ["dtoverlay=led", "dtoverlay=pwm,pin=18,func=2", "x=1", "dtoverlay=dac"]
           } = layer
  end

  test "accepts a module without options" do
    assert %NervesLayer{} = new([DeviceTree])
  end

  test "rejects modules that aren't layers" do
    assert_raise Mix.Error, ~r/NotALayer doesn't implement NervesLayer.Layer/, fn ->
      new([NotALayer])
    end
  end

  test "rejects entries that aren't {module, opts}" do
    assert_raise Mix.Error, ~r/invalid :nerves_layer entry/, fn ->
      new(kernel_fragment: "linux.fragment")
    end
  end

  test "rejects unknown options" do
    assert_raise ArgumentError, ~r/unknown options \[:fragments\]/, fn ->
      new([{Kernel, fragments: "linux.fragment"}])
    end
  end
end
