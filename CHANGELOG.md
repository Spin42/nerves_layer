# Changelog

## v0.1.0

First release.

* Layers list `NervesLayer.Layer` modules in their `:nerves_layer` project
  option. Built in: `NervesLayer.Kernel` (modules from kernel config
  fragments or out-of-tree sources), `NervesLayer.DeviceTree` (overlays on
  the boot partition, compiled from source or prebuilt) and
  `NervesLayer.RaspberryPi` (`config.txt` lines). Layers can write their own
  with the same helpers.
* `:nerves_layer` compiler building each layer for the system's kernel, and
  `mix nerves_layer.install` installing all layers into the firmware
* Kernel dev kits: found in the system, generated from a local system
  build, or downloaded from this repository's `devkits` release, and
  verified against the system's kernel
* `devkits` workflow building and verifying dev kits for the systems in
  `devkits.txt`
