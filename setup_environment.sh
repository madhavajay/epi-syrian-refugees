#!/bin/bash

set -e  # Exit on error

# Setup logging
LOG_FILE="setup_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Environment name and location
ENV_NAME="epigenetic-violence-analysis"
ENV_DIR="./envs/${ENV_NAME}"
SPEC_FILE="environment-spec.txt"
R_PACKAGES_MARKER="${ENV_DIR}/.r_packages_installed"

# Handle --clean flag
if [[ "$1" == "--clean" ]]; then
    echo "========================================="
    echo "CLEAN MODE: Removing all cached data"
    echo "========================================="
    echo ""
    echo "Removing environment directory: $ENV_DIR"
    rm -rf "$ENV_DIR"
    echo "Removing spec file: $SPEC_FILE"
    rm -f "$SPEC_FILE"
    echo ""
    echo "✓ Clean complete. Continuing with fresh setup..."
    echo ""
    # Don't exit - continue with setup
fi

echo "========================================="
echo "Setting up R environment for Epigenetic Violence Analysis"
echo "========================================="
echo "Logging to: $LOG_FILE"
echo ""

echo "Environment: $ENV_NAME"
echo "Location: $ENV_DIR"
echo ""

# Check if micromamba is installed
if ! command -v micromamba &> /dev/null; then
    echo "✗ micromamba not found"
    echo ""
    echo "Please install micromamba using one of these methods:"
    echo ""
    echo "1. Run the installation script (recommended):"
    echo "   ./install_micromamba.sh"
    echo ""
    echo "2. Install via Homebrew (macOS):"
    echo "   brew install micromamba"
    echo ""
    echo "3. Use official installer:"
    echo "   \"\${SHELL}\" <(curl -L https://micro.mamba.pm/install.sh)"
    echo ""
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

# Check if environment already exists
if [ -d "$ENV_DIR" ]; then
    echo "✓ Environment already exists: $ENV_DIR"
    echo "  To recreate: rm -rf $ENV_DIR && ./setup_environment.sh"
    echo ""
    # Skip creation, jump to package installation
else
    # Create from environment.yml (standard approach)
    if [ -f "environment.yml" ]; then
        echo "✓ Found environment.yml - creating environment..."
        echo ""
        CONDA_SUBDIR=osx-64 micromamba create -p "$ENV_DIR" -f environment.yml -y
        echo "✓ Environment created"
    else
        echo "ℹ No environment.yml found - will install packages manually"
        echo ""
    fi
fi

# Create environment from scratch if needed (when no spec file)
if [ ! -d "$ENV_DIR" ] && [ ! -f "$SPEC_FILE" ]; then
    echo "Creating micromamba environment (x86_64)..."
    echo "Optimization: strict channel priority, conda-forge + bioconda only"
    echo ""

    # Use strict channel priority to avoid backtracking
    # conda-forge + bioconda is the recommended combo for R + bioinformatics
    CONDA_SUBDIR=osx-64 micromamba create -p "$ENV_DIR" \
        -c conda-forge \
        -c bioconda \
        --strict-channel-priority \
        -y \
        r-base=4.4 \
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
        r-rebus \
        make \
        automake \
        autoconf \
        libtool \
        pkg-config \
        compilers \
        perl

    echo "✓ Base environment created (x86_64)"

    # Set conda subdir permanently for this environment
    if [[ "$ARCH" == "arm64" ]]; then
        # Create .condarc file in environment to force x86_64
        cat > "${ENV_DIR}/.condarc" <<EOF
subdir: osx-64
EOF
        echo "✓ Environment configured for x86_64 packages"
    fi

    # Save explicit spec for faster future rebuilds
    echo ""
    echo "Saving environment spec for faster rebuilds..."
    micromamba list -p "$ENV_DIR" --explicit > "$SPEC_FILE"
    echo "✓ Saved to $SPEC_FILE"
    echo "  Future runs will use this spec file (skips dependency solver)"
fi

# Always retry R package installation (remove marker to force check)
if [ -f "$R_PACKAGES_MARKER" ]; then
    echo "Removing R package marker to retry failed installations..."
    rm -f "$R_PACKAGES_MARKER"
fi

# Some heavy dependencies are more reliable from micromamba binaries than CRAN/Bioconductor
echo "Ensuring pre-built binaries for core compiled R dependencies..."
MICROMAMBA_PKGS=(r-nloptr r-igraph)

# bioconductor-gdsfmt currently ships Linux-only binaries; skip on macOS to avoid solver failures
if [[ "$(uname -s)" != "Darwin" ]]; then
    MICROMAMBA_PKGS+=(bioconductor-gdsfmt)
fi

if [[ "${#MICROMAMBA_PKGS[@]}" -gt 0 ]]; then
    if [[ "$ARCH" == "arm64" ]]; then
        CONDA_SUBDIR=osx-64 micromamba install -p "$ENV_DIR" -y "${MICROMAMBA_PKGS[@]}" || true
    else
        micromamba install -p "$ENV_DIR" -y "${MICROMAMBA_PKGS[@]}" || true
    fi
fi

echo ""
echo "========================================="
echo "Installing R packages"
echo "========================================="
echo ""

