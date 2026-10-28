defmodule NervesLayer.RaspberryPi do
  @moduledoc """
  Raspberry Pi boot configuration: lines added to `config.txt`, in every
  boot partition the system's `fwup.conf` writes it to.

  As a layer entry:

      {NervesLayer.RaspberryPi, dtoverlays: ["hifiberry-dacplus"]}

  ## Options

    * `:dtoverlays` - overlays to enable, as names or `{name, params}`. See
      `enable_overlay/3`.
    * `:config_txt` - other lines. See `add_config_txt/2`.
  """

  @behaviour NervesLayer.Layer

  @impl NervesLayer.Layer
  def layer(layer, opts) do
    opts = NervesLayer.validate_opts!(opts, [:dtoverlays, :config_txt], __MODULE__)

    layer =
      Enum.reduce(opts[:dtoverlays] || [], layer, fn
        {name, params}, layer -> enable_overlay(layer, name, params)
        name, layer -> enable_overlay(layer, name)
      end)

    Enum.reduce(opts[:config_txt] || [], layer, &add_config_txt(&2, &1))
  end

  @doc """
  Enables an overlay with optional parameters. The overlay must be on the
  boot partition: one the system's `fwup.conf` writes, or one added with
  `NervesLayer.DeviceTree.add_overlay/2`.

      enable_overlay(layer, "pwm", pin: 18, func: 2)
      # dtoverlay=pwm,pin=18,func=2
  """
  @spec enable_overlay(NervesLayer.t(), String.t(), keyword() | [{String.t(), term()}]) ::
          NervesLayer.t()
  def enable_overlay(%NervesLayer{} = layer, name, params \\ []) do
    add_config_txt(layer, Enum.join(["dtoverlay=" <> name | Enum.map(params, &param/1)], ","))
  end

  defp param({key, value}), do: "#{key}=#{value}"

  @doc """
  Adds a line to `config.txt`, after the system's own lines.
  """
  @spec add_config_txt(NervesLayer.t(), String.t()) :: NervesLayer.t()
  def add_config_txt(%NervesLayer{} = layer, line) do
    %{layer | config_txt: layer.config_txt ++ [line]}
  end
end
