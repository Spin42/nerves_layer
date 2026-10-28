defmodule NervesLayer.Kernel do
  @moduledoc """
  Kernel modules, built against the system's kernel dev kit and installed in
  `/lib/modules/<release>/updates/<layer>/`, where `nerves_uevent` loads them
  when the kernel announces matching devices.

  As a layer entry:

      {NervesLayer.Kernel, fragment: "linux.fragment"}

  ## Options

    * `:fragment` - a kernel config fragment, or a list of them, enabling
      in-tree modules (`CONFIG_..._=m`). See `add_fragment/2`.
    * `:modules_src` - a directory, or a list of them, with out-of-tree
      module sources. See `add_modules_src/2`.
  """

  @behaviour NervesLayer.Layer

  @impl NervesLayer.Layer
  def layer(layer, opts) do
    opts = NervesLayer.validate_opts!(opts, [:fragment, :modules_src], __MODULE__)
    layer = Enum.reduce(List.wrap(opts[:fragment]), layer, &add_fragment(&2, &1))
    Enum.reduce(List.wrap(opts[:modules_src]), layer, &add_modules_src(&2, &1))
  end

  @doc """
  Builds the in-tree modules a kernel config fragment enables, from the
  kernel's own sources.

  Only options the kernel's Kconfig needs to be told about are needed; what
  they select follows. The build rejects a fragment that would change the
  system's kernel rather than add modules to it: an option the system sets,
  one code compiled into the kernel depends on, or built-in code. A layer's
  fragments are combined.
  """
  @spec add_fragment(NervesLayer.t(), Path.t()) :: NervesLayer.t()
  def add_fragment(%NervesLayer{} = layer, path) do
    %{layer | kernel_fragments: layer.kernel_fragments ++ [path]}
  end

  @doc """
  Builds out-of-tree modules from a directory with their sources and a
  `Kbuild` file.
  """
  @spec add_modules_src(NervesLayer.t(), Path.t()) :: NervesLayer.t()
  def add_modules_src(%NervesLayer{} = layer, dir) do
    %{layer | kernel_modules_srcs: layer.kernel_modules_srcs ++ [dir]}
  end
end
