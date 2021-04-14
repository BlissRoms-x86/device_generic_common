#
# Copyright (C) 2014-2019 The Android-x86 Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#

# Android makefile to build kernel as a part of Android Build
#
# Configuration
# =============
#
# These config vars are usually set in BoardConfig.mk:
#
#   TARGET_KERNEL_CONFIG               = Kernel defconfig
#   TARGET_KERNEL_VARIANT_CONFIG       = Variant defconfig, optional
#   TARGET_KERNEL_SELINUX_CONFIG       = SELinux defconfig, optional
#   TARGET_KERNEL_ADDITIONAL_CONFIG    = Additional defconfig, optional
#
#   TARGET_KERNEL_CLANG_COMPILE        = Compile kernel with clang, defaults to false
#
#   TARGET_KERNEL_CLANG_VERSION        = Clang prebuilts version, optional, defaults to clang-stable
#
#   TARGET_KERNEL_CLANG_PATH           = Clang prebuilts path, optional
#
#   BOARD_KERNEL_IMAGE_NAME            = Built image name
#                                          for ARM use: zImage
#                                          for ARM64 use: Image.gz
#                                          for uncompressed use: Image
#                                          If using an appended DT, append '-dtb'
#                                          to the end of the image name.
#                                          For example, for ARM devices,
#                                          use zImage-dtb instead of zImage.
#
#   KERNEL_CC                          = The C Compiler used. This is automatically set based
#                                          on whether the clang version is set, optional.
#
#   KERNEL_CLANG_TRIPLE                = Target triple for clang (e.g. aarch64-linux-gnu-)
#                                          defaults to arm-linux-gnu- for arm
#                                                      aarch64-linux-gnu- for arm64
#                                                      x86_64-linux-gnu- for x86
#
#   NEED_KERNEL_MODULE_ROOT            = Optional, if true, install kernel
#                                          modules in root instead of vendor
#   NEED_KERNEL_MODULE_SYSTEM          = Optional, if true, install kernel
#                                          modules in system instead of vendor

ifneq ($(TARGET_NO_KERNEL),true)
ifeq ($(TARGET_PREBUILT_KERNEL),)

KERNEL_DIR ?= kernel

ifeq ($(KERNEL_ARCH),x86_64)
TARGET_KERNEL_ARCH ?= x86_64
KERNEL_TARGET := bzImage
KERNEL_CONFIG_DIR := arch/x86/configs
TARGET_KERNEL_CONFIG ?= android-x86_64_defconfig
else ifeq ($(KERNEL_ARCH),x86)
TARGET_KERNEL_ARCH ?= x86
KERNEL_CONFIG_DIR := arch/x86/configs
TARGET_KERNEL_CONFIG ?= android-x86_defconfig
endif

ifeq ($(TARGET_ARCH),arm)
KERNEL_TARGET := zImage
TARGET_KERNEL_CONFIG ?= goldfish_defconfig
KERNEL_CONFIG_DIR := arch/arm/configs
endif

# Grab current kernel version information
ROM_FOLDER_LOCATION := $(abspath $(PWD))
KERNEL_MAKEFILE_LOCATION := "$(ROM_FOLDER_LOCATION)/kernel/Makefile"
VERSION := $(shell grep -m 1 VERSION $(KERNEL_MAKEFILE_LOCATION) | sed 's/^.*= //g')
PATCHLEVEL := $(shell grep -m 1 PATCHLEVEL $(KERNEL_MAKEFILE_LOCATION) | sed 's/^.*= //g')
SUBLEVEL := $(shell grep -m 1 SUBLEVEL $(KERNEL_MAKEFILE_LOCATION) | sed 's/^.*= //g')

ifeq ($(BUILD_KERNEL_WITH_CLANG),true)
KERNEL_CROSS_COMPILE := x86_64-linux-androidkernel-
KERNEL_CLANG_CLAGS += CC=clang HOSTCC=clang CLANG_TRIPLE=x86_64-linux-gnu- PATH=$(abspath $(LLVM_PREBUILTS_BASE)/$(BUILD_OS)-x86/$(LLVM_PREBUILTS_VERSION)/bin):$$PATH 
# If current kernel version >= 5.9 
else ifeq ($(shell expr $(VERSION) \>= 5 "&" $(PATCHLEVEL) \>= 9), 1)
KERNEL_CROSS_COMPILE ?= $(abspath $(TARGET_TOOLS_PREFIX))
# If current kernel version <= 5.9 
else ifeq ($(shell expr $(VERSION) \>= 5 "&" $(PATCHLEVEL) \<= 9 "|" $(VERSION) \< 5), 1)
ifeq ($(HOST_OS),darwin)
KERNEL_CROSS_COMPILE ?= $(abspath prebuilts/gcc/darwin-x86/host/i686-apple-darwin-4.2.1/bin)/i686-apple-darwin11-
else 
KERNEL_CROSS_COMPILE ?= $(abspath prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.11-4.6/bin)/x86_64-linux-
endif
else
KERNEL_CROSS_COMPILE ?= $(abspath $(TARGET_TOOLS_PREFIX))
endif
# Allow to use local gcc: "export NO_KERNEL_CROSS_COMPILE=true" 
# or adding NO_KERNEL_CROSS_COMPILE := true to BoardConfig.mk
ifeq ($(NO_KERNEL_CROSS_COMPILE),true)
KERNEL_CROSS_COMPILE ?=
endif

