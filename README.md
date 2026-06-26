# fresh-macos-install

Automated macOS setup script for fresh installs. One command installs all apps, configures system settings, symlinks dotfiles, and sets up the shell.

Supports two modes: `personal` and `work`, sharing a common base with mode-specific overrides.

## Usage

```bash
# Clone the repo
git clone https://github.com/imZeo/fresh-macos-install.git ~/Developer/personal/fresh-macos-install
cd ~/Developer/personal/fresh-macos-install
chmod +x macos-setup.sh

# Run for personal machine
./macos-setup.sh personal

# Run for work machine
./macos-setup.sh work
```

The script will prompt for your sudo password once and keep it alive for the duration.
All output is logged to `~/.setup.log`.

## What it does

### System
- Installs Xcode CLI tools (skips if already present)
- Installs Homebrew (unattended, Apple Silicon aware)
- Detects architecture (ARM/Intel) and warns accordingly

### Packages
Installs via `brew bundle` from three Brewfiles:
- `Brewfile` — shared across both modes
- `Brewfile.personal` — personal-only additions
- `Brewfile.work` — work-only additions (AWS, k8s, Terraform, etc.)

### Shell & Dotfiles
- Installs oh-my-zsh (skips if present)
- Symlinks `dotfiles/.zshrc` → `~/.zshrc` (backs up existing)
- Symlinks `dotfiles/nvim/` → `~/.config/nvim/` (init.lua, lua plugins, lazy-lock)

### Git
Sets global config: name, email, default branch (`main`), auto remote setup.

### macOS Defaults
- **Finder**: show hidden files, extensions, path/status bar, list view (+ purges cached per-folder `.DS_Store` view state so list view actually applies everywhere), full path in title, no .DS_Store on network/USB, sidebar icon size medium
- **Dock**: auto-hide (instant), scale minimize effect, no launch animation, app switcher on all displays, smallest icon size
- **Trackpad**: tap-to-click (built-in + Bluetooth), trackpad scaling, secondary click in bottom-right corner, three-finger drag, three-finger swipe between pages, three-finger tap for Look Up/data detectors
- **Keyboard**: fast key repeat, full keyboard access, press-and-hold disabled (enables proper repeat), autocorrect/autocap/smart punctuation all off, F1/F2/etc. as standard function keys
- **Input Sources**: Hungarian and Danish keyboard layouts added (alongside default ABC layout)
- **Screenshots**: saved to `~/Documents/Screenshots`, PNG, no drop shadow
- **UI**: faster window resize/save/print animations
- **Security**: screensaver password on wake immediately
- **Spotlight**: Cmd+Space unbound so Raycast can claim it

### Security & System
- **TouchID for sudo**: enabled via `/etc/pam.d/sudo_local` (survives macOS updates on Ventura+)
- **Firewall**: software update auto-check, download, and critical security patches enabled
- **Power management**: display sleep 30min (plugged), 10min (battery); system sleep never (plugged), 30min (battery)
- **Hosts file**: backs up `/etc/hosts` to `/etc/hosts.bak`, then replaces it with the [someonewhocares.org](https://someonewhocares.org/hosts/) ad/tracker-blocking hosts file

### Directories
Scaffolds `~/Developer/personal` and `~/Developer/work`.

## Keeping Brewfiles up to date

After installing new tools, capture current state:

```bash
brew bundle dump --file=Brewfile.dump --force
```

Review the dump and move new entries into the appropriate Brewfile (`Brewfile`, `Brewfile.personal`, or `Brewfile.work`), then delete the dump.

## Dotfiles

```
dotfiles/
  .zshrc              # zsh config (oh-my-zsh, aliases, PATH)
  nvim/
    init.lua          # neovim entry point
    lazy-lock.json    # plugin lockfile
    lua/
      config/lazy.lua # lazy.nvim bootstrap
      plugins/        # plugin configs (telescope, copilot, tokyonight, treesitter, statuscol)
    .gitignore        # excludes pack/ (binary plugin files)
```

## Manual steps (not automatable)

- **Displays**: scaled resolution for more space
- **Raycast**: assign Cmd+Space in Raycast preferences (Spotlight hotkey is unbound by the script)
- **espanso**: clone private config repo
- **ghostty**: config TBD
- **Browser extensions**: see below

## Browser extensions

Chrome and Arc extensions to install manually (no reliable unattended-install mechanism for either, especially Arc):

- _TODO: fill in extension names/URLs_

## File structure

```
macos-setup.sh      # main setup script
Brewfile            # shared packages + apps
Brewfile.personal   # personal-only
Brewfile.work       # work-only
dotfiles/           # symlinked to ~ on setup
.gitignore          # ignores .claude/
```