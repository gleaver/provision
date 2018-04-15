# Provisioning

## Bootstrap
Run appropriate bootstrap method, then create a static address, and add to invventory.

### Bootstrap a local machine:
Run as root after OS install. Installs some core packages, and sets up basic GUI/networking.
```sh
cd bootstrap/desktop
./bootstrap.sh --user <user>
```

### Bootstrap a headless machine (an rpi):
Run as root from host machine. Formats and creates a filesystem for a raspberry pi containing a unique set of SSH keys, wireless credentials, and a bootstrap script. When the script is run on the local machine, it results in a network connected device with no default accounts and SSH access with passwordless sudo, ready for normal provisioning.
```sh
cd bootstrap/headless
./mkbootstrap.sh --user <user> \
               --device /dev/mmcblk0 \
               --host <hostname> \
               --config <rpizero|rpi3> \
               --secrets <path to pass repo>
```
On actual machine:
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

