SHELL := /bin/bash
BOARDNAME := futurehome-cube-2v0-eu

# Overridable defaults
ARMBIAN_GITSTATE ?= main
ARMBIAN_KERNEL ?= current
ARMBIAN_RELEASE ?= noble
ARMBIAN_MINIMAL ?= no
UBOOT_TAG ?= v2026.01
BOARD_CONFIG_FILE ?= ./boardconfig-futurehome-cube-2v0-eu.conf

# Board support resources
BOARD_SUPPORT ?= $(shell pwd)/futurehome-cube2v0-board-support
BOARD_SUPPORT_GITSTATE ?= c062a5de84c3bbe8ff47968845f8947442078a32
UBOOT_DTSI ?= $(BOARD_SUPPORT)/rk3328-futurehome-cube-2v0-eu-u-boot.dtsi
UBOOT_DEFCONFIG ?= $(BOARD_SUPPORT)/futurehome-cube-2v0-eu_defconfig
UBOOT_BOOTMODE_SCRIPT ?= $(BOARD_SUPPORT)/futurehome-cube-2v0-eu-bootmode-script.cmd
DEVICE_TREE ?= $(BOARD_SUPPORT)/rk3328-futurehome-cube-2v0-eu.dts
DEVICE_TREE_OVERLAYS := $(wildcard $(BOARD_SUPPORT)/device-tree-overlays/*.dtso)

ARMBIAN := $(shell pwd)/armbian-build

.NOTPARALLEL:

.DEFAULT_GOAL: main

v25.11: UBOOT_TAG = v2025.10
v25.11: ARMBIAN_GITSTATE = v25.11
v25.11: prepare build

v26.02: UBOOT_TAG = v2026.01
v26.02: ARMBIAN_GITSTATE = v26.02
v26.02: prepare build

main: prepare build

prepare:
	@ if [[ ! -d $(BOARD_SUPPORT) ]]; then \
		echo "# Downloading board support resources..." \
		&& git clone https://github.com/RockPaperPencil/futurehome-cube2v0eu-boardsupport.git $(BOARD_SUPPORT) ; \
	else \
		git -C $(BOARD_SUPPORT) reset --hard > /dev/null ; \
		git -C $(BOARD_SUPPORT) pull origin main ; \
	fi
	@ git -C $(BOARD_SUPPORT) checkout $(BOARD_SUPPORT_GITSTATE)

	@ if [[ ! -d $(ARMBIAN) ]]; then \
		echo "# Downloading Armbian build framework..." && git clone https://github.com/armbian/build.git $(ARMBIAN) ; \
	else \
		git -C $(ARMBIAN) remote update --prune ; \
		git -C $(ARMBIAN) clean -fxd patch config userpatches ; \
		git -C $(ARMBIAN) reset --hard > /dev/null ; \
		git -C $(ARMBIAN) checkout $(ARMBIAN_GITSTATE) ; \
		git -C $(ARMBIAN) pull origin ; \
	fi
	@ echo "Preparing to build Armbian from Git state '$(ARMBIAN_GITSTATE)'"

	# Add board config file to Armbian build system
	@ install -D ./boardconfig-futurehome-cube-2v0-eu.wip $(ARMBIAN)/config/boards/$(BOARDNAME).wip
	@ sed -i 's/BOOTBRANCH_BOARD.*$$/BOOTBRANCH_BOARD="tag:$(UBOOT_TAG)"/g' $(ARMBIAN)/config/boards/$(BOARDNAME).wip
	@ sed -i 's/BOOTPATCHDIR.*$$/BOOTPATCHDIR="$(UBOOT_TAG)"/g' $(ARMBIAN)/config/boards/$(BOARDNAME).wip

	# Add to kernel patch directories
	@ for KERNEL_VERSION in $(shell grep KERNEL_MAJOR_MINOR $(ARMBIAN)/config/sources/families/include/rockchip64_common.inc|cut -d \" -f 2 | tr '\n' ' '); do \
		TARGETDIR="$(ARMBIAN)/patch/kernel/archive/rockchip64-$${KERNEL_VERSION}" ;\
		install -m 0644 -D $(DEVICE_TREE) $$TARGETDIR/dt/rk3328-$(BOARDNAME).dts ;\
		install -m 0644 -D -t $$TARGETDIR/overlay/ $(DEVICE_TREE_OVERLAYS) ;\
		for OVERLAY_FILE in $(DEVICE_TREE_OVERLAYS); do \
			sed -i "5i \\\t$$(basename $$OVERLAY_FILE | sed 's/\.dtso/\.dtbo/') \\\\" $$TARGETDIR/overlay/Makefile \
		; done \
	done

	# Create u-boot patch directory for board
	@ mkdir -p $(ARMBIAN)/patch/u-boot/$(UBOOT_TAG)/board_$(BOARDNAME)

	# Generate u-boot board defconfig patch
	@echo "--- /dev/null" > $(ARMBIAN)/patch/u-boot/$(UBOOT_TAG)/board_$(BOARDNAME)/01-add-uboot-defconfig-for-$(BOARDNAME).patch
	@echo "+++ b/configs/$(BOARDNAME)_defconfig" > $(ARMBIAN)/patch/u-boot/$(UBOOT_TAG)/board_$(BOARDNAME)/01-add-uboot-defconfig-for-$(BOARDNAME).patch
	@echo "@@ -0,0 +1,$(shell wc -l $(UBOOT_DEFCONFIG) | cut -d " " -f 1) @@" >> $(ARMBIAN)/patch/u-boot/$(UBOOT_TAG)/board_$(BOARDNAME)/01-add-uboot-defconfig-for-$(BOARDNAME).patch
	@sed 's/^/+/' $(UBOOT_DEFCONFIG) >> $(ARMBIAN)/patch/u-boot/$(UBOOT_TAG)/board_$(BOARDNAME)/01-add-uboot-defconfig-for-$(BOARDNAME).patch

	# Generate u-boot upstream device tree patch
	@echo "--- /dev/null" > $(ARMBIAN)/patch/u-boot/$(UBOOT_TAG)/board_$(BOARDNAME)/02-add-uboot-upstream-device-tree-for-$(BOARDNAME).patch
	@echo "+++ b/dts/upstream/src/arm64/rockchip/rk3328-$(BOARDNAME).dts" > $(ARMBIAN)/patch/u-boot/$(UBOOT_TAG)/board_$(BOARDNAME)/02-add-uboot-upstream-device-tree-for-$(BOARDNAME).patch
	@echo "@@ -0,0 +1,$(shell wc -l $(DEVICE_TREE) | cut -d " " -f 1) @@" >> $(ARMBIAN)/patch/u-boot/$(UBOOT_TAG)/board_$(BOARDNAME)/02-add-uboot-upstream-device-tree-for-$(BOARDNAME).patch
	@sed 's/^/+/' $(DEVICE_TREE) >> $(ARMBIAN)/patch/u-boot/$(UBOOT_TAG)/board_$(BOARDNAME)/02-add-uboot-upstream-device-tree-for-$(BOARDNAME).patch

	# Generate u-boot specific device tree include patch
	@echo "--- /dev/null" > $(ARMBIAN)/patch/u-boot/$(UBOOT_TAG)/board_$(BOARDNAME)/03-add-uboot-specific-device-tree-include-for-$(BOARDNAME).patch
	@echo "+++ b/arch/arm/dts/rk3328-$(BOARDNAME)-u-boot.dtsi" > $(ARMBIAN)/patch/u-boot/$(UBOOT_TAG)/board_$(BOARDNAME)/03-add-uboot-specific-device-tree-include-for-$(BOARDNAME).patch
	@echo "@@ -0,0 +1,$(shell wc -l $(UBOOT_DTSI) | cut -d " " -f 1) @@" >> $(ARMBIAN)/patch/u-boot/$(UBOOT_TAG)/board_$(BOARDNAME)/03-add-uboot-specific-device-tree-include-for-$(BOARDNAME).patch
	@sed 's/^/+/' $(UBOOT_DTSI) >> $(ARMBIAN)/patch/u-boot/$(UBOOT_TAG)/board_$(BOARDNAME)/03-add-uboot-specific-device-tree-include-for-$(BOARDNAME).patch

	# Generate U-Boot bootscript file
	@ install -m 0644 -D $(UBOOT_BOOTMODE_SCRIPT) $(ARMBIAN)/config/bootscripts/boot-$(BOARDNAME).cmd
	@ cat $(ARMBIAN)/config/bootscripts/boot-rockchip64.cmd >> $(ARMBIAN)/config/bootscripts/boot-$(BOARDNAME).cmd	

	@ mkdir -p $(ARMBIAN)/userpatches/overlay
	# Install systemd services
	@ install -m 0644 -D $(BOARD_SUPPORT)/systemd-units/case-led-{boot,reboot,shutoff}.service $(ARMBIAN)/userpatches/overlay/
	@ install -m 0644 -D ./customize-image.sh $(ARMBIAN)/userpatches/customize-image.sh

build:
	$(ARMBIAN)/compile.sh BOARD=$(BOARDNAME) BRANCH=$(ARMBIAN_KERNEL) BUILD_DESKTOP=no KERNEL_CONFIGURE=no RELEASE=$(ARMBIAN_RELEASE) BUILD_MINIMAL=$(ARMBIAN_MINIMAL)

