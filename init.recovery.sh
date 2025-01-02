#
# Copyright (C) 2024 BlissLabs
#
# License: GNU Public License v2 or later
#

function set_property()
{
	setprop "$1" "$2"
	[ -n "$DEBUG" ] && echo "$1"="$2" >> /dev/x86.prop
}

function set_prop_if_empty()
{
	[ -z "$(getprop $1)" ] && set_property "$1" "$2"
}

function init_misc()
{
	# Tell vold to use ntfs3 driver instead of ntfs-3g
    if [ "$USE_NTFS3" -ge "1" ] || [ "$VOLD_USE_NTFS3" -ge 1 ]; then
        set_property ro.vold.use_ntfs3 true
    fi
}

function map_device_link()
{
	ln -s /dev/block/"${1#'#>'}" /dev/block/by-name/"$2"
}

function init_loop_links()
{
    # Setup partitions loop
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

    # Insert /data to recovery.fstab
    if grep /dev/block/by-name/userdata "$(ls /fstab.*)" >> /etc/recovery.fstab; then
        set_property sys.recovery.data_is_part true
    fi

    # Insert /system into recovery.fstab
    ab_slot=$(getprop ro.boot.slot_suffix)
    if [ "$ab_slot" ]; then
        echo "/dev/block/by-name/system     /system   ext4    defaults        slotselect,first_stage_mount" >> /etc/recovery.fstab
    else
        echo "/dev/block/by-name/system     /system   ext4    defaults        defaults" >> /etc/recovery.fstab
    fi

    # Create /dev/block/bootdevice/by-name
    # because some scripts are dumb
    mkdir -p /dev/block/bootdevice
    ln -s /dev/block/by-name /dev/block/bootdevice/by-name
}

function do_netconsole()
{
	modprobe netconsole netconsole="@/,@$(getprop dhcp.eth0.gateway)/"
}

function do_init()
{
    init_misc
	init_loop_links
}

# import cmdline variables
for c in `cat /proc/cmdline`; do
	case $c in
		BOOT_IMAGE=*|iso-scan/*|*.*=*)
			;;
		nomodeset)
			HWACCEL=0
			;;
		*=*)
			eval $c
			if [ -z "$1" ]; then
				case $c in
					DEBUG=*)
						[ -n "$DEBUG" ] && set_property debug.logcat 1
						[ "$DEBUG" = "0" ] || SETUPWIZARD=${SETUPWIZARD:-0}
						;;
					DPI=*)
						set_property ro.sf.lcd_density "$DPI"
						;;
				esac
			fi
			;;
	esac
done

[ -n "$DEBUG" ] && set -x || exec &> /dev/null

case "$1" in
	netconsole)
		[ -n "$DEBUG" ] && do_netconsole
		;;
	init|"")
		do_init
		;;
esac

return 0
