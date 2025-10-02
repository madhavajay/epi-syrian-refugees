#!/bin/bash

# Activation helper script for Epigenetic Violence Analysis environment

ENV_NAME="epigenetic-violence-analysis"
ENV_DIR="./envs/${ENV_NAME}"

if [ ! -d "$ENV_DIR" ]; then
    echo "✗ Environment not found: $ENV_DIR"
    echo "  Run ./setup_environment.sh first"
    exit 1
fi

eval "$(micromamba shell hook --shell bash)"
micromamba activate "$ENV_DIR"

# Ensure x86_64 architecture on ARM Macs
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    export CONDA_SUBDIR=osx-64
    echo "✓ Activated environment: Epigenetic Violence Analysis ($ENV_NAME) [x86_64 via Rosetta]"
else
    echo "✓ Activated environment: Epigenetic Violence Analysis ($ENV_NAME) [x86_64]"
fi

echo ""
echo "R version:"
if [[ "$ARCH" == "arm64" ]]; then
    arch -x86_64 R --version | head -1
else
    R --version | head -1
fi
echo ""
echo "Architecture: $(uname -m) → using x86_64 packages"
echo ""
echo "To deactivate: micromamba deactivate"
