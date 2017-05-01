# Provisioning

## Bootstrap
Run as root after OS install. Installs some core packages, and sets up basic GUI/networking.

Usage:
```sh
./bootstrap.sh
```

## TODO
- SSH/GPG keys for user
- tarsnap/backup
- vim/zsh
- dev environment
- pass
- keyboard mapping
- post install arch configuration
- dell xps13 configuration
- (maybe) automate arch installation itself
- hardening
- tmux, ag, tree, lolcat, vi -> vim , git config, completions

# Manual steps
- Loaded SSH and GPG keys from darkroom using scripts
- Added UK as an input source in gnome to fix keyboard layout in GUI
- Installed tweak tool, and set caps/esc swap that way
