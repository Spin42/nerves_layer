defmodule NervesLayer.HifiberryDacplus.Layer do
  @moduledoc """
  What the DAC+ layer adds to the firmware: the codec, amplifier, clock and
  machine driver modules, and the `hifiberry-dacplus` overlay, which the
  system builds but doesn't put on the boot partition, enabled in
  `config.txt`.
  """

  @behaviour NervesLayer.Layer

  @impl NervesLayer.Layer
  def layer(layer, _opts) do
    layer
    |> NervesLayer.Kernel.add_fragment("linux.fragment")
    |> NervesLayer.DeviceTree.add_overlay("hifiberry-dacplus")
    |> NervesLayer.RaspberryPi.enable_overlay("hifiberry-dacplus")
  end
end
