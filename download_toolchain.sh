#!/bin/bash

# Configuration Variables
CLANG_VER="${CLANG_VER:-clang-r584948b}"
CLANG_BRANCH="${CLANG_BRANCH:-mirror-goog-llvm-r596125-release}"
CLANG_TOOLS_BRANCH="${CLANG_TOOLS_BRANCH:-main-kernel-2026}"
RUST_TOOL_VER="${RUST_TOOL_VER:-1.93.1}"
RUST_TOOL_BRANCH="${RUST_TOOL_BRANCH:-main-kernel-2026}"

# Target Directories
CLANG_DIR="prebuilts/clang/host/linux-x86"
CLANG_TOOLS_DIR="prebuilts/clang-tools-kernel" 
RUST_DIR="prebuilts/rust-toolchain/linux-x86"

# Gitiles Base URL
BASE_URL="https://android.googlesource.com/platform"

# Ensure we are running from the root of the tree
if [ ! -d "build" ] && [ ! -d "prebuilts" ]; then
    echo "Warning: This script should probably be run from the root of your source tree."
fi

# Function to download and extract from tar.gz
download_and_extract() {
    local url="$1"
    local dest_dir="$2"
    local temp_tar=".temp_toolchain.tar.gz"

    # Clean up any leftover temp file
    rm -f "$temp_tar"

    echo "Downloading from $url..."
    if command -v curl &> /dev/null; then
        curl -s -L -o "$temp_tar" "$url"
    elif command -v wget &> /dev/null; then
        wget -q -O "$temp_tar" "$url"
    else
        echo "Error: Neither curl nor wget is installed."
        exit 1
    fi

    echo "Extracting to $dest_dir..."
    mkdir -p "$dest_dir"
    
    # Extract directly into the destination directory
    tar -xzf "$temp_tar" -C "$dest_dir"

    # Clean up the local temp file after extraction
    rm -f "$temp_tar"
}

# ---------------------------------------------------------
# 1. Clang Host Linux-x86
# ---------------------------------------------------------
echo "=== Checking Clang Toolchain ==="
if [ -d "$CLANG_DIR/$CLANG_VER" ]; then
    echo "Clang $CLANG_VER already exists in $CLANG_DIR. Skipping download."
else
    echo "Updating Clang to $CLANG_VER..."
    
    # If it's a git repo, clean up previous *untracked* clang directories to keep status clean
    if git -C "$CLANG_DIR" rev-parse --is-inside-work-tree &> /dev/null; then
        echo "Cleaning up previous untracked custom Clang directories..."
        git -C "$CLANG_DIR" ls-files --others --exclude-standard --directory | grep '^clang-' | xargs -I {} rm -rf "$CLANG_DIR/{}"
    else
        mkdir -p "$CLANG_DIR"
        find "$CLANG_DIR" -maxdepth 1 -mindepth 1 -type d -name "clang-*" -exec rm -rf {} +
    fi
    
    # Use the targeted subdirectory archive URL
    CLANG_URL="${BASE_URL}/prebuilts/clang/host/linux-x86/+archive/${CLANG_BRANCH}/${CLANG_VER}.tar.gz"
    
    # Notice we pass $CLANG_DIR/$CLANG_VER as the exact destination now
    download_and_extract "$CLANG_URL" "$CLANG_DIR/$CLANG_VER"

    # Show git status to confirm the hack worked
    if git -C "$CLANG_DIR" rev-parse --is-inside-work-tree &> /dev/null; then
        echo -e "\n[ Git Status for Clang ]"
        git -C "$CLANG_DIR" status -s
    fi
fi
echo ""

# ---------------------------------------------------------
# 2. Clang-Tools
# ---------------------------------------------------------
echo "=== Checking Clang Tools ==="
if [ -f "$CLANG_TOOLS_DIR/version.txt" ] && grep -q "^${CLANG_TOOLS_BRANCH}$" "$CLANG_TOOLS_DIR/version.txt"; then
    echo "Clang-tools is already up to date ($CLANG_TOOLS_BRANCH). Skipping."
else
    echo "Updating Clang-tools to $CLANG_TOOLS_BRANCH..."
    mkdir -p "$CLANG_TOOLS_DIR"
    
    # Remove all contents EXCEPT .git
    find "$CLANG_TOOLS_DIR" -maxdepth 1 -mindepth 1 ! -name ".git" -exec rm -rf {} +
    
    CLANG_TOOLS_URL="${BASE_URL}/prebuilts/clang-tools/+archive/${CLANG_TOOLS_BRANCH}.tar.gz"
    download_and_extract "$CLANG_TOOLS_URL" "$CLANG_TOOLS_DIR"
    
    # Remove Android.bp if it exists to avoid build conflicts
    if [ -f "$CLANG_TOOLS_DIR/Android.bp" ]; then
        echo "Removing Android.bp from clang-tools..."
        rm -f "$CLANG_TOOLS_DIR/Android.bp"
    fi
    
    # Create version tracking file
    echo "$CLANG_TOOLS_BRANCH" > "$CLANG_TOOLS_DIR/version.txt"
fi
echo ""

# ---------------------------------------------------------
# 3. Rust Toolchain Linux-x86
# ---------------------------------------------------------
echo "=== Checking Rust Toolchain ==="
if [ -d "$RUST_DIR/$RUST_TOOL_VER" ]; then
    echo "Rust toolchain $RUST_TOOL_VER already exists in $RUST_DIR. Skipping download."
else
    echo "Updating Rust toolchain to $RUST_TOOL_VER..."

    # Check for legacy vs new way
    if git -C "$RUST_DIR" rev-parse --is-inside-work-tree &> /dev/null; then
        echo "Detected Git repository for Rust toolchain (New Way)."
        echo "Cleaning up previous untracked custom Rust directories..."
        # Safely remove untracked custom rust folders (e.g., 1.93.1)
        git -C "$RUST_DIR" ls-files --others --exclude-standard --directory | grep -E '^[0-9]+\.[0-9]+' | xargs -I {} rm -rf "$RUST_DIR/{}"
    else
        echo "No Git repository detected for Rust toolchain (Legacy Way)."
        mkdir -p "$RUST_DIR"
        find "$RUST_DIR" -maxdepth 1 -mindepth 1 -type d -name "[0-9]*.[0-9]*" -exec rm -rf {} +
    fi

    # Use the targeted subdirectory archive URL
    RUST_URL="${BASE_URL}/prebuilts/rust-toolchain/linux-x86/+archive/${RUST_TOOL_BRANCH}/${RUST_TOOL_VER}.tar.gz"
    
    # Pass $RUST_DIR/$RUST_TOOL_VER as the exact destination
    download_and_extract "$RUST_URL" "$RUST_DIR/$RUST_TOOL_VER"
fi

# Show git status to confirm the hack worked (if it's a git repo)
if git -C "$RUST_DIR" rev-parse --is-inside-work-tree &> /dev/null; then
    echo -e "\n[ Git Status for Rust ]"
    git -C "$RUST_DIR" status -s
fi
echo ""

echo "Toolchain download script execution complete!"
