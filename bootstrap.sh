#!/usr/bin/env bash
#
# Bootstrap an installation to have:
# - IP address
# - SSH server with known keys
# - 'guy' user with SSH keys and sudo access
# - no default credentials
# - python and ansible installed
#
# Template credentials should be provided using mkbootstrap

set -ex

# params
user=guy
default_user=alarm
interface=wlan0

# bootstrap files
ssh_authorized_keys=authorized_keys
wpa_key=wpa_supplicant.conf

# system files
wpa_conf="/etc/wpa_supplicant/wpa_supplicant-${interface}.conf"
network_file="/etc/systemd/network/${interface}.network"
unit_file="/usr/lib/systemd/system/wpa_supplicant@.service"
unit_file_link="/etc/systemd/system/multi-user.target.wants/wpa_supplicant@${interface}.service"
ssh_dir=/etc/ssh
user_ssh_dir="/home/${user}/.ssh"
user_authorized_keys="${user_ssh_dir}/authorized_keys"

fail() {
  echo "$1" >&2 && exit 1
}

check_permissions() {
  [[ "$(id -u)" == 0 ]] || fail "Must be root"
}

check_files() {
  for ktype in rsa dsa ecdsa ed25519; do
    [[ -e "ssh_host_${ktype}_key" ]] || fail "Missing ${ktype} private key"
    [[ -e "ssh_host_${ktype}_key.pub" ]] || fail "Missing ${ktype} public key"
  done
  [[ -e ${ssh_authorized_keys} ]] || fail "Missing SSH authorized_keys"
  [[ -e ${wpa_key} ]] || fail "Missing WPA passphrase"
}

configure_network() {
  # enable interface
  cat << EOF >> ${network_file}
[Match]
Name=${interface}

[Network]
DHCP=yes
EOF
  # start wpa_supplicant
  ln -s ${unit_file} ${unit_file_link}
  # wpa_supplicant credentials
  cp ${wpa_key} ${wpa_conf}
  chmod 644 ${wpa_conf}
  # enable
  systemctl daemon-reload
  sleep 5
}

install_packages() {
  pacman -Syu python ansible sudo openssh --noconfirm
}

configure_ssh() {
  cp ssh_host_* "${ssh_dir}"
  for ktype in rsa dsa ecdsa ed25519; do
    keyfile="ssh_host_${ktype}_key"
    mv "${keyfile}" "${ssh_dir}/${keyfile}"
    chown root:root "${ssh_dir}/${keyfile}"
    chmod 600 "${ssh_dir}/${keyfile}"
    mv "${keyfile}.pub" "${ssh_dir}/${keyfile}.pub"
    chown root:root "${ssh_dir}/${keyfile}.pub"
    chmod 644 "${ssh_dir}/${keyfile}.pub"
  done
  systemctl enable sshd
  systemctl restart sshd
}

configure_sudo() {
  sed -i.bak 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
  sed -i.bak 's/# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
  visudo -cf /etc/sudoers
}

create_user() {
  useradd -m -G wheel ${user}
  mkdir -p ${user_ssh_dir}
  chmod 700 ${user_ssh_dir}
  mv ${ssh_authorized_keys} ${user_authorized_keys}
  chmod 640 ${user_authorized_keys}
  chown -R "${user}:${user}" ${user_ssh_dir}
}

print_mac_address() {
  ip link | grep "${interface}"
}

lockdown_users() {
   ! id -u ${default_user} &>/dev/null || userdel -r "${default_user}"
  passwd -l root
}

main() {
  cd "$(dirname "${BASH_SOURCE[0]}")"

  check_files
  if [[ "$1" == "--check" ]]; then
    print_mac_address
    exit 0
  fi

  check_permissions
  configure_network
  install_packages
  configure_ssh
  configure_sudo
  create_user
  lockdown_users
}

main "$@"
