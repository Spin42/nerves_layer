defmodule Mix.Tasks.NervesLayer.Install do
  @shortdoc "Install layers into the firmware being built"

  @moduledoc """
  Installs every layer among the project's dependencies into the firmware
  that the next `mix firmware` builds:

      aliases: [firmware: ["nerves_layer.install", "firmware"]]

    * kernel modules, with a regenerated module index, go into Nerves'
      generated rootfs overlay (`_build/<target>_<env>/nerves/rootfs_overlay`)
    * overlays and `config.txt` lines go into a derived `fwup.conf`, which
      becomes the `:fwup_conf` of `config :nerves, :firmware` for the rest of
      this Mix invocation. A project's own `:fwup_conf` is used as the base.
  """

  use Mix.Task

  @requirements ["compile"]

  @impl Mix.Task
  def run(_args) do
    if Mix.target() == :host do
      Mix.raise("mix nerves_layer.install must run with a real MIX_TARGET")
    end

    case NervesLayer.layers() do
      [] ->
        Mix.shell().info("[nerves_layer] no layers in deps; nothing to install.")

      layers ->
        install_modules(layers)
        install_boot_files(layers)
    end
  end

  defp install_modules(layers) do
    modules =
      for %{app: app} <- layers,
          dir = Path.join(NervesLayer.build_dir(app), "modules"),
          Path.wildcard(Path.join(dir, "*.ko")) != [],
          do: "#{app}=#{dir}"

    if modules != [] do
      overlay = Path.join([Mix.Project.build_path(), "nerves", "rootfs_overlay"])
      args = [System.fetch_env!("NERVES_SYSTEM"), NervesLayer.devkit!(), overlay | modules]
      NervesLayer.script!("install-modules.sh", args)
    end
  end

  defp install_boot_files(layers) do
    overlays =
      for layer <- layers,
          name <- layer.dt_overlays,
          do: ["--overlay", "#{name}=#{find_overlay!(layer, name)}"]

    lines = for layer <- layers, line <- layer.config_txt, do: ["--line", line]

    if overlays != [] or lines != [] do
      firmware = Application.get_env(:nerves, :firmware, [])
      system_fwup = Path.join([System.fetch_env!("NERVES_SYSTEM"), "images", "fwup.conf"])
      out = Path.join([Mix.Project.build_path(), "nerves_layer", "boot"])
      args = [firmware[:fwup_conf] || system_fwup, out | List.flatten(lines ++ overlays)]

      fwup_conf = NervesLayer.script!("boot-files.sh", args)
      Application.put_env(:nerves, :firmware, Keyword.put(firmware, :fwup_conf, fwup_conf))

      for [_, arg] <- overlays ++ lines, do: Mix.shell().info("[nerves_layer] boot: #{arg}")
    end
  end

  defp find_overlay!(layer, name) do
    candidates = [
      Path.join([NervesLayer.build_dir(layer.app), "overlays", name <> ".dtbo"]),
      Path.join([layer.root, "overlays", name <> ".dtbo"]),
      Path.join([System.fetch_env!("NERVES_SYSTEM"), "images/rpi-firmware/overlays/#{name}.dtbo"])
    ]

    Enum.find(candidates, &File.regular?/1) ||
      Mix.raise(
        "#{layer.app}: overlay #{name} not found in:\n  " <> Enum.join(candidates, "\n  ")
      )
  end
end
