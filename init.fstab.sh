#
# Copyright (C) 2024 Shadichy <shadichy@blisslabs.org>
#
# License: GNU Public License v2 or later
#

function map_device_link() {
  ln -s /dev/block/"${1#'#>'}" /dev/block/by-name/"$2"
}

function init_loop_links() {
  mkdir -p /dev/block/by-name

  while read -r line; do
    case "$line" in
    '#>'*) map_device_link $line ;;
    *) ;;
    esac
  done <"$(ls /fstab.*)"

  ln -s /dev/block/by-name/kernel_a /dev/block/by-name/boot_a
  ln -s /dev/block/by-name/kernel_b /dev/block/by-name/boot_b

  ln -s /dev/block/by-name/recovery_a /dev/block/by-name/ramdisk-recovery_a
  ln -s /dev/block/by-name/recovery_b /dev/block/by-name/ramdisk-recovery_b
}

init_loop_links
