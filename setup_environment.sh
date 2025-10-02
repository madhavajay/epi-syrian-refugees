#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Setting up R environment for Epigenetic Violence Analysis"
echo "========================================="
echo ""

# Environment name and location
ENV_NAME="epigenetic-violence-analysis"
ENV_DIR="./envs/${ENV_NAME}"

echo "Environment: $ENV_NAME"
echo "Location: $ENV_DIR"
echo ""

# Check if micromamba is installed
if ! command -v micromamba &> /dev/null; then
    echo "✗ micromamba not found. Please install micromamba first."
    echo "  Install: curl -Ls https://micro.mamba.pm/install.sh | bash"
    exit 1
fi

echo "✓ micromamba found: $(which micromamba)"
echo ""

# Detect architecture and set platform
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    echo "⚠ Detected ARM64 (Apple Silicon) - forcing x86_64 architecture"
    export CONDA_SUBDIR=osx-64
    PLATFORM_FLAG="--platform=osx-64"
else
    echo "✓ Detected x86_64 architecture"
    PLATFORM_FLAG=""
fi

# Create environment if it doesn't exist
if [ -d "$ENV_DIR" ]; then
    echo "✓ Environment already exists: $ENV_DIR"
    echo "  To recreate, delete: rm -rf $ENV_DIR"
else
    echo "Creating micromamba environment (x86_64)..."
    CONDA_SUBDIR=osx-64 micromamba create -p "$ENV_DIR" -c conda-forge -c bioconda -y \
        r-base=4.2 \
        r-essentials \
        r-devtools \
        bioconductor-minfi \
        bioconductor-sesame \
        bioconductor-sesamedata \
        bioconductor-epidish \
        r-here \
        r-kableextra \
        r-tidyverse \
        r-data.table \
        r-ggplot2 \
        r-dplyr \
        r-tidyr \
        r-stringr \
        r-magrittr \
        r-dt \
        r-purrr \
        r-forcats \
        r-rebus

    echo "✓ Base environment created (x86_64)"

    # Set conda subdir permanently for this environment
    if [[ "$ARCH" == "arm64" ]]; then
        # Create .condarc file in environment to force x86_64
        cat > "${ENV_DIR}/.condarc" <<EOF
subdir: osx-64
EOF
        echo "✓ Environment configured for x86_64 packages"
    fi
fi

echo ""
echo "========================================="
echo "Installing R packages"
echo "========================================="
echo ""

# Activate environment and install packages
eval "$(micromamba shell hook --shell bash)"
micromamba activate "$ENV_DIR"

# Ensure x86_64 for R package installation on ARM
if [[ "$ARCH" == "arm64" ]]; then
    echo "Installing R packages (forcing x86_64 via Rosetta)..."
    arch -x86_64 Rscript install_packages.R
else
    echo "Installing R packages from install_packages.R..."
    Rscript install_packages.R
fi

echo ""
echo "========================================="
echo "Environment setup complete!"
echo "========================================="
echo ""
echo "To activate this environment, run:"
echo "  eval \"\$(micromamba shell hook --shell bash)\""
echo "  micromamba activate $ENV_DIR"
echo ""
echo "Or use the provided activation script:"
echo "  source activate_env.sh"
