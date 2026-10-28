defmodule Mix.Tasks.Compile.NervesLayer do
  @shortdoc "Builds a layer's kernel modules and overlays"

  @moduledoc """
  Builds the kernel modules and device-tree overlays of the current project,
  a layer, for the active Nerves system. Add it to the layer's compilers:

      compilers: Mix.compilers() ++ [:nerves_layer]

  Nothing is built for the host target, and nothing is rebuilt until the
  layer's inputs or the system's dev kit change.
  """

  use Mix.Task.Compiler

  @impl Mix.Task.Compiler
  def run(_args) do
    config = Mix.Project.config()
    layer = config[:nerves_layer] || []
    root = File.cwd!()
    overlays = overlay_sources(root, layer)

    if Mix.target() == :host or
         (layer[:kernel_fragment] == nil and layer[:kernel_modules_src] == nil and overlays == []) do
      {:noop, []}
    else
      build(config[:app], root, layer, overlays)
    end
  end

  defp build(app, root, layer, overlays) do
    devkit = NervesLayer.devkit!()
    out = NervesLayer.build_dir(app)
    stamp_path = Path.join(out, "build.stamp")
    stamp = stamp(root, layer, overlays, devkit)

    if File.read(stamp_path) == {:ok, stamp} do
      {:noop, []}
    else
      Mix.shell().info("==> #{app}: building for the system's kernel")
      modules = Path.join(out, "modules")
      File.rm_rf!(modules)
      File.rm_rf!(Path.join(out, "overlays"))

      if fragment = layer[:kernel_fragment] do
        NervesLayer.script!("build-fragment.sh", [
          devkit,
          Path.join(root, fragment),
          Path.join(out, "fragment"),
          modules
        ])
      end

      if src = layer[:kernel_modules_src] do
        kbuild = Path.join(out, "vendored")
        File.rm_rf!(kbuild)
        File.cp_r!(Path.join(root, src), kbuild)
        NervesLayer.script!("build-modules.sh", [devkit, kbuild, modules])
      end

      if overlays != [] do
        NervesLayer.script!("build-overlays.sh", [devkit, Path.join(out, "overlays") | overlays])
      end

      File.write!(stamp_path, stamp)
      {:ok, []}
    end
  end

  defp overlay_sources(root, layer) do
    for name <- layer[:dt_overlays] || [],
        source <- Path.wildcard(Path.join(root, "overlays/#{name}.{dtso,dts}")) |> Enum.take(1),
        do: source
  end

  # The dev kit pins the kernel, its sources and the toolchain, so the
  # layer's own files and the dev kit are all a build depends on.
  defp stamp(root, layer, overlays, devkit) do
    files =
      [layer[:kernel_fragment], layer[:kernel_modules_src]]
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(&[Path.join(root, &1) | Path.wildcard(Path.join([root, &1, "**"]))])
      |> Enum.concat(overlays)
      |> Enum.filter(&File.regular?/1)
      |> Enum.sort()

    :crypto.hash(
      :sha256,
      :erlang.term_to_binary({devkit, Enum.map(files, &{&1, File.read!(&1)})})
    )
    |> Base.encode16(case: :lower)
  end
end
