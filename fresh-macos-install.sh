#!/usr/bin/env bash

# Setup script for setting up a new macos machine
echo "Starting setup"

# install xcode CLI
xcode-select —-install

# Check for Homebrew to be present, install if it's missing
if test ! $(which brew); then
    echo "Installing homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

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
    macdown
    rectangle
    caffeine
    todoist
    brave-browser
    firefox
    alfred
)
echo "Installing cask apps..."
brew install --cask ${CASKS[@]}


###############################################################################
# General tuning                                                              #
###############################################################################

echo "Configuring OS..."

# Show the ~/Library folder
chflags nohidden ~/Library

# Store screenshots directly on desktop
mkdir ~/Desktop/Screenshots
defaults write com.apple.screencapture location ~/Desktop/Screenshots
# Save screenshots in PNG format (other options: BMP, GIF, JPG, PDF, TIFF)
defaults write com.apple.screencapture type -string "png"

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true


# Set fast key repeat rate
defaults write NSGlobalDomain KeyRepeat -int 0
# Show filename extensions by default
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Enable tap-to-click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# A quick restart so everything goes to plan.
killall Finder
killall Dock

# We are done now.
echo "Macbook setup completed!"

# Thanks to:
# https://medium.com/macoclock/automating-your-macos-setup-with-homebrew-and-cask-e2a103b51af1
# https://github.com/kevinpapst/mac-os-setup/blob/master/settings/macos.sh
#
