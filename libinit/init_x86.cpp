/*
 * Copyright (C) 2021 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <android-base/file.h>
#include <android-base/properties.h>
#include <sys/sysinfo.h>

#include <libinit_dalvik_heap.h>
#include <libinit_utils.h>

#include "vendor_init.h"

#include <unordered_map>

using android::base::GetProperty;
using android::base::ReadFileToString;

static const std::string kDmiIdPath = "/sys/devices/virtual/dmi/id/";

static const std::unordered_map<std::string, std::string> kDmiIdToPropertyMap = {
    {"bios_version", "ro.boot.bootloader"},
    {"product_serial", "ro.bliss.serialnumber"},
    {"board_name", "ro.product.board"},
};

static const std::unordered_map<std::string, std::string> kDmiIdToRoBuildPropMap = {
    {"product_name", "name"},
    {"chassis_vendor", "brand"},
    {"board_name", "model"},
    {"sys_vendor", "manufacturer"},
};

static const std::unordered_map<std::string, std::string> kLenovoDmiIdToRoBuildPropMap = {
    {"product_family", "name"},
    {"chassis_vendor", "brand"},
    {"board_name", "model"},
    {"sys_vendor", "manufacturer"},
};

static bool is_lenovo() {
    std::string value;
    if (ReadFileToString(kDmiIdPath + "sys_vendor", &value)) {
        value.pop_back();
        return value == "Lenovo" || value == "LENOVO";
    }
    return false;
}

static void set_misc_properties() {
    if (GetProperty("ro.boot.insecure_adb", "") == "1") {
        property_override("ro.adb.secure", "0");
        property_override("ro.secure", "0");
    }
}

static void set_properties_from_dmi_id() {
    std::string value;

    for (const auto& [file, prop] : kDmiIdToPropertyMap) {
        ReadFileToString(kDmiIdPath + file, &value);
        if (value.empty())
            continue;
        value.pop_back();
        property_override(prop, value);
    }

    if (is_lenovo()) {
        for (const auto& [file, ro_build_prop] : kLenovoDmiIdToRoBuildPropMap) {
            ReadFileToString(kDmiIdPath + file, &value);
            if (value.empty())
                continue;
            value.pop_back();
            set_ro_build_prop(ro_build_prop, value, true);
        }
        return;
    }

    for (const auto& [file, ro_build_prop] : kDmiIdToRoBuildPropMap) {
        ReadFileToString(kDmiIdPath + file, &value);
        if (value.empty())
            continue;
        value.pop_back();
        set_ro_build_prop(ro_build_prop, value, true);
    }
}

void vendor_load_properties() {
    set_dalvik_heap();
    set_misc_properties();
    set_properties_from_dmi_id();
}
