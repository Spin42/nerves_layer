defmodule HelloLayer do
  @moduledoc """
  Test firmware for `nerves_layer`.

  The firmware itself has no layer-specific code at boot: the DAC+ kernel
  modules, overlay and `config.txt` line are all added while the firmware is
  built. These helpers only check the result on a device.
  """

  alias NervesLayer.HifiberryDacplus

  @doc """
  Reports what the DAC+ layer put in place.
  """
  @spec status() :: map()
  def status() do
    %{
      card_present?: HifiberryDacplus.present?(),
      modules_loaded:
        Enum.filter(
          ~w(snd_soc_pcm512x snd_soc_pcm512x_i2c snd_soc_hifiberry_dacplus clk_hifiberry_dacpro),
          &File.dir?("/sys/module/#{&1}")
        ),
      flac: System.find_executable("flac")
    }
  end

  @doc """
  Plays a 2-second 440 Hz test tone on the DAC+.
  """
  @spec play_test_tone() :: :ok | {:error, String.t()}
  def play_test_tone() do
    :hello_layer
    |> :code.priv_dir()
    |> Path.join("tone.flac")
    |> HifiberryDacplus.play_flac()
  end
end
