defmodule NervesLayer.HifiberryDacplus do
  @moduledoc """
  HiFiBerry DAC+ / DAC+ Pro support for stock Raspberry Pi Nerves systems.

  Adding this dependency is all the firmware needs. At firmware build time
  it contributes:

    * the PCM512x codec, TPA6130A2 amplifier, DAC Pro clock and machine
      driver modules, built against the system's kernel dev kit
    * the `hifiberry-dacplus` device-tree overlay on the boot partition,
      enabled in `config.txt`
    * FLAC tools, through `:nbpr_flac`

  Nothing loads at runtime: the firmware applies the overlay at boot, the
  kernel announces the codec and sound card, and `nerves_uevent` loads the
  matching modules.
  """

  @card "sndrpihifiberry"

  @doc """
  The ALSA card id the DAC+ registers.
  """
  @spec card() :: String.t()
  def card(), do: @card

  @doc """
  Returns whether the DAC+ sound card is present.
  """
  @spec present?() :: boolean()
  def present?(), do: File.dir?("/proc/asound/#{@card}")

  @doc """
  Plays a FLAC file on the DAC+, decoding with `flac` and playing with `aplay`.
  """
  @spec play_flac(Path.t()) :: :ok | {:error, String.t()}
  def play_flac(path) do
    pipeline =
      "flac --decode --stdout --silent #{shell_quote(path)} | aplay -q -D plughw:CARD=#{@card}"

    case System.cmd("sh", ["-c", "set -o pipefail; " <> pipeline], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, _} -> {:error, String.trim(output)}
    end
  end

  defp shell_quote(string), do: "'" <> String.replace(string, "'", ~S('\'')) <> "'"
end
