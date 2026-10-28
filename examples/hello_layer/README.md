# hello_layer

An example firmware using layers on the stock, Hex-published
`nerves_system_rpi4` and `nerves_system_rpi5`. Neither system is rebuilt.
It uses two layers:

* [`nerves_layer_hifiberry_dacplus`](../nerves_layer_hifiberry_dacplus):
  kernel modules built from a config fragment, an overlay the system ships,
  and FLAC tools from NBPR
* [`hello_led`](layers/hello_led): a layer kept inside this project, with
  one device-tree overlay compiled from source
  ([`hello-led.dtso`](layers/hello_led/overlays/hello-led.dtso)) that makes
  GPIO 17 (header pin 11) a heartbeat LED

## Using layers in a firmware

Add the layers as dependencies:

```elixir
{:nerves_layer_hifiberry_dacplus, path: "../nerves_layer_hifiberry_dacplus"},
{:hello_led, path: "layers/hello_led", targets: @all_targets},
```

and run `mix nerves_layer.install` before `mix firmware`:

```elixir
defp aliases do
  [firmware: ["nbpr.fetch", "nerves_layer.install", "firmware"]]
end
```

(`nbpr.fetch` is only there for the NBPR package the DAC+ layer depends
on.) That's all: `mix compile` builds the layers for the system's kernel and
`mix firmware` puts the modules, overlays and `config.txt` lines in the
image. Nothing layer-specific runs at boot: the bootloader applies the
overlays and `nerves_uevent` loads the modules the kernel asks for.

Layers build nothing for the host, so a layer can be a dependency on every
target when its Elixir code is useful there, as the DAC+ layer is here.

## Building

```sh
export MIX_TARGET=rpi4   # or rpi5
mix deps.get
mix firmware
scripts/verify-firmware.sh
```

The first build downloads the system's kernel dev kit and the kernel
sources the layer needs. `scripts/verify-firmware.sh` checks the `.fw`
without booting it: the overlay and `config.txt` line in every boot
partition task, the modules and their dependencies in the module index,
and `flac` in the release. For rpi5, pass
`_build/rpi5_dev/nerves/images/hello_layer.fw`.

`config/target.exs` expects an SSH public key in `~/.ssh`, as generated
Nerves projects do.

## On a device

With a DAC+ on the header:

```elixir
iex> HelloLayer.status()
iex> HelloLayer.play_test_tone()
```

`status/0` reports whether the sound card registered, which of the layer's
modules are loaded and where `flac` is.

An LED on GPIO 17 blinks with the heartbeat trigger, and
`/sys/class/leds/hello-layer` exists.
