# Changelog

## v0.1.0

First release.

* `:nerves_layer` compiler building a layer's kernel modules, from a kernel
  config fragment or out-of-tree sources, and its device-tree overlays
* `mix nerves_layer.install` installing modules, overlays and `config.txt`
  lines into the firmware
* Kernel dev kits: found in the system, generated from a local system
  build, or downloaded from this repository's `devkits` release, and
  verified against the system's kernel
* `devkits` workflow building and verifying dev kits for the systems in
  `devkits.txt`
