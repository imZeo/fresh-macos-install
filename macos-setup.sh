#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Usage: ./macos-setup.sh [personal|work]
###############################################################################

MODE="${1:-}"
if [[ "$MODE" != "personal" && "$MODE" != "work" ]]; then
    echo "Usage: $0 [personal|work]"
    exit 1
fi

# Resolve the logged-in console user (safe under sudo)
LOGGED_IN_USER=$(ls -l /dev/console | awk '{print $3}')
USER_HOME="/Users/$LOGGED_IN_USER"

echo "Starting $MODE setup for $LOGGED_IN_USER..."

###############################################################################
# Xcode CLI Tools
###############################################################################

if ! xcode-select -p &>/dev/null; then
    echo "Installing Xcode CLI tools..."
    xcode-select --install
    echo "Waiting for Xcode CLI tools..."
    until xcode-select -p &>/dev/null; do sleep 5; done
fi

###############################################################################
# Homebrew
###############################################################################

if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Apple Silicon: set up brew env
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    if ! grep -q 'brew shellenv' $USER_HOME/.zprofile 2>/dev/null; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $USER_HOME/.zprofile
    fi
fi

brew update

###############################################################################
# Install packages via Brewfiles
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing shared packages..."
brew bundle install --file="$SCRIPT_DIR/Brewfile"

echo "Installing $MODE packages..."
brew bundle install --file="$SCRIPT_DIR/Brewfile.$MODE"

brew cleanup

###############################################################################
# Git Config
###############################################################################

git config --global user.name "imZeo"
git config --global user.email "ZMCsoltai@gmail.com"
git config --global init.defaultbranch main
git config --global push.autosetupremote true

###############################################################################
# Oh My Zsh
###############################################################################

if [[ ! -d "$USER_HOME/.oh-my-zsh" ]]; then
    echo "Installing Oh My Zsh..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

###############################################################################
# Dotfiles
###############################################################################

# .zshrc
[[ -f $USER_HOME/.zshrc && ! -L $USER_HOME/.zshrc ]] && cp $USER_HOME/.zshrc $USER_HOME/.zshrc.bak
ln -sf "$SCRIPT_DIR/dotfiles/.zshrc" $USER_HOME/.zshrc

# nvim
mkdir -p $USER_HOME/.config/nvim/lua
ln -sf "$SCRIPT_DIR/dotfiles/nvim/init.lua" $USER_HOME/.config/nvim/init.lua
ln -sf "$SCRIPT_DIR/dotfiles/nvim/lazy-lock.json" $USER_HOME/.config/nvim/lazy-lock.json
ln -sf "$SCRIPT_DIR/dotfiles/nvim/lua/config" $USER_HOME/.config/nvim/lua/config
ln -sf "$SCRIPT_DIR/dotfiles/nvim/lua/plugins" $USER_HOME/.config/nvim/lua/plugins

###############################################################################
# Dev Directories
###############################################################################

mkdir -p $USER_HOME/Developer/personal $USER_HOME/Developer/work

###############################################################################
# macOS Defaults
###############################################################################

echo "Configuring macOS..."

# --- Finder ---
chflags nohidden $USER_HOME/Library
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# No .DS_Store on network/USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# --- Screenshots ---
mkdir -p $USER_HOME/Documents/Screenshots
defaults write com.apple.screencapture location $USER_HOME/Documents/Screenshots
defaults write com.apple.screencapture type -string "png"

# --- Dock ---
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults delete com.apple.dock autohide-time-modifier 2>/dev/null || true
defaults write com.apple.dock expose-animation-duration -float 0.1
defaults write com.apple.Dock appswitcher-all-displays -bool true

# --- Trackpad ---
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# --- Keyboard ---
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Disable autocorrect annoyances
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# --- UI Speed ---
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true

# --- Raycast: disable Spotlight Cmd+Space so Raycast can claim it ---
/usr/libexec/PlistBuddy -c "Set :AppleSymbolicHotKeys:64:enabled false" \
    $USER_HOME/Library/Preferences/com.apple.symbolichotkeys.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :AppleSymbolicHotKeys:65:enabled false" \
    $USER_HOME/Library/Preferences/com.apple.symbolichotkeys.plist 2>/dev/null || true

# --- Security ---
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

###############################################################################
# Restart affected services
###############################################################################

killall Finder
killall Dock

echo "$MODE setup complete!"

###############################################################################
# Manual TODO (not automatable via defaults)
# - Accessibility: enable dragging without drag lock
# - Keyboard: enable focus movement between controls (covered by AppleKeyboardUIMode above)
# - Trackpad: swipe between pages → 3 fingers
# - Trackpad: right-click → bottom right corner
# - Displays: scaled for more space
# - espanso: clone private config repo
###############################################################################
