defmodule NervesLayer do
  @moduledoc """
  Layers add kernel modules, device-tree overlays and boot configuration to a
  stock Nerves system without rebuilding it.

  A layer is an ordinary Mix dependency whose `mix.exs` adds the
  `:nerves_layer` compiler and lists what the layer contributes, as
  `NervesLayer.Layer` modules and their options:

      def project do
        [
          app: :hello_led,
          compilers: Mix.compilers() ++ [:nerves_layer],
          nerves_layer: [
            {NervesLayer.DeviceTree, overlays: ["hello-led"]},
            {NervesLayer.RaspberryPi, dtoverlays: ["hello-led"]}
          ],
          ...
        ]
      end

  The built-in layer modules are `NervesLayer.Kernel`,
  `NervesLayer.DeviceTree` and `NervesLayer.RaspberryPi`. A layer can also
  list its own modules, written with the same helpers:

      defmodule MyLayer.Layer do
        @behaviour NervesLayer.Layer

        @impl NervesLayer.Layer
        def layer(layer, _opts) do
          layer
          |> NervesLayer.Kernel.add_fragment("linux.fragment")
          |> NervesLayer.RaspberryPi.enable_overlay("my-overlay")
        end
      end

  Everything happens while the firmware is built, by the scripts in
  `priv/scripts`:

    * `mix compile` builds each layer's kernel modules and overlays
      (`Mix.Tasks.Compile.NervesLayer`)
    * `mix nerves_layer.install`, run before `mix firmware`, installs them
      into the firmware (`Mix.Tasks.NervesLayer.Install`)

  Paths are relative to the layer's root.
  """

  @typedoc """
  What a layer contributes. Layer modules build it with the helpers of
  `NervesLayer.Kernel`, `NervesLayer.DeviceTree` and
  `NervesLayer.RaspberryPi` rather than by changing its fields.

    * `:app`, `:root` - the layer's application and directory
    * `:target` - the `MIX_TARGET` the firmware is built for
  """
  @type t :: %__MODULE__{
          app: atom(),
          root: Path.t(),
          target: atom(),
          kernel_fragments: [Path.t()],
          kernel_modules_srcs: [Path.t()],
          dt_overlays: [String.t()],
          config_txt: [String.t()]
        }

  defstruct app: nil,
            root: nil,
            target: nil,
            kernel_fragments: [],
            kernel_modules_srcs: [],
            dt_overlays: [],
            config_txt: []

  @doc """
  Returns the layers among the current project's dependencies.
  """
  @spec layers() :: [t()]
  def layers() do
    for {app, path} <- Enum.sort(Mix.Project.deps_paths()),
        entries =
          Mix.Project.in_project(app, path, fn _ -> Mix.Project.config()[:nerves_layer] end),
        entries != nil,
        do: new(app, path, entries)
  end

  @doc """
  Runs a layer's `:nerves_layer` entries, `{module, opts}` or `module`, in
  order.
  """
  @spec new(atom(), Path.t(), [module() | {module(), keyword()}]) :: t()
  def new(app, root, entries) do
    layer = %__MODULE__{app: app, root: root, target: Mix.target()}
    Enum.reduce(List.wrap(entries), layer, &run_entry/2)
  end

  defp run_entry({module, opts}, layer) when is_atom(module) and is_list(opts) do
    if not (Code.ensure_loaded?(module) and function_exported?(module, :layer, 2)) do
      Mix.raise("#{layer.app}: #{inspect(module)} doesn't implement NervesLayer.Layer")
    end

    case module.layer(layer, opts) do
      %__MODULE__{} = layer ->
        layer

      other ->
        Mix.raise(
          "#{layer.app}: #{inspect(module)}.layer/2 returned #{inspect(other)}, not a %NervesLayer{}"
        )
    end
  end

  defp run_entry(module, layer) when is_atom(module), do: run_entry({module, []}, layer)

  defp run_entry(entry, layer) do
    Mix.raise(
      "#{layer.app}: invalid :nerves_layer entry #{inspect(entry)}, expected {module, opts}"
    )
  end

  @doc """
  Raises unless `opts` is a keyword list with only the given keys. For layer
  modules validating their options.
  """
  @spec validate_opts!(keyword(), [atom()], module()) :: keyword()
  def validate_opts!(opts, keys, module) do
    if not Keyword.keyword?(opts) do
      raise ArgumentError, "#{inspect(module)}: options must be a keyword list"
    end

    case Keyword.keys(opts) -- keys do
      [] ->
        opts

      unknown ->
        raise ArgumentError,
              "#{inspect(module)}: unknown options #{inspect(unknown)}, expected #{inspect(keys)}"
    end
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