# Use direct path to Rscript instead of activation (more reliable in scripts)
RSCRIPT="${ENV_DIR}/bin/Rscript"

if [ ! -f "$RSCRIPT" ]; then
    echo "✗ Rscript not found at $RSCRIPT"
    echo "  Environment may not be properly created"
    exit 1
fi

# Ensure x86_64 for R package installation on ARM
if [[ "$ARCH" == "arm64" ]]; then
    echo "Installing R packages (forcing x86_64 via Rosetta)..."

    # Patch R's Makeconf to use absolute paths to compilers
    MAKECONF="${ENV_DIR}/lib/R/etc/Makeconf"
    ENV_DIR_ABS="$(cd "$(dirname "${ENV_DIR}")" && pwd)/$(basename "${ENV_DIR}")"

    if [ -f "${MAKECONF}" ]; then
        # Also fix any existing relative paths from previous runs
        sed -i.bak \
            -e "s|^CC = \./envs/.*bin/x86_64-apple-darwin13.4.0-clang|CC = ${ENV_DIR_ABS}/bin/x86_64-apple-darwin13.4.0-clang|" \
            -e "s|^CC = x86_64-apple-darwin13.4.0-clang|CC = ${ENV_DIR_ABS}/bin/x86_64-apple-darwin13.4.0-clang|" \
            -e "s|^CXX = \./envs/.*bin/x86_64-apple-darwin13.4.0-clang++|CXX = ${ENV_DIR_ABS}/bin/x86_64-apple-darwin13.4.0-clang++|" \
            -e "s|^CXX = x86_64-apple-darwin13.4.0-clang++|CXX = ${ENV_DIR_ABS}/bin/x86_64-apple-darwin13.4.0-clang++|" \
            -e "s|^CXX11 = \./envs/.*bin/x86_64-apple-darwin13.4.0-clang++|CXX11 = ${ENV_DIR_ABS}/bin/x86_64-apple-darwin13.4.0-clang++|" \
            -e "s|^CXX11 = x86_64-apple-darwin13.4.0-clang++|CXX11 = ${ENV_DIR_ABS}/bin/x86_64-apple-darwin13.4.0-clang++|" \
            -e "s|^CXX14 = \./envs/.*bin/x86_64-apple-darwin13.4.0-clang++|CXX14 = ${ENV_DIR_ABS}/bin/x86_64-apple-darwin13.4.0-clang++|" \
            -e "s|^CXX14 = x86_64-apple-darwin13.4.0-clang++|CXX14 = ${ENV_DIR_ABS}/bin/x86_64-apple-darwin13.4.0-clang++|" \
            -e "s|^CXX17 = \./envs/.*bin/x86_64-apple-darwin13.4.0-clang++|CXX17 = ${ENV_DIR_ABS}/bin/x86_64-apple-darwin13.4.0-clang++|" \
            -e "s|^CXX17 = x86_64-apple-darwin13.4.0-clang++|CXX17 = ${ENV_DIR_ABS}/bin/x86_64-apple-darwin13.4.0-clang++|" \
            -e "s|^CXX20 = \./envs/.*bin/x86_64-apple-darwin13.4.0-clang++|CXX20 = ${ENV_DIR_ABS}/bin/x86_64-apple-darwin13.4.0-clang++|" \
            -e "s|^CXX20 = x86_64-apple-darwin13.4.0-clang++|CXX20 = ${ENV_DIR_ABS}/bin/x86_64-apple-darwin13.4.0-clang++|" \
            -e "s|^FC = \./envs/.*bin/x86_64-apple-darwin13.4.0-gfortran|FC = ${ENV_DIR_ABS}/bin/x86_64-apple-darwin13.4.0-gfortran|" \
            -e "s|^FC = x86_64-apple-darwin13.4.0-gfortran|FC = ${ENV_DIR_ABS}/bin/x86_64-apple-darwin13.4.0-gfortran|" \
            "${MAKECONF}"

        # Remove '-pipe' from Fortran compilation flags to avoid Rosetta issues
        perl -0pi -e 's/ -pipe/ /g' "${MAKECONF}"

        echo "✓ Patched R Makeconf with absolute compiler paths: ${ENV_DIR_ABS}/bin"
        echo "✓ Removed problematic -pipe flag from Fortran toolchain"
    fi

    # Use workspace-local temp dir so seatbelt doesn't block linking (e.g. nlopt build)
    export TMPDIR="${ENV_DIR}/tmp"
    mkdir -p "${TMPDIR}"

    # Force x86_64 for R
    arch -x86_64 /bin/bash -c "'$RSCRIPT' install_packages.R"
else
    echo "Installing R packages from install_packages.R..."
    "$RSCRIPT" install_packages.R
fi

# Create marker file on successful installation
touch "$R_PACKAGES_MARKER"
echo "✓ R packages installation complete - created marker file"

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
echo ""
echo "Performance tips:"
echo "  - First run is slow (dependency solving + package downloads)"
echo "  - Subsequent rebuilds use $SPEC_FILE (much faster)"
echo "  - Keep micromamba updated: micromamba self-update"
