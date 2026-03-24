#!/bin/bash

# URLs for the raw Gitiles text format
BASE_URL="https://kernel.googlesource.com/pub/scm/linux/kernel/git/wens/wireless-regdb.git/+/refs/heads/master"

# Setup directories
SCRIPT_DIR=$(dirname "$0")
TARGET_DIR="$SCRIPT_DIR/wireless-regdb"

# Ensure the target directory exists
mkdir -p "$TARGET_DIR"

download_and_check() {
    local filename="$1"
    local url="${BASE_URL}/${filename}?format=TEXT"
    local temp_file="/tmp/${filename}.tmp"
    local dest_file="$TARGET_DIR/$filename"

    echo "Checking $filename..."

    # Gitiles serves raw files as base64; we decode it on the fly into the /tmp ramdisk
    if command -v curl &> /dev/null; then
        curl -s -L "$url" | base64 -d > "$temp_file"
    elif command -v wget &> /dev/null; then
        wget -q -O - "$url" | base64 -d > "$temp_file"
    else
        echo "Error: Neither curl nor wget is installed."
        exit 1
    fi

    # Check if the destination file already exists and compare hashes
    if [ -f "$dest_file" ]; then
        local temp_hash
        local dest_hash
        
        # Calculate SHA-256 hashes
        temp_hash=$(sha256sum "$temp_file" | awk '{print $1}')
        dest_hash=$(sha256sum "$dest_file" | awk '{print $1}')

        if [ "$temp_hash" == "$dest_hash" ]; then
            echo "$filename is already up to date. Skipping."
            rm -f "$temp_file"
            return 0
        fi
    fi

    echo "Updating $filename..."
    mv "$temp_file" "$dest_file"
}

download_and_check "regulatory.db"
download_and_check "regulatory.db.p7s"

echo "Wireless regdb download script execution complete!"
