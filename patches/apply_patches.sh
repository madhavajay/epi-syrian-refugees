#!/bin/bash

# Script to apply patches to extracted R markdown files
# Run this after extracting fresh copies from authors' original files

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==========================================="
echo "Applying Analysis Patches"
echo "==========================================="

# Check if patch file exists
if [ ! -f "$SCRIPT_DIR/nmds_fix.patch" ]; then
    echo "✗ Patch file not found: $SCRIPT_DIR/nmds_fix.patch"
    exit 1
fi

# Apply NMDS fix patch
echo "Applying NMDS fix patch..."
cd "$PROJECT_ROOT"

if patch -p1 --dry-run < "$SCRIPT_DIR/nmds_fix.patch" >/dev/null 2>&1; then
    patch -p1 < "$SCRIPT_DIR/nmds_fix.patch"
    echo "✓ NMDS fix applied successfully"
else
    echo "⚠ Patch already applied or conflicts detected"
    echo "  Attempting reverse check..."
    if patch -p1 -R --dry-run < "$SCRIPT_DIR/nmds_fix.patch" >/dev/null 2>&1; then
        echo "✓ Patch already applied"
    else
        echo "✗ Patch conflicts - manual intervention required"
        exit 1
    fi
fi

echo ""
echo "==========================================="
echo "Patch Application Complete"
echo "==========================================="
