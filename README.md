# Dotfiles managed with GNU Stow

This repository contains my personal dotfiles for Linux, managed with [GNU Stow](https://www.gnu.org/software/stow/). Each directory corresponds to a category of configuration and is organized to make symlink management simple and reproducible.

## Structure

- `hypr/` — [Hyprland](https://hyprland.org/) window manager configuration (`.config/hypr/hyprland.conf`)
- `nvim/` — Neovim configuration (`.config/nvim/`)
- `tmux/` — Tmux configuration (`.tmux.conf`)

Other files may be present for miscellaneous setup (e.g., `set-audiodg-affinity.bat` for Windows).

## Prerequisites

- [GNU Stow](https://www.gnu.org/software/stow/) — install via your package manager:
  - Debian/Ubuntu: `sudo apt install stow`
  - Arch: `sudo pacman -S stow`
  - macOS: `brew install stow`

## Usage

Clone this repository into your home directory (or wherever you prefer to manage dotfiles):

```sh
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

To symlink a specific application’s config, run:

```sh
stow -t ~ <folder>
```

For example:

```sh
stow -t ~ hypr
stow -t ~ nvim
stow -t ~ tmux
```

This will create symlinks in your `$HOME` so that `~/.config/hypr`, `~/.config/nvim`, and `~/.tmux.conf` point to the files in this repo.

### Unstowing

To remove symlinks created by stow:

```sh
stow -t ~ -D <folder>
```

Example:

```sh
stow -t ~ -D tmux
```

## OpenCode Plugins

The `opencode/` stow package includes OpenCode configuration and plugins. Plugins require a build step before stowing because only the compiled output should be symlinked -- not the full plugin source.

Plugin source code lives in `_plugins/` as git submodules, outside the stow tree. A build script handles compiling and copying the built `.js` file into the stow package's plugins directory. OpenCode auto-loads `.js` files from `~/.config/opencode/plugins/` at startup.

### Setup

```sh
# Initialize submodules (first time or after clone)
git submodule update --init --recursive

# Build plugins and copy dist files into the stow tree
./build-plugins.sh

# Stow the opencode config (including built plugin dist files)
stow -t ~ opencode
```

### Updating a Plugin

```sh
# Pull latest changes for the plugin submodule
git -C _plugins/opencode-meridian pull

# Rebuild and copy dist files
./build-plugins.sh

# Re-stow if needed
stow -t ~ -R opencode
```

### How It Works

1. `_plugins/opencode-meridian/` -- git submodule with the full plugin source
2. `./build-plugins.sh` -- runs `bun install` + `bun run build` in the submodule, then copies `dist/index.js` to `opencode/.config/opencode/plugins/opencode-meridian.js`
3. `stow -t ~ opencode` -- symlinks `opencode-meridian.js` into `~/.config/opencode/plugins/`, where OpenCode auto-loads it

The copied `.js` files are gitignored since they are build artifacts.

## Customization

- Edit config files in this repo and re-run `stow` to update symlinks.
- Review each config’s documentation for further customization.

## Tips

- Only stow what you need. You can manage each set of configs independently.
- If you already have existing configs, back them up before running stow as it may overwrite them.

## Troubleshooting

- If stow fails due to conflicts, check for existing files or symlinks in your home directory.
- You can use the `-t` flag to specify a target directory, e.g. `stow -t ~ nvim`.
