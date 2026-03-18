#!/bin/bash

PCI_URL="https://pci-ids.ucw.cz/v2.2/pci.ids"
USB_URL="http://www.linux-usb.org/usb.ids"

# Get the script's directory and change to it
SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR/ids" || exit

download_and_check() {
    local file_name="$1"
    local url="$2"
    # Route the temporary download to the RAM-backed /tmp directory
    local temp_file="/tmp/${file_name}.tmp"

    echo "Checking $file_name..."
    
    # Download to the RAM disk
    if command -v curl &> /dev/null; then
        curl -s -L -o "$temp_file" "$url"
    elif command -v wget &> /dev/null; then
        wget -q -O "$temp_file" "$url"
    else
        echo "Error: Neither curl nor wget is installed."
        exit 1
    fi

    # Extract versions using regex to catch both tabbed and spaced formatting
    local new_version
    new_version=$(grep -i -m 1 "^#[[:space:]]*Version:" "$temp_file" | awk '{print $NF}')

    local current_version="None"
    if [[ -f "$file_name" ]]; then
        current_version=$(grep -i -m 1 "^#[[:space:]]*Version:" "$file_name" | awk '{print $NF}')
    fi

    if [[ -z "$new_version" ]]; then
        echo "Warning: Could not parse the version from the downloaded $file_name. Replacing anyway."
        mv "$temp_file" "$file_name"
    elif [[ "$new_version" == "$current_version" ]]; then
        echo "$file_name is already up to date (Version: $current_version). Skipping."
        # Clean up the RAM disk file
        rm "$temp_file"
    else
        echo "Updating $file_name: $current_version -> $new_version"
        # Move it from /tmp to your working directory only if there's an update
        mv "$temp_file" "$file_name"
    fi
}

download_and_check "pci.ids" "$PCI_URL"
download_and_check "usb.ids" "$USB_URL"

echo "Script execution complete!"
