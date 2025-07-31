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

## Customization

- Edit config files in this repo and re-run `stow` to update symlinks.
- Review each config’s documentation for further customization.

## Tips

- Only stow what you need. You can manage each set of configs independently.
- If you already have existing configs, back them up before running stow as it may overwrite them.

## Troubleshooting

- If stow fails due to conflicts, check for existing files or symlinks in your home directory.
- You can use the `-t` flag to specify a target directory, e.g. `stow -t ~ nvim`.
