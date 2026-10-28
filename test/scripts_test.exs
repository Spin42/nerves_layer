defmodule NervesLayer.ScriptsTest do
  use ExUnit.Case, async: true

  @scripts Path.expand("../priv/scripts", __DIR__)
  @fwup_conf Path.expand("fixtures/rpi4-fwup.conf", __DIR__)

  @moduletag :tmp_dir

  defp run(script, args, env \\ []) do
    System.cmd(Path.join(@scripts, script), args, env: env, stderr_to_stdout: true)
  end

  describe "boot-files.sh" do
    setup %{tmp_dir: tmp} do
      system = Path.join(tmp, "system")
      File.mkdir_p!(Path.join(system, "images"))
      File.write!(Path.join([system, "images", "config.txt"]), "arm_64bit=1\n")
      File.write!(Path.join(tmp, "x.dtbo"), "dtbo")
      %{system: system, out: Path.join(tmp, "out"), dtbo: Path.join(tmp, "x.dtbo")}
    end

    test "writes each overlay wherever config.txt is written", ctx do
      assert {_, 0} =
               run("boot-files.sh", [@fwup_conf, ctx.out, "--overlay", "x=#{ctx.dtbo}"], [
                 {"NERVES_SYSTEM", ctx.system}
               ])

      conf = File.read!(Path.join(ctx.out, "fwup.conf"))

      config_txt_partitions =
        Regex.scan(~r/fat_write\(\$\{(\w+)\}, "config\.txt"\)/, conf, capture: :all_but_first)

      overlay_partitions =
        Regex.scan(~r/fat_write\(\$\{(\w+)\}, "overlays\/x\.dtbo"\)/, conf,
          capture: :all_but_first
        )

      assert length(config_txt_partitions) == 5
      assert overlay_partitions == config_txt_partitions
      assert conf =~ ~s(file-resource config.txt { host-path = "#{ctx.out}/config.txt" })

      assert conf =~
               ~s(file-resource overlays/x.dtbo { host-path = "#{ctx.out}/overlays/x.dtbo" })

      assert File.read!(Path.join([ctx.out, "overlays", "x.dtbo"])) == "dtbo"
    end

    test "appends the layers' lines to the original config.txt", ctx do
      assert {_, 0} =
               run("boot-files.sh", [@fwup_conf, ctx.out, "--line", "dtoverlay=x"], [
                 {"NERVES_SYSTEM", ctx.system}
               ])

      assert File.read!(Path.join(ctx.out, "config.txt")) ==
               "arm_64bit=1\n\n# Added by nerves_layer\ndtoverlay=x\n"
    end

    test "leaves overlays the system already ships alone", ctx do
      args = [@fwup_conf, ctx.out, "--overlay", "pwm=#{ctx.dtbo}"]
      assert {_, 0} = run("boot-files.sh", args, [{"NERVES_SYSTEM", ctx.system}])

      count = &(&1 |> File.read!() |> String.split("overlays/pwm.dtbo") |> length())
      assert count.(Path.join(ctx.out, "fwup.conf")) == count.(@fwup_conf)
    end
  end

  describe "check-config.sh" do
    setup %{tmp_dir: tmp} do
      tree = Path.join(tmp, "tree")
      File.mkdir_p!(Path.join(tree, "drivers/serdev"))

      File.write!(
        Path.join(tree, "drivers/serdev/Makefile"),
        "obj-$(CONFIG_SERIAL_DEV_BUS) += core.o\n"
      )

      write = fn name, text ->
        path = Path.join(tmp, name)
        File.write!(path, text)
        path
      end

      system = write.("system", "CONFIG_SND=m\n# CONFIG_CAN is not set\n")
      base = write.("base", "CONFIG_SND=m\n")
      refs = write.("refs", "CAN\nSND\n")

      check = fn resolved ->
        run("check-config.sh", [system, base, write.("resolved", resolved), refs, tree])
      end

      %{check: check}
    end

    test "prints the modules and module-internal options a fragment adds", %{check: check} do
      assert {"CONFIG_CAN_NETLINK=y\nCONFIG_SND_SOC_PCM512x=m\n", 0} =
               check.("CONFIG_SND=m\nCONFIG_SND_SOC_PCM512x=m\nCONFIG_CAN_NETLINK=y\n")
    end

    test "rejects options compiled system code references", %{check: check} do
      assert {output, 1} = check.("CONFIG_SND=m\nCONFIG_CAN=m\n")
      assert output =~ "CONFIG_CAN: code compiled into the system references it"
    end

    test "rejects built-in code", %{check: check} do
      assert {output, 1} = check.("CONFIG_SND=m\nCONFIG_SERIAL_DEV_BUS=y\n")
      assert output =~ "CONFIG_SERIAL_DEV_BUS=y would build code into the kernel image"
    end

    test "rejects changes to options the system sets", %{check: check} do
      assert {output, 1} = check.("CONFIG_SND=y\n")
      assert output =~ "CONFIG_SND: the system sets it to m"
    end
  end
end
