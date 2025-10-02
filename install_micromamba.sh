#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Micromamba Installation Script"
echo "========================================="
echo ""

# Check if micromamba is already installed
if command -v micromamba &> /dev/null; then
    echo "✓ micromamba is already installed"
    echo "  Location: $(which micromamba)"
    echo "  Version: $(micromamba --version)"
    echo ""
    echo "To update micromamba to the latest version:"
    echo "  micromamba self-update"
    exit 0
fi

echo "Installing micromamba..."
echo ""

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

echo "Detected system:"
echo "  OS: $OS"
echo "  Architecture: $ARCH"
echo ""

# Determine installation method based on OS
case "$OS" in
    Linux*)
        echo "Installing micromamba for Linux..."
        # Official installation script
        "${SHELL}" <(curl -L https://micro.mamba.pm/install.sh)
        ;;
    Darwin*)
        echo "Installing micromamba for macOS..."

        # Check if Homebrew is available
        if command -v brew &> /dev/null; then
            echo "✓ Homebrew detected - using brew install"
            echo ""
            brew install micromamba
        else
            echo "⚠ Homebrew not found - using official installer"
            echo ""
            # Official installation script
            "${SHELL}" <(curl -L https://micro.mamba.pm/install.sh)
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*)
        echo "Installing micromamba for Windows..."
        echo ""
        echo "For Windows, please use one of these methods:"
        echo ""
        echo "1. PowerShell (recommended):"
        echo "   Invoke-Expression ((Invoke-WebRequest -Uri https://micro.mamba.pm/install.ps1).Content)"
        echo ""
        echo "2. Manual download:"
        echo "   https://github.com/mamba-org/micromamba-releases/releases"
        echo ""
        echo "3. Chocolatey:"
        echo "   choco install micromamba"
        echo ""
        echo "4. Scoop:"
        echo "   scoop install micromamba"
        exit 1
        ;;
    *)
        echo "✗ Unsupported operating system: $OS"
        echo ""
        echo "Please install micromamba manually from:"
        echo "  https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html"
        exit 1
        ;;
esac

echo ""
echo "========================================="
echo "Verifying Installation"
echo "========================================="
echo ""

# Source shell configuration to pick up new PATH
if [ -f "$HOME/.bashrc" ]; then
    echo "Sourcing ~/.bashrc..."
    source "$HOME/.bashrc"
elif [ -f "$HOME/.zshrc" ]; then
    echo "Sourcing ~/.zshrc..."
    source "$HOME/.zshrc"
fi

# Check if installation was successful
if command -v micromamba &> /dev/null; then
    echo "✓ micromamba installation successful!"
    echo "  Location: $(which micromamba)"
    echo "  Version: $(micromamba --version)"
    echo ""
    echo "========================================="
    echo "Shell Configuration"
    echo "========================================="
    echo ""
    echo "To use micromamba, you need to initialize your shell."
    echo ""
    echo "Add this to your shell configuration file:"
    echo ""

    # Detect shell
    CURRENT_SHELL=$(basename "$SHELL")
    case "$CURRENT_SHELL" in
        bash)
            CONFIG_FILE="~/.bashrc"
            ;;
        zsh)
            CONFIG_FILE="~/.zshrc"
            ;;
        *)
            CONFIG_FILE="~/.${CURRENT_SHELL}rc"
            ;;
    esac

    echo "For $CURRENT_SHELL (add to $CONFIG_FILE):"
    echo "  eval \"\$(micromamba shell hook --shell $CURRENT_SHELL)\""
    echo ""
    echo "Or run this command to add it automatically:"
    echo "  micromamba shell init --shell $CURRENT_SHELL --root-prefix=~/micromamba"
    echo ""
    echo "After adding, restart your shell or run:"
    echo "  source $CONFIG_FILE"
    echo ""
    echo "========================================="
    echo "Next Steps"
    echo "========================================="
    echo ""
    echo "1. Initialize your shell (see above)"
    echo "2. Restart your terminal or source your config file"
    echo "3. Run the environment setup:"
    echo "   ./setup_environment.sh"
    echo ""
else
    echo "✗ Installation verification failed"
    echo ""
    echo "Please try installing manually:"
    echo "  https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html"
    echo ""
    exit 1
fi

echo "========================================="
echo "Installation Complete!"
echo "========================================="
