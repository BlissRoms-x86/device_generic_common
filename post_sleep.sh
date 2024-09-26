# called from modified suspend hal

# prepare env
DMIPATH=/sys/class/dmi/id
export BOARD=$(cat $DMIPATH/board_name)
export PRODUCT=$(cat $DMIPATH/product_name)
export VENDOR=$(cat $DMIPATH/sys_vendor)
export UEVENT=$(cat $DMIPATH/uevent)

function reprobe_module_if_loaded()
{
	module=$1
	for modname in $(lsmod | awk '{print $1}')
	do
		if [ "$module" == "$modname" ]
		then
			modprobe -rv $module
			modprobe -v $module
			return
		fi
	done
	echo module $module not loaded, not reprobing
}

# prep the prebaked list here, if there are known devices that definitely needs this work-around
MODULE_RELOAD_LIST=""
# set RESTART_WIFI to true if a wifi module is going to be reloaded, note that users will have to manually turn on wifi again after a wificond restart
RESTART_WIFI=false

### EXAMPLE:
### if [ "$BOARD" == "xxx" ]
### then
###   MODULE_RELOAD_LIST="$MODULE_RELOAD_LIST iwlwifi"
###   RESTART_WIFI=true
### fi

# note that btusb is unloaded in pre_sleep.sh, since it takes more than 10+ seconds to unload btusb right after wake
# ie. do not put btusb into the reload list

# users can use this to flag wificond restart
USER_RESTART_WIFI_FLAG=/data/etc/wake_reload_wifi
if [ -e $USER_RESTART_WIFI_FLAG ]
then
	RESTART_WIFI=true
fi

if $RESTART_WIFI
then
	setprop ctl.stop wificond
fi

# perform module reprobe
MODULE_RELOAD_LOG=/data/wake_module_reload_log
rm -f $MODULE_RELOAD_LOG
if [ -n "$MODULE_RELOAD_LIST" ]
then
	for m in $MODULE_RELOAD_LIST
	do
		reprobe_module_if_loaded $m 2>&1 | cat >> $MODULE_RELOAD_LOG
	done
fi

# let users define a list of modules to reload on wake
USER_MODULE_RELOAD_LIST=/data/etc/wake_module_reload_list
if [ -e $USER_MODULE_RELOAD_LIST ]
then
	for m in $(cat $USER_MODULE_RELOAD_LIST)
	do
		reprobe_module_if_loaded $m 2>&1 | cat >> $MODULE_RELOAD_LOG
	done
fi

# start services again
if $RESTART_WIFI
then
	setprop ctl.start wificond
fi

# probe btusb since it was unloaded in pre_sleep.sh
modprobe btusb

# bthal and com.android.bluetooth were disabled in pre_sleep.sh
bthal=$(getprop ro.bliss.bthal)
case $bthal in
	"btlinux")
		setprop ctl.start btlinux-1.1
		;;
	"celadon")
		setprop ctl.start vendor.bluetooth-1-1
		;;
esac
pm enable com.android.bluetooth

# allow user defined actions
USER_SCRIPT=/data/etc/post_sleep.sh
if [ -e $USER_SCRIPT ]
then
	/system/bin/sh $USER_SCRIPT
fi
