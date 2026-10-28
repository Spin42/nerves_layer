# Evaluates a kernel directory's makefile the way Kbuild would, and prints
# the modules it builds with their objects:
#
#   <module>.o <object>...
#
# Usage: make -s -f kbuild-eval.mk DEVKIT=<dev kit> SRC=<kernel tree> DIR=<dir> [CONFIG_<NAME>=<value>...]
#
# Options come from the dev kit's auto.conf; ones given on the command line
# override them.

include $(DEVKIT)/include/config/auto.conf

srctree := $(SRC)
src := $(SRC)/$(DIR)
obj := $(DIR)

include $(firstword $(wildcard $(src)/Kbuild $(src)/Makefile))

modules := $(filter %.o,$(obj-m))
parts = $(strip $($(1:.o=-objs)) $($(1:.o=-y)) $($(1:.o=-m)))

$(foreach m,$(modules),$(info $(m) $(or $(call parts,$(m)),$(m))))

.PHONY: kbuild-eval
kbuild-eval: ;
