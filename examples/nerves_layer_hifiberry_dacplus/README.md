# nerves_layer_hifiberry_dacplus

An example layer: [HiFiBerry DAC+](https://www.hifiberry.com/shop/boards/hifiberry-dac-pro/)
support for the stock `nerves_system_rpi*` systems, which don't build its
drivers.

A firmware adds it as a dependency and nothing else. While the firmware is
built, it contributes:

* the PCM512x codec, TPA6130A2 headphone amplifier, DAC Pro clock and
  machine driver kernel modules, compiled for the system's kernel
* the `hifiberry-dacplus` device-tree overlay, which the system already
  ships, written to the boot partition and enabled in `config.txt`
* the `flac` command, from [`nbpr_flac`](https://github.com/jimsynz/nbpr)

and at runtime, `NervesLayer.HifiberryDacplus` with a couple of helpers.

See [`../hello_layer`](../hello_layer) for a firmware that uses it.

## Anatomy of a layer

A layer is an ordinary Mix project. Three things make it one.

**The `:nerves_layer` compiler, dependency and entry**, in
[`mix.exs`](mix.exs):

```elixir
def project do
  [
    app: :nerves_layer_hifiberry_dacplus,
    compilers: Mix.compilers() ++ [:nerves_layer],
    nerves_layer: [NervesLayer.HifiberryDacplus.Layer],
    deps: [{:nerves_layer, github: "spin42/nerves_layer"}, ...]
  ]
end
```

This example uses `path: "../.."` instead, so it builds against the
`nerves_layer` next to it.

**A layer module**,
[`NervesLayer.HifiberryDacplus.Layer`](lib/nerves_layer/hifiberry_dacplus/layer.ex),
which says what the layer adds with nerves_layer's helpers:

```elixir
def layer(layer, _opts) do
  layer
  |> NervesLayer.Kernel.add_fragment("linux.fragment")
  |> NervesLayer.DeviceTree.add_overlay("hifiberry-dacplus")
  |> NervesLayer.RaspberryPi.enable_overlay("hifiberry-dacplus")
end
```

The same could be written in `mix.exs` with the built-in layer modules:

```elixir
nerves_layer: [
  {NervesLayer.Kernel, fragment: "linux.fragment"},
  {NervesLayer.DeviceTree, overlays: ["hifiberry-dacplus"]},
  {NervesLayer.RaspberryPi, dtoverlays: ["hifiberry-dacplus"]}
]
```

as the [`hello_led`](../hello_layer/layers/hello_led) layer does. A module
of its own lets a layer compute what it adds, from options or the target.

**The kernel config fragment**, [`linux.fragment`](linux.fragment): the
`CONFIG_` options to build as modules, in the kernel's own syntax.

```
CONFIG_SND_SOC_PCM512x_I2C=m
CONFIG_SND_BCM2708_SOC_HIFIBERRY_DACPLUS=m
```

Only the options you want are needed; Kconfig resolves what they select
(here the TPA6130A2 amplifier and the DAC Pro clock). The build rejects any
fragment that would change the system's kernel rather than add modules to
it.

The `hifiberry-dacplus` overlay comes from the system: Raspberry Pi systems
build all of the kernel's overlays but only put a few on the boot
partition, so `DeviceTree.add_overlay/2` adds it there.

Anything else in the layer is regular Elixir. Here,
[`NervesLayer.HifiberryDacplus`](lib/nerves_layer/hifiberry_dacplus.ex)
checks for the card and plays FLAC files, and the `nbpr_flac` dependency
brings the `flac` binary along.

## Building

A layer is only built as part of a firmware: `mix compile` with a Nerves
`MIX_TARGET` builds its modules against the system's
[kernel dev kit](../../README.md#kernel-dev-kits), and `mix firmware`
installs them. On the host it compiles like any other library.

```sh
mix deps.get
mix compile
```

## NBPR packages from git

NBPR packages refer to each other by path inside the
[nbpr](https://github.com/jimsynz/nbpr) repository. A sparse git dependency
checks out only one package, so `mix.exs` also points `:nbpr` and
`:nbpr_libogg` at the repository, with `override: true`.
