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

step() { printf '\n==> %s\n' "$1"; }

ensure_line() {
    local line="$1" file="$2"
    touch "$file"
    grep -Fqx "$line" "$file" 2>/dev/null || printf '%s\n' "$line" >> "$file"
}

ensure_symlink() {
    local source="$1" target="$2" backup
    if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
        echo "Already linked: $target"
        return
    fi
    if [[ -e "$target" && ! -L "$target" ]]; then
        backup="$target.bak"
        [[ -e "$backup" ]] && backup="$target.bak.$(date +%Y%m%d%H%M%S)"
        mv "$target" "$backup"
        echo "Backed up: $target -> $backup"
    fi
    ln -sfn "$source" "$target"
    echo "Linked: $target -> $source"
}

# Resolve the logged-in console user (safe under sudo)
LOGGED_IN_USER=$(ls -l /dev/console | awk '{print $3}')
USER_HOME="/Users/$LOGGED_IN_USER"

# Log everything
LOG_FILE="$USER_HOME/.setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== Setup started at $(date) ==="

# Architecture check
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    echo "Apple Silicon (ARM) detected."
elif [[ "$ARCH" == "x86_64" ]]; then
    echo "Intel Mac detected."
else
    echo "Unknown architecture: $ARCH" >&2; exit 1
fi

# Cache sudo credentials and keep alive for duration of script
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_PID=$!
HOSTS_DOWNLOAD=""
cleanup() {
    kill "$SUDO_PID" 2>/dev/null || true
    [[ -z "$HOSTS_DOWNLOAD" ]] || rm -f "$HOSTS_DOWNLOAD"
    echo "=== Setup finished at $(date) ===" >> "$LOG_FILE"
}
trap cleanup EXIT

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
    ensure_line 'eval "$(/opt/homebrew/bin/brew shellenv)"' "$USER_HOME/.zprofile"
fi

###############################################################################
# Install packages via Brewfiles
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ensure_brew_bundle() {
    local label="$1" brewfile="$2" status
    if brew bundle check --file="$brewfile" &>/dev/null; then
        echo "$label packages already installed."
    else
        echo "Installing missing $label packages..."
        if brew bundle install --no-upgrade --file="$brewfile"; then
            echo "$label packages installed successfully."
        else
            status=$?
            echo ""
            echo "⚠️  Homebrew failed while installing $label packages (exit $status)."
            echo "Unmet dependencies in $brewfile:"
            brew bundle check --verbose --file="$brewfile" 2>&1 || true
            echo "Retry with: brew bundle install --no-upgrade --file=\"$brewfile\""
            echo "Full output is in: $LOG_FILE"
        fi
    fi
}

ensure_brew_bundle shared "$SCRIPT_DIR/Brewfile"
ensure_brew_bundle "$MODE" "$SCRIPT_DIR/Brewfile.$MODE"

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
ensure_symlink "$SCRIPT_DIR/dotfiles/.zshrc" "$USER_HOME/.zshrc"

# nvim
mkdir -p $USER_HOME/.config/nvim/lua
ensure_symlink "$SCRIPT_DIR/dotfiles/nvim/init.lua" "$USER_HOME/.config/nvim/init.lua"
ensure_symlink "$SCRIPT_DIR/dotfiles/nvim/lazy-lock.json" "$USER_HOME/.config/nvim/lazy-lock.json"
ensure_symlink "$SCRIPT_DIR/dotfiles/nvim/lua/config" "$USER_HOME/.config/nvim/lua/config"
ensure_symlink "$SCRIPT_DIR/dotfiles/nvim/lua/plugins" "$USER_HOME/.config/nvim/lua/plugins"

###############################################################################
# Dev Directories
###############################################################################

mkdir -p $USER_HOME/Developer/personal $USER_HOME/Developer/work

###############################################################################
# macOS Defaults
###############################################################################

step "Configuring macOS"

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
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Reset Finder state only at common folder roots. A recursive scan of $HOME can
# block for a long time in Library, CloudStorage, and large development trees.
for folder in "$USER_HOME" "$USER_HOME/Desktop" "$USER_HOME/Documents" "$USER_HOME/Downloads"; do
    [[ -d "$folder" ]] && rm -f "$folder/.DS_Store"
done

# No .DS_Store on network/USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# --- Screenshots ---
mkdir -p $USER_HOME/Documents/Screenshots
defaults write com.apple.screencapture location $USER_HOME/Documents/Screenshots
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# --- Dock ---
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults delete com.apple.dock autohide-time-modifier 2>/dev/null || true
defaults write com.apple.dock expose-animation-duration -float 0.1
defaults write com.apple.Dock appswitcher-all-displays -bool true
defaults write com.apple.dock mineffect -string "scale"
defaults write com.apple.dock launchanim -bool false
defaults write com.apple.dock tilesize -int 16  # smallest size available via the UI slider

