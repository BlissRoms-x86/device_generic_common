# called from modified suspend hal

# prepare env
DMIPATH=/sys/class/dmi/id
export BOARD=$(cat $DMIPATH/board_name)
export PRODUCT=$(cat $DMIPATH/product_name)
export VENDOR=$(cat $DMIPATH/sys_vendor)
export UEVENT=$(cat $DMIPATH/uevent)

# put prebaked actions here

# stop com.android.bluetooth
pm disable com.android.bluetooth
bt_pid=$(pidof com.android.bluetooth)
if [ -n "$bt_pid" ]
then
	kill -KILL $bt_pid
fi

# stop bluetooth hal
setprop ctl.stop vendor.bluetooth-1-1
setprop ctl.stop btlinux-1.1

# unload btusb here, because unloading could take 10+ seconds right after wake
modprobe -r btusb

# allow user defined actions
USER_SCRIPT=/data/etc/pre_sleep.sh
if [ -e $USER_SCRIPT ]
then
	/system/bin/sh $USER_SCRIPT
fi
