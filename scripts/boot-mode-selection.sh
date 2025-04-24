#!/vendor/bin/sh -e

# Determine the configuration file path
CFG_PATH=$(getprop ro.boot.bootctrl_bootcfg)

klog() {
    echo "$0: $@" > /dev/kmsg
}

if [ -z "$CFG_PATH" ]; then
    if [ -f "/boot/grub/android.cfg" ]; then
        CFG_PATH="/boot/grub/android.cfg"
    elif [ -f "/boot/efi/EFI/refind/android.conf" ]; then
        CFG_PATH="/boot/efi/EFI/refind/android.conf"
    else
        klog "Error: No valid configuration file found"
        setprop vendor.boot-mode-selection.complete true  
        exit 1
    fi
fi

# Check if the configuration file is writable
if [ ! -w "$CFG_PATH" ]; then
    klog "Error: $CFG_PATH is not writable"
    setprop vendor.boot-mode-selection.complete true 
    exit 1
fi

# Determine boot mode from first argument
REASON=$(echo -n "$1" | cut -c 2-)
case "$REASON" in
    recovery|recovery-update)
        new_mode="recovery"
        ;;
    *)
        new_mode="normal"
        ;;
esac

# First pass: Try to modify androidboot.mode
found_android=0
while IFS= read -r line; do
    if [ "$found_android" -eq 0 ] && echo "$line" | grep -q 'androidboot\.mode='; then
        line=$(echo "$line" | sed "s/androidboot\.mode=[^ ]*/androidboot.mode=$new_mode/")
        found_android=1
    fi
    printf '%s\n' "$line"
done < "$CFG_PATH" > "$CFG_PATH.tmp" && mv "$CFG_PATH.tmp" "$CFG_PATH"

# Second pass: Fallback to MODE= if androidboot.mode wasn't found
if [ "$found_android" -eq 0 ]; then
    klog "Notice: androidboot.mode not found, checking for MODE="
    
    found_mode=0
    while IFS= read -r line; do
        if [ "$found_mode" -eq 0 ] && echo "$line" | grep -q 'MODE='; then
            line=$(echo "$line" | sed "s/MODE=[^ ]*/MODE=$new_mode/")
            found_mode=1
        fi
        printf '%s\n' "$line"
    done < "$CFG_PATH" > "$CFG_PATH.tmp" && mv "$CFG_PATH.tmp" "$CFG_PATH"

    if [ "$found_mode" -eq 0 ]; then
        klog "Error: Neither androidboot.mode nor MODE= found in $CFG_PATH"
        setprop vendor.boot-mode-selection.complete true 
        exit 1
    else
        klog "Success: Updated MODE= to $new_mode"
        setprop vendor.boot-mode-selection.complete true 
        exit 0
    fi
else
    klog "Success: Updated androidboot.mode to $new_mode"
    setprop vendor.boot-mode-selection.complete true 
    exit 0
fi
