#!/usr/bin/env bash

set -eo pipefail

fail() {
  echo "$1" >&2 && exit 1
}

install_packages() {
  echo "Install packages..."
  pacman -Syu --noconfirm sudo git vim python openssh
}

configure_sudo() {
  echo "Configure sudo..."
  sed -i.bak 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
  visudo -cf /etc/sudoers
}

create_user() {
  echo "Creating user..."
  useradd -m -G wheel,audio,video,rfkill,uucp,sys "${user}"
  echo "Setting user password:"
  passwd "${user}"
}

setup_ui() {
  echo "Setup UI..."
  pacman -S --noconfirm gnome
  systemctl enable NetworkManager
  systemctl restart NetworkManager
}

parse_args() {
  while [[ $# -gt 0 ]];
  do
    case $1 in
      --user|-u)  shift; user=$1; shift ;;
      *) fail "Unknown option: $1" ;;
    esac
  done
}

main() {
  parse_args "$@"

  [[ "$(id -u)" == 0 ]] || fail "y u no root?"
  [[ -n ${user} ]] || fail "No user specified"

  cd "$(dirname "${BASH_SOURCE[0]}")"

  install_packages
  configure_sudo
  create_user
  setup_ui
  
  echo "Done"
}

main "$@"
