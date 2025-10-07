#!/bin/bash

# Activation helper script for Epigenetic Violence Analysis environment

ENV_NAME="epigenetic-violence-analysis"
ENV_DIR="./envs/${ENV_NAME}"

if [ ! -d "$ENV_DIR" ]; then
    echo "✗ Environment not found: $ENV_DIR"
    echo "  Run ./setup_environment.sh first"
    exit 1
fi

# Detect current shell
if [ -n "$ZSH_VERSION" ]; then
    CURRENT_SHELL="zsh"
elif [ -n "$BASH_VERSION" ]; then
    CURRENT_SHELL="bash"
else
    CURRENT_SHELL="bash"  # fallback
fi

eval "$(micromamba shell hook --shell $CURRENT_SHELL)"
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
micromamba run -p "$ENV_DIR" R --version 2>/dev/null | head -1 || echo "  (run commands with: micromamba run -p $ENV_DIR R)"
echo ""
echo "Architecture: $(uname -m) → using x86_64 packages"
echo ""
echo "To deactivate: micromamba deactivate"
