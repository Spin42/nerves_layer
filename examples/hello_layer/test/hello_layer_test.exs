defmodule HelloLayerTest do
  use ExUnit.Case

  test "status/0 reports no DAC+ on the host" do
    assert %{card_present?: false, modules_loaded: []} = HelloLayer.status()
  end
end
