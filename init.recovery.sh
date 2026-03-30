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

function init_graphics()
{
	# Loop with a timeout (e.g., 20 attempts, 0.5s each = 10 seconds max)
	for attempt in $(seq 1 20); do
		for i in $(seq 0 9); do
			if [ -c "/dev/dri/card$i" ]; then
				local driver_name=""
				
				if [ -L "/sys/class/drm/card$i/device/driver" ]; then
					driver_name=$(basename $(readlink /sys/class/drm/card$i/device/driver))
				elif [ -f "/sys/class/drm/card$i/device/uevent" ]; then
					driver_name=$(grep DRIVER= /sys/class/drm/card$i/device/uevent | cut -d= -f2)
				fi

				# Ignore simple framebuffers or unpopulated sysfs entries
				if [[ "$driver_name" == *simple* ]] || [ -z "$driver_name" ]; then
					if [ "$HWACCEL" != "0" ]; then
						continue
					fi
				fi

				break 2
			fi
		done
		sleep 0.5
	done

	if [ "$HWACCEL" == "0" ]; then
		set_property ro.minui.graphics_backend fbdev
	fi

	# Wait for Framebuffer device
	local fb_node="fb0"
	for attempt in $(seq 1 20); do
		for j in $(seq 0 9); do
			# Check if the driver symlink is populated
			if [ -L "/sys/class/graphics/fb$j/device/driver" ]; then
				local fb_driver_name=$(basename $(readlink /sys/class/graphics/fb$j/device/driver))

				# Ignore simple framebuffers or unpopulated sysfs entries
				if [[ "$fb_driver_name" == *simple* ]] || [ -z "$fb_driver_name" ]; then
					if [ "$HWACCEL" != "0" ]; then
						continue
					fi
				fi

				fb_node="fb$j"
				break 2
			fi
		done
		sleep 0.5
	done

	case "$(readlink /sys/class/graphics/$fb_node/device/driver)" in
		*i915)
			set_property ro.minui.pixel_format RGBX_8888
			;;
		*amdgpu)
			set_property ro.minui.pixel_format ARGB_8888
			;;
		*vmwgfx)
			set_property ro.minui.pixel_format BGRX_8888
			;;
		*)
			;;
	esac
}

function init_misc()
{
	# Tell vold to use ntfs3 driver instead of ntfs-3g
    if [ "$USE_NTFS3" -ge "1" ] || [ "$VOLD_USE_NTFS3" -ge 1 ]; then
        set_property ro.vold.use_ntfs3 true
    fi

    set_property service.adb.tcp.port ${DEBUG_NET_PORT:-5555}
}

function init_recovery_device_link()
{
	# Insert /data to recovery.fstab
	if grep -E '^[[:space:]]*[^#].+ /data ' "$(ls /fstab.*)" >> /etc/recovery.fstab; then
		set_property sys.recovery.data_is_part true
	fi

	# Insert /system into recovery.fstab
	if [ "$(getprop ro.boot.slot_suffix)" ]; then
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
	init_graphics
    init_misc
	init_recovery_device_link
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
			;;
	esac
done

if [ -n "$DEBUG" ]; then
    exec > /tmp/recovery_init.log 2>&1
	set -x
fi

case "$1" in
	netconsole)
		[ -n "$DEBUG" ] && do_netconsole
		;;
	init|"")
		do_init
		;;
esac

return 0
