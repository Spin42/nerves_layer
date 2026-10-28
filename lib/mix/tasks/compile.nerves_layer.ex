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

    if Mix.target() == :host or config[:nerves_layer] == nil do
      {:noop, []}
    else
      layer = NervesLayer.new(config[:app], File.cwd!(), config[:nerves_layer])
      overlays = overlay_sources(layer)

      if layer.kernel_fragments == [] and layer.kernel_modules_srcs == [] and overlays == [] do
        {:noop, []}
      else
        build(layer, overlays)
      end
    end
  end

  defp build(layer, overlays) do
    devkit = NervesLayer.devkit!()
    out = NervesLayer.build_dir(layer.app)
    stamp_path = Path.join(out, "build.stamp")
    stamp = stamp(layer, overlays, devkit)

    if File.read(stamp_path) == {:ok, stamp} do
      {:noop, []}
    else
      Mix.shell().info("==> #{layer.app}: building for the system's kernel")
      modules = Path.join(out, "modules")
      File.rm_rf!(modules)
      File.rm_rf!(Path.join(out, "overlays"))

      if layer.kernel_fragments != [] do
        fragment = Path.join(out, "linux.fragment")
        File.mkdir_p!(out)

        File.write!(
          fragment,
          Enum.map_join(layer.kernel_fragments, "\n", &File.read!(Path.join(layer.root, &1)))
        )

        NervesLayer.script!("build-fragment.sh", [
          devkit,
          fragment,
          Path.join(out, "fragment"),
          modules
        ])
      end

      vendored = Path.join(out, "vendored")
      File.rm_rf!(vendored)

      for {src, index} <- Enum.with_index(layer.kernel_modules_srcs) do
        kbuild = Path.join(vendored, Integer.to_string(index))
        File.cp_r!(Path.join(layer.root, src), kbuild)
        NervesLayer.script!("build-modules.sh", [devkit, kbuild, modules])
      end

      if overlays != [] do
        NervesLayer.script!("build-overlays.sh", [devkit, Path.join(out, "overlays") | overlays])
      end

      File.write!(stamp_path, stamp)
      {:ok, []}
    end
  end

  defp overlay_sources(layer) do
    for name <- layer.dt_overlays,
        source <-
          Path.wildcard(Path.join(layer.root, "overlays/#{name}.{dtso,dts}")) |> Enum.take(1),
        do: source
  end

  # The dev kit pins the kernel, its sources and the toolchain, so the
  # layer's own files and the dev kit are all a build depends on.
  defp stamp(layer, overlays, devkit) do
    files =
      (layer.kernel_fragments ++ layer.kernel_modules_srcs)
      |> Enum.map(&Path.join(layer.root, &1))
      |> Enum.flat_map(&[&1 | Path.wildcard(Path.join(&1, "**"))])
      |> Enum.concat(overlays)
      |> Enum.filter(&File.regular?/1)
      |> Enum.sort()

    inputs = {devkit, layer.kernel_fragments, Enum.map(files, &{&1, File.read!(&1)})}

    :crypto.hash(:sha256, :erlang.term_to_binary(inputs))
    |> Base.encode16(case: :lower)
  end
end
