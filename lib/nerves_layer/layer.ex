defmodule NervesLayer.Layer do
  @moduledoc """
  A module a layer lists in its `:nerves_layer` project option.

  `c:layer/2` receives the `t:NervesLayer.t/0` built by the entries before it
  and returns it with what this module contributes, through the helpers of
  `NervesLayer.Kernel`, `NervesLayer.DeviceTree` and
  `NervesLayer.RaspberryPi`. It only describes the layer: building and
  installing happen afterwards, for all layers together.

  It runs while the firmware is built, in `mix compile` and again in
  `mix nerves_layer.install`, so it must return the same result each time.
  """

  @callback layer(NervesLayer.t(), opts :: keyword()) :: NervesLayer.t()
end
