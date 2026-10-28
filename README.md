# nerves_layer

Layers for [Nerves](https://nerves-project.org): Mix dependencies that add
kernel modules, device-tree overlays and binaries to a **stock** Nerves
system, entirely at firmware build time, without rebuilding the system or
its kernel.

A sound card, a CAN controller or a sensor whose driver your system doesn't
build used to mean maintaining a custom system. With a layer, it's a
dependency:

```elixir
{:nerves_system_rpi4, "~> 2.1", runtime: false, targets: :rpi4},
{:nerves_layer_hifiberry_dacplus, path: "../nerves_layer_hifiberry_dacplus"}
```

> **Status:** nerves_layer is young. Dev kits are built for the official
> systems listed in
> [`devkits.txt`](https://github.com/spin42/nerves_layer/blob/main/devkits.txt),
> and boot partition handling is Raspberry Pi specific for now. See
> [Limits](#limits).

## Examples

* [`examples/nerves_layer_hifiberry_dacplus`](https://github.com/spin42/nerves_layer/tree/main/examples/nerves_layer_hifiberry_dacplus):
  how to write a layer. HiFiBerry DAC+ support: modules from a kernel config
  fragment, an overlay, `config.txt` lines and an NBPR package.
* [`examples/hello_layer`](https://github.com/spin42/nerves_layer/tree/main/examples/hello_layer): how to use layers in a
  firmware, on the stock `nerves_system_rpi4` and `nerves_system_rpi5`.
  Includes a second layer, kept inside the project, with an overlay compiled
  from source.

## Writing a layer

A layer is a Mix project that adds the `:nerves_layer` compiler and lists
what it contributes as layer modules and their options:

```elixir
def project do
  [
    app: :my_layer,
    version: "0.1.0",
    compilers: Mix.compilers() ++ [:nerves_layer],
    nerves_layer: [
      {NervesLayer.Kernel, fragment: "linux.fragment"},
      {NervesLayer.DeviceTree, overlays: ["my-overlay"]},
      {NervesLayer.RaspberryPi, dtoverlays: ["my-overlay"]}
    ],
    deps: [{:nerves_layer, github: "spin42/nerves_layer"}]
  ]
end
```

The built-in layer modules, and their options (paths are relative to the
layer's root):

| Module | Options | Adds |
|---|---|---|
| `NervesLayer.Kernel` | `fragment:`, `modules_src:` | Kernel modules: in-tree ones a config fragment enables (`CONFIG_..._=m`), built from the kernel's own sources, or out-of-tree ones from a directory with a `Kbuild` file |
| `NervesLayer.DeviceTree` | `overlays:` | Overlays on the boot partition, compiled from `overlays/<name>.dtso` or `.dts`, prebuilt `overlays/<name>.dtbo`, or taken from the overlays the system builds |
| `NervesLayer.RaspberryPi` | `dtoverlays:`, `config_txt:` | `config.txt` lines, such as `dtoverlay=<name>,<param>=<value>` |

A fragment can only add modules: the build rejects options the system sets,
options code compiled into the kernel depends on (`CONFIG_CAN` changes
`struct net`), and built-in code.

### Layer modules

Each entry is a module implementing the `NervesLayer.Layer` behaviour. It
receives a `%NervesLayer{}` and returns it with its additions, made with
the same helpers the built-in modules use, so a layer can write its own:

```elixir
defmodule MyLayer.Layer do
  @behaviour NervesLayer.Layer

  @impl NervesLayer.Layer
  def layer(layer, opts) do
    layer
    |> NervesLayer.Kernel.add_fragment("linux.fragment")
    |> NervesLayer.DeviceTree.add_overlay("my-overlay")
    |> NervesLayer.RaspberryPi.enable_overlay("my-overlay", speed: opts[:speed] || 100)
  end
end
```

and list it as `nerves_layer: [{MyLayer.Layer, speed: 400}]`. The
`%NervesLayer{}` also carries the firmware's `:target`, for layers that
depend on it. Layer modules only describe; nerves_layer builds and installs
what all layers describe together.

A layer can also carry Elixir code and dependencies like any library,
including [NBPR](https://github.com/jimsynz/nbpr) packages for userspace
binaries.

## Using layers in a firmware

Add the layers to the firmware's dependencies and install them before
`mix firmware` assembles the image:

```elixir
defp aliases do
  [firmware: ["nerves_layer.install", "firmware"]]
end
```

`mix compile` builds each layer for the system's kernel and
`mix nerves_layer.install`:

* puts modules in `/lib/modules/<release>/updates/<layer>/` through Nerves'
  generated rootfs overlay and regenerates the module index
* derives a `fwup.conf` that writes the layers' overlays wherever
  `config.txt` is written, with `config.txt` extended by the layers' lines.
  A project's own `:fwup_conf` is used as the base.

At boot nothing layer-specific runs: the bootloader applies the overlays,
the kernel announces the devices, and `nerves_uevent` loads the modules.

On the host, layers build nothing.

## Kernel dev kits

Out-of-tree modules are compiled against a kernel *dev kit*: the build
products of the system's kernel build (`.config`, `Module.symvers`,
generated headers and host tools, from the kernel's own
`scripts/package/install-extmod-build`, as distributions package
`linux-headers`), plus the kernel source URL and `kernel-config-refs`,
every `CONFIG_` option the system's compiled code references.

nerves_layer finds the dev kit of the active system, in order:

1. in the system, as `images/linux-devkit.tar.xz`
2. generated from the system's kernel build tree, for locally built systems
3. as an artifact pinned to the system release,
   `~/.local/share/nerves/nerves_layer/devkits/<system>-<version>.tar.xz`,
   downloaded if missing from `$NERVES_LAYER_DEVKIT_URL`, which defaults to
   this repository's
   [`devkits` release](https://github.com/spin42/nerves_layer/releases/tag/devkits)

and **verifies it against the system**: every symbol CRC recorded in the
modules the system ships must match the dev kit's `Module.symvers`. A dev
kit that doesn't match the system's kernel is rejected.

| Variable | Default |
|---|---|
| `NERVES_LAYER_DEVKIT_URL` | `https://github.com/spin42/nerves_layer/releases/download/devkits`; empty to never download |
| `NERVES_LAYER_DEVKITS_DIR` | `nerves_layer/devkits` in the Nerves data directory |

### Publishing dev kits

`priv/scripts/mkdevkit-release.sh <system> <version> <work dir> <out dir>`
clones the system at its release tag and the `nerves_system_br` version it
pins, builds only the kernel (`make linux`, about 20 minutes on 20 cores,
most of it Buildroot host tools), packages the dev kit, and keeps it only if
it passes verification against the published release. The kernel patches
Buildroot applied travel in the dev kit and are applied to the fetched
sources.

The [`devkits` workflow](https://github.com/spin42/nerves_layer/blob/main/.github/workflows/devkits.yml) runs it for every
entry of [`devkits.txt`](https://github.com/spin42/nerves_layer/blob/main/devkits.txt) not yet attached to the `devkits`
release. To support a new system release, add a line there.

## How it works

Everything happens in the shell scripts in [`priv/scripts`](https://github.com/spin42/nerves_layer/tree/main/priv/scripts);
three Elixir files connect them to Mix.

**`mix compile`** builds each layer:

* **In-tree modules from a kernel config fragment** (`build-fragment.sh`).
  The kernel source is checked out sparsely from git at the dev kit's ref
  (Kconfig files, makefiles, `scripts/`: about 18 MB, cached). The kernel's
  own Kconfig resolves the fragment, with and without it. `check-config.sh`
  rejects any change that isn't purely adding modules: an option the system
  sets, one in `kernel-config-refs` (`CONFIG_CAN` changes `struct net`), or
  built-in code. `make` evaluates the kernel's makefiles (`kbuild-eval.mk`)
  with and without the changes; the new modules and their objects are the
  difference. Only their sources and relatively included headers are
  fetched, and each directory gets a two-line `Kbuild` that includes the
  kernel's makefile and keeps only the new modules.
* **Out-of-tree modules**: sources and a `Kbuild` shipped by the layer
  (`build-modules.sh`).
* **Overlay sources** (`overlays/<name>.dtso`): the C preprocessor with the
  kernel's headers, then the kernel's own `dtc -@` (`build-overlays.sh`).

Nothing is rebuilt until the layer's inputs or the dev kit change.

**`mix nerves_layer.install`** runs `install-modules.sh`, which regenerates
the module index with `depmod -e` against `Module.symvers`, and
`boot-files.sh`, which derives the `fwup.conf`.

## Requirements

Besides what Nerves itself needs, the build host needs bash, GNU coreutils,
grep, sed and awk, `git`, `curl`, `make`, `xz`, `patch` and `depmod`
(kmod).

## Limits

* Boot partition handling is Raspberry Pi specific (`config.txt` and
  `dtoverlay`).
* A layer can only add modules whose kernel foundations the system already
  has.
* Selective kernel source fetching needs a GitHub archive, kernel.org or
  cgit source URL.
* The dev kit's host tools are built for x86_64 Linux, the system build
  machine, so layers with kernel modules build on x86_64 Linux hosts only.

## License

Apache-2.0, see [LICENSE](https://github.com/spin42/nerves_layer/blob/main/LICENSE).
