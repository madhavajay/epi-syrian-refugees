#!/bin/bash

set -e  # Exit on error

DOWNLOAD_DIR="downloads"
DATA_DIR="data"

echo "========================================="
echo "Extracting raw data archives"
echo "========================================="
echo ""

mkdir -p "$DATA_DIR"

shopt -s nullglob
archives=( "$DOWNLOAD_DIR"/*.zip )
if [ ${#archives[@]} -eq 0 ]; then
    legacy_archives=( "$DATA_DIR"/*.zip )
    if [ ${#legacy_archives[@]} -gt 0 ]; then
        echo "Found ZIP files in data/. Moving them to $DOWNLOAD_DIR/ for consistency..."
        mkdir -p "$DOWNLOAD_DIR"
        for legacy in "${legacy_archives[@]}"; do
            mv "$legacy" "$DOWNLOAD_DIR/"
        done
        archives=( "$DOWNLOAD_DIR"/*.zip )
    fi
fi

if [ ! -d "$DOWNLOAD_DIR" ]; then
    echo "✗ $DOWNLOAD_DIR/ not found. Run ./download.sh first."
    exit 1
fi

if [ ${#archives[@]} -eq 0 ]; then
    echo "No ZIP files found in $DOWNLOAD_DIR/. Nothing to extract."
    exit 0
fi

for archive_path in "${archives[@]}"; do
    archive=$(basename "$archive_path")
    target_dir="$DATA_DIR/${archive%.zip}"

    echo "Extracting: $archive -> $target_dir/"
    mkdir -p "$target_dir"
    unzip -o "$archive_path" -d "$target_dir" >/dev/null
    echo "  ✓ Done"
    echo ""
done

echo "All archives processed."
echo "Run ./link_data.sh next to create the directory structure and symlinks."
