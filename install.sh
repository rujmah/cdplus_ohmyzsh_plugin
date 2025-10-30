#!/usr/bin/env bash
# Installation script for cdplus oh-my-zsh plugin

set -e

PLUGIN_NAME="cdplus"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
PLUGIN_DIR="$ZSH_CUSTOM/plugins/$PLUGIN_NAME"

echo "📦 Installing $PLUGIN_NAME plugin..."

# Check if oh-my-zsh is installed
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    echo "❌ Oh-My-Zsh not found. Please install it first:"
    echo "   sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
    exit 1
fi

# Create custom plugins directory if it doesn't exist
mkdir -p "$ZSH_CUSTOM/plugins"

# Clone or update the plugin
if [[ -d "$PLUGIN_DIR" ]]; then
    echo "📂 Plugin directory exists. Updating..."
    cd "$PLUGIN_DIR"
    git pull origin main || git pull origin master
else
    echo "📥 Cloning plugin..."
    git clone https://github.com/yourusername/cdplus.git "$PLUGIN_DIR"
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Add '$PLUGIN_NAME' to your plugins array in ~/.zshrc:"
echo "      plugins=(... $PLUGIN_NAME)"
echo ""
echo "   2. (Optional) Configure in ~/.zshrc BEFORE oh-my-zsh loads:"
echo "      export CDPLUS_TIMEOUT=5"
echo "      export CDPLUS_MAX_DEPTH=3"
echo "      export CDPLUS_SHOW_SPINNER=1"
echo ""
echo "   3. Reload your shell:"
echo "      source ~/.zshrc"
echo ""
echo "📖 For more options, see: $PLUGIN_DIR/README.md"
