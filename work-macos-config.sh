#!/usr/bin/env bash

# Setup script for setting up a new macos machine
echo "Starting work setup"

# install xcode CLI
xcode-select --install

# Check for Homebrew to be present, install if it's missing
if test ! $(which brew); then
    echo "Installing homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

#
#echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/zeo-pleo/.zprofile
#eval "$(/opt/homebrew/bin/brew shellenv)"

# Update homebrew recipes
brew update

PACKAGES=(
    git
    htop
    speedtest-cli
    tree
    task
)

echo "Installing packages..."
brew install ${PACKAGES[@]}

echo "Cleaning up..."
brew cleanup

echo "Installing cask..."
CASKS=(
    atom
    iterm2
    spotify
    visual-studio-code
    rectangle
    caffeine
    todoist
    brave-browser
    firefox
    arc
    alfred
    discord
    forklift
    nvidia-geforce-now
    linear
    espanso
    gh
    raycast
    bartender
)
echo "Installing cask apps..."
brew install --cask ${CASKS[@]}


###############################################################################
# General tuning                                                              #
###############################################################################

echo "Configuring OS..."

# Show the ~/Library folder
chflags nohidden ~/Library

# Store screenshots in Documents/Screenshots instead
mkdir ~/Documents/Screenshots
defaults write com.apple.screencapture location ~/Documents/Screenshots
# Save screenshots in PNG format (other options: BMP, GIF, JPG, PDF, TIFF)
defaults write com.apple.screencapture type -string "png"

# Make the Dock appear in an instant, no delay
defaults write com.apple.dock autohide-delay -float 0; defaults delete com.apple.dock autohide-time-modifier; killall Dock

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true


# Show filename extensions by default
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show app switcher on all displays
defaults write com.apple.Dock appswitcher-all-displays -bool true; killall Dock

# Enable tap-to-click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1


###############################################################################
# TODO                                                                        #
###############################################################################

# accessibility ->      enable dragging without drag lock
# dock & menu bar ->    hide dock by default
# keyboard ->           enable to move focus between controls
# trackpad ->           swipe between pages -> swipe with 3 fingers
# trackpad ->           set up right-click to bottom right  
# displays ->           Scaled for more space

# git clone espanso config BUT its a private repo

# A quick restart so everything goes to plan.
killall Finder
killall Dock


# We are done now.
echo "Macbook setup completed!"

# Thanks to:
# https://medium.com/macoclock/automating-your-macos-setup-with-homebrew-and-cask-e2a103b51af1
# https://github.com/kevinpapst/mac-os-setup/blob/master/settings/macos.sh
# https://github.com/andersfischernielsen for the inspiration :fish:
