defmodule NervesLayer.DeviceTree do
  @moduledoc """
  Device-tree overlays, put on the boot partition next to the system's own.

  As a layer entry:

      {NervesLayer.DeviceTree, overlays: ["hello-led"]}

  An overlay is only shipped by this module; the bootloader applies it once
  it's enabled, for example with `NervesLayer.RaspberryPi.enable_overlay/3`.

  Putting overlays on the boot partition needs a Raspberry Pi system for
  now: they go to `overlays/` wherever its `fwup.conf` writes `config.txt`.

  ## Options

    * `:overlays` - overlay names. See `add_overlay/2`.
  """

  @behaviour NervesLayer.Layer

  @impl NervesLayer.Layer
  def layer(layer, opts) do
    opts = NervesLayer.validate_opts!(opts, [:overlays], __MODULE__)
    Enum.reduce(opts[:overlays] || [], layer, &add_overlay(&2, &1))
  end

  @doc """
  Puts the overlay `<name>.dtbo` on the boot partition.

  It's looked up in the layer's `overlays/` directory as a source,
  `<name>.dtso` or `<name>.dts`, compiled like the kernel compiles its own
  overlays, with the kernel's headers available to `#include`; then as a
  prebuilt `<name>.dtbo`; then among the overlays the system builds,
  `images/rpi-firmware/overlays/`. An overlay the system's `fwup.conf`
  already writes is left as it is.
  """
  @spec add_overlay(NervesLayer.t(), String.t()) :: NervesLayer.t()
  def add_overlay(%NervesLayer{} = layer, name) do
    %{layer | dt_overlays: layer.dt_overlays ++ [name]}
  end
end