KBUILD_OUTPUT := $(abspath $(TARGET_OUT_INTERMEDIATES)/kernel)
mk_kernel := + $(hide) $(MAKE) $(if $(filter darwin,$(HOST_OS)),-j$$(sysctl -n hw.ncpu) -l$$(($$(sysctl -n hw.ncpu)+2)),-j$$(nproc) -l$$(($$(nproc)+2))) \
	-C $(KERNEL_DIR) O=$(KBUILD_OUTPUT) ARCH=$(TARGET_ARCH) CROSS_COMPILE="$(abspath $(CC_WRAPPER)) $(CROSS_COMPILE)" $(if $(SHOW_COMMANDS),V=1) \
	# YACC=$(abspath $(BISON)) LEX=$(abspath $(LEX)) \
	$(KERNEL_CLANG_CLAGS)

KERNEL_CONFIG_FILE := $(if $(wildcard $(TARGET_KERNEL_CONFIG)),$(TARGET_KERNEL_CONFIG),$(KERNEL_DIR)/$(KERNEL_CONFIG_DIR)/$(TARGET_KERNEL_CONFIG))

MOD_ENABLED := $(shell grep ^CONFIG_MODULES=y $(KERNEL_CONFIG_FILE))
FIRMWARE_ENABLED := $(shell grep ^CONFIG_FIRMWARE_IN_KERNEL=y $(KERNEL_CONFIG_FILE))

# I understand Android build system discourage to use submake,
# but I don't want to write a complex Android.mk to build kernel.
# This is the simplest way I can think.
KERNEL_DOTCONFIG_FILE := $(KBUILD_OUTPUT)/.config
KERNEL_ARCH_CHANGED := $(if $(filter 0,$(shell grep -s ^$(if $(filter x86,$(TARGET_KERNEL_ARCH)),\#.)CONFIG_64BIT $(KERNEL_DOTCONFIG_FILE) | wc -l)),FORCE)
$(KERNEL_DOTCONFIG_FILE): $(KERNEL_CONFIG_FILE) $(wildcard $(TARGET_KERNEL_DIFFCONFIG)) $(KERNEL_ARCH_CHANGED)
	$(hide) mkdir -p $(@D) && cat $(wildcard $^) > $@
	$(hide) ln -sf ../../../../../../prebuilts $(@D)
	$(mk_kernel) olddefconfig

BUILT_KERNEL_TARGET := $(KBUILD_OUTPUT)/arch/$(TARGET_ARCH)/boot/$(KERNEL_TARGET)
$(BUILT_KERNEL_TARGET): $(KERNEL_DOTCONFIG_FILE)
	$(mk_kernel) $(KERNEL_TARGET) $(if $(MOD_ENABLED),modules)
	$(if $(FIRMWARE_ENABLED),$(mk_kernel) INSTALL_MOD_PATH=$(abspath $(TARGET_OUT)) firmware_install)

ifneq ($(MOD_ENABLED),)
KERNEL_MODULES_DEP := $(firstword $(wildcard $(TARGET_OUT)/lib/modules/*/modules.dep))
KERNEL_MODULES_DEP := $(if $(KERNEL_MODULES_DEP),$(KERNEL_MODULES_DEP),$(TARGET_OUT)/lib/modules)

ALL_EXTRA_MODULES := $(patsubst %,$(TARGET_OUT_INTERMEDIATES)/kmodule/%,$(TARGET_EXTRA_KERNEL_MODULES))
$(ALL_EXTRA_MODULES): $(TARGET_OUT_INTERMEDIATES)/kmodule/%: $(BUILT_KERNEL_TARGET) | $(ACP)
	@echo Building additional kernel module $*
	$(hide) mkdir -p $(@D) && $(ACP) -fr $(EXTRA_KERNEL_MODULE_PATH_$*) $(@D)
	$(mk_kernel) M=$(abspath $@) modules || ( rm -rf $@ && exit 1 )

$(KERNEL_MODULES_DEP): $(BUILT_KERNEL_TARGET) $(ALL_EXTRA_MODULES)
	$(hide) rm -rf $(TARGET_OUT)/lib/modules
	$(mk_kernel) INSTALL_MOD_PATH=$(abspath $(TARGET_OUT)) modules_install
	+ $(hide) for kmod in $(TARGET_EXTRA_KERNEL_MODULES) ; do \
		echo Installing additional kernel module $${kmod} ; \
		$(subst +,,$(subst $(hide),,$(mk_kernel))) INSTALL_MOD_PATH=$(abspath $(TARGET_OUT)) M=$(abspath $(TARGET_OUT_INTERMEDIATES))/kmodule/$${kmod} modules_install ; \
	done
	$(hide) rm -f $(TARGET_OUT)/lib/modules/*/{build,source}
endif

$(BUILT_SYSTEMIMAGE): $(KERNEL_MODULES_DEP)

installclean: FILES += $(KBUILD_OUTPUT) $(INSTALLED_KERNEL_TARGET)

TARGET_PREBUILT_KERNEL := $(BUILT_KERNEL_TARGET)

.PHONY: kernel $(if $(KERNEL_ARCH_CHANGED),$(KERNEL_HEADERS_COMMON)/linux/binder.h)
kernel: $(INSTALLED_KERNEL_TARGET) $(KERNEL_MODULES_DEP)

endif # TARGET_PREBUILT_KERNEL

ifndef LINEAGE_BUILD
$(INSTALLED_KERNEL_TARGET): $(TARGET_PREBUILT_KERNEL) | $(ACP)
	$(copy-file-to-new-target)
ifdef TARGET_PREBUILT_MODULES
	mkdir -p $(TARGET_OUT)/lib
	$(hide) cp -r $(TARGET_PREBUILT_MODULES) $(TARGET_OUT)/lib
endif
endif # LINEAGE_BUILD
endif # KBUILD_OUTPUT
