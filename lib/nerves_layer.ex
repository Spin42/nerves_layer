defmodule NervesLayer do
  @moduledoc """
  Layers add kernel modules, device-tree overlays and binaries to a stock
  Nerves system without rebuilding it.

  A layer is an ordinary Mix dependency whose `mix.exs` carries a
  `:nerves_layer` keyword list:

      def project do
        [
          app: :nerves_layer_hifiberry_dacplus,
          compilers: Mix.compilers() ++ [:nerves_layer],
          nerves_layer: [
            kernel_fragment: "linux.fragment",
            dt_overlays: ["hifiberry-dacplus"],
            config_txt: ["dtoverlay=hifiberry-dacplus"]
          ],
          ...
        ]
      end

  Everything happens while the firmware is built, by the scripts in
  `priv/scripts`; this module and the two Mix tasks only connect them to Mix:

    * `mix compile` builds each layer's kernel modules and overlays
      (`Mix.Tasks.Compile.NervesLayer`)
    * `mix nerves_layer.install`, run before `mix firmware`, installs them
      into the firmware (`Mix.Tasks.NervesLayer.Install`)

  ## Options

    * `:kernel_fragment` - a kernel config fragment file enabling in-tree
      modules (`CONFIG_..._=m`), built from the kernel's own sources. Only
      options that add modules are accepted.
    * `:kernel_modules_src` - a directory with out-of-tree module sources and
      a `Kbuild` file building them.
    * `:dt_overlays` - overlay names to put on the boot partition. Each is
      looked up in the layer's `overlays/` directory as a source
      (`<name>.dtso` or `<name>.dts`, compiled at build time), then as a
      prebuilt `<name>.dtbo`, then in the system's
      `images/rpi-firmware/overlays/`.
    * `:config_txt` - lines appended to the Raspberry Pi `config.txt`.

  Paths are relative to the layer's root.
  """

  @type layer :: %{app: atom(), path: Path.t(), config: keyword()}

  @doc """
  Returns the layers among the current project's dependencies.
  """
  @spec layers() :: [layer()]
  def layers() do
    for {app, path} <- Enum.sort(Mix.Project.deps_paths()),
        config =
          Mix.Project.in_project(app, path, fn _ -> Mix.Project.config()[:nerves_layer] end),
        config != nil,
        do: %{app: app, path: path, config: config}
  end

  @doc """
  The build directory of a layer: `modules/` and `overlays/` hold what it
  built for the current target.
  """
  @spec build_dir(atom()) :: Path.t()
  def build_dir(app) do
    Path.join([Mix.Project.build_path(), "nerves_layer", Atom.to_string(app)])
  end

  @doc """
  Extracts, verifies and returns the active system's kernel dev kit.
  """
  @spec devkit!() :: Path.t()
  def devkit!() do
    script!("devkit.sh", [nerves_system!(), Path.join(Mix.Project.build_path(), "nerves_layer")])
  end

  @doc """
  Runs one of the scripts in `priv/scripts` and returns its trimmed stdout.
  Its stderr goes to the console.
  """
  @spec script!(String.t(), [String.t()]) :: String.t()
  def script!(name, args) do
    script = Path.join([Application.app_dir(:nerves_layer, "priv"), "scripts", name])

    case System.cmd(script, args, env: env()) do
      {output, 0} -> String.trim(output)
      {_output, status} -> Mix.raise("nerves_layer: #{name} failed (exit #{status})")
    end
  end

  defp env() do
    data_dir =
      System.get_env("NERVES_DATA_DIR") ||
        Path.join(System.get_env("XDG_DATA_HOME") || Path.expand("~/.local/share"), "nerves")

    cross_compile =
      System.get_env("CROSSCOMPILE") ||
        Mix.raise("CROSSCOMPILE is not set; is the Nerves environment loaded?")

    [
      {"CROSS_COMPILE", cross_compile <> "-"},
      {"NERVES_LAYER_SOURCE_CACHE", Path.join([data_dir, "nerves_layer", "linux"])}
    ]
  end

  defp nerves_system!() do
    System.get_env("NERVES_SYSTEM") ||
      Mix.raise("NERVES_SYSTEM is not set; nerves_layer only works with a real MIX_TARGET")
  end
end