# --- Finder Appearance ---
defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 2  # sidebar icon size: medium

# --- Trackpad ---
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true  # Bluetooth
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true                    # Built-in
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 2.5

# Secondary click -> bottom right corner
defaults write com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 2
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults -currentHost write NSGlobalDomain com.apple.trackpad.trackpadCornerClickBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true

# Use trackpad for dragging (three-finger drag; mutually exclusive with Dragging/DragLock)
defaults write com.apple.AppleMultitouchTrackpad Dragging -bool false
defaults write com.apple.AppleMultitouchTrackpad DragLock -bool false
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Dragging -bool false
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad DragLock -bool false
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true

# Swipe between pages -> three fingers
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture -int 1
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture -int 1

# Look up & data detectors -> three-finger tap
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerTapGesture -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerTapGesture -int 2

# --- Keyboard ---
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true  # F1, F2, etc. as standard function keys

# --- Input Sources ---
if ! defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null | grep -q '"KeyboardLayout ID" = 30763;'; then
    defaults write com.apple.HIToolbox AppleEnabledInputSources -array-add '{InputSourceKind = "Keyboard Layout"; "KeyboardLayout ID" = 30763; "KeyboardLayout Name" = Hungarian;}'
    echo "Added Hungarian input source."
fi
if ! defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null | grep -q '"KeyboardLayout ID" = 9;'; then
    defaults write com.apple.HIToolbox AppleEnabledInputSources -array-add '{InputSourceKind = "Keyboard Layout"; "KeyboardLayout ID" = 9; "KeyboardLayout Name" = Danish;}'
    echo "Added Danish input source."
fi

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
# TouchID for sudo
# Uses sudo_local (Ventura+) — survives macOS updates
# Falls back to editing /etc/pam.d/sudo directly on older systems
###############################################################################

if [[ -f /etc/pam.d/sudo_local.template ]]; then
    if ! grep -q 'pam_tid.so' /etc/pam.d/sudo_local 2>/dev/null; then
        sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local
        sudo sed -i '' 's/#auth/auth/' /etc/pam.d/sudo_local
        echo "TouchID for sudo enabled via sudo_local (survives OS updates)."
    else
        echo "TouchID for sudo already configured."
    fi
elif ! grep -q 'pam_tid.so' /etc/pam.d/sudo 2>/dev/null; then
    sudo sed -i '' '2s/^/auth       sufficient     pam_tid.so\n/' /etc/pam.d/sudo
    echo "TouchID for sudo enabled via /etc/pam.d/sudo."
fi

###############################################################################
# Software Updates
###############################################################################

sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool true
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool true

###############################################################################
# Power Management
###############################################################################

sudo pmset -c displaysleep 30   # plugged in: display sleep after 30 min
sudo pmset -c sleep 0           # plugged in: never sleep
sudo pmset -b displaysleep 10   # battery: display sleep after 10 min
sudo pmset -b sleep 30          # battery: sleep after 30 min

###############################################################################
# Hosts File (ad/tracker blocking via someonewhocares.org)
###############################################################################

step "Updating /etc/hosts"
HOSTS_DOWNLOAD=$(mktemp)
if curl -fsSL https://someonewhocares.org/hosts/hosts -o "$HOSTS_DOWNLOAD"; then
    if cmp -s "$HOSTS_DOWNLOAD" /etc/hosts; then
        echo "/etc/hosts is already current."
    else
        [[ -f /etc/hosts.bak ]] || sudo cp /etc/hosts /etc/hosts.bak
        sudo install -m 644 "$HOSTS_DOWNLOAD" /etc/hosts
        sudo dscacheutil -flushcache
        echo "/etc/hosts updated."
    fi
else
    echo "⚠️  Could not download the hosts list; keeping the existing /etc/hosts."
fi
rm -f "$HOSTS_DOWNLOAD"
HOSTS_DOWNLOAD=""

###############################################################################
# Restart affected services
###############################################################################

killall Finder 2>/dev/null || true
killall Dock 2>/dev/null || true

echo "$MODE setup complete!"

###############################################################################
# Manual TODO (not automatable via defaults)
# - Keyboard: enable focus movement between controls (covered by AppleKeyboardUIMode above)
# - Displays: scaled for more space
# - espanso: clone private config repo
# - ghostty: config TBD
# - Browser extensions: see README "Browser extensions" section
###############################################################################
