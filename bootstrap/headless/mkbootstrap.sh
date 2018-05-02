#!/usr/bin/env bash

set -ex

fail() {
  echo "$1" >&2 && exit 1
}

initialise_config() {
  bootp="${device}p1"
  rootp="${device}p2"

  case ${config} in
    rpizero)
      echo "Using rpi zero config"
      image_file="ArchLinuxARM-rpi-latest.tar.gz"
      image_url="http://os.archlinuxarm.org/os/${image_file}"
      ;;
    rpi3)
      echo "Using rpi 3 config"
      image_file="ArchLinuxARM-rpi-3-latest.tar.gz"
      image_url="http://os.archlinuxarm.org/os/${image_file}"
      ;;
  esac
}

download_image() {
  [[ -e "${image_file}" ]] || wget "${image_url}" "${image_file}"
}

partition_device() {
  (
    echo "o"      # smash everything

    echo "n"      # new partition
    echo "p"      # primary partition
    echo "1"      # first partition
    echo ""       # default first sector
    echo "+100M"  # last sector size
    echo "t"      # type
    echo "c"      # FAT

    echo n        # new partition
    echo p        # primary partition
    echo 2        # second partition
    echo          # default first sector
    echo          # default last sector

    echo p        # list partitions
    echo w        # write table
  ) | fdisk "${device}"
}

create_filesystems() {
  echo "Creating filesystems..."
  [[ -n "${bootp}" && -e "${bootp}" ]] || fail "Bad boot partition?"
  [[ -n "${rootp}" && -e "${rootp}" ]] || fail "Bad root partition?"
  [[ -e "${image_file}" ]] || fail "no image file?"

  mkfs.ext4 "${rootp}"
  mkfs.vfat "${bootp}"

  mount "${rootp}" /mnt

  bsdtar -xpf "${image_file}" -C /mnt

  mkdir /mnt/boot.tmp
  mount "${bootp}" /mnt/boot.tmp
  mv /mnt/boot/* /mnt/boot.tmp
  umount /mnt/boot.tmp
  rmdir /mnt/boot.tmp

  umount /mnt
  sync
}

generate_keys() {
  echo "Generating keys..."
  for key_type in rsa dsa ecdsa ed25519;
  do
    local keyfile="ssh_host_${key_type}_key"
    sudo -u "${user}" -E ssh-keygen -t "${key_type}" -P "" -C "${host}" -f "${keyfile}" > /dev/null
    sudo -u "${user}" -E pass insert -m "${host}/${keyfile}" < "${keyfile}"
    sudo -u "${user}" -E pass insert -m "${host}/${keyfile}.pub" < "${keyfile}"
    rm "${keyfile}" "${keyfile}.pub"
  done
}

parse_args() {
  while [[ $# -gt 0 ]];
  do
    case $1 in
      --device|-d)  shift; device=$1; shift ;;
      --secrets|-s) shift; secrets=$1; shift ;;
      --host|-h)    shift; host=$1; shift ;;
      --config|-c)  shift; config=$1; shift ;;
      --user|-u)  shift; user=$1; shift ;;
      *) fail "Unknown option: $1" ;;
    esac
  done
}

mount_fs() {
  mount "${rootp}" /mnt
  mount "${bootp}" /mnt/boot
}

umount_fs() {
  umount -R /mnt
}

load_bootstrap_files() {
  local target=/mnt/root

  mkdir -p "${target}"
  for ktype in rsa dsa ecdsa ed25519; do
    keyfile="ssh_host_${ktype}_key"
    sudo -u "${user}" -E pass show "${host}/${keyfile}" > "${target}/${keyfile}"
    sudo -u "${user}" -E pass show "${host}/${keyfile}.pub" > "${target}/${keyfile}.pub"
  done
  sudo -u "${user}" -E pass show "home/wpa_supplicant.conf" > "${target}/wpa_supplicant.conf"
  cp /home/${user}/.ssh/id_rsa.pub "${target}/authorized_keys"

  cp bootstrap.sh "${target}"
}

#
# bootstrap /dev/mmcblk0 rpi persephone
#
main() {
  parse_args "$@"

  [[ "$(id -u)" = 0 ]] || fail "y u no root?"
  [[ -n "${device}" && -e "${device}" ]] || fail "No device specified"
  [[ -n ${host} ]] || fail "No host specified"
  [[ -n ${config} ]] || fail "No config specified"
  [[ -n ${secrets} ]] || fail "No secrets specified"
  [[ -n ${user} ]] || fail "No user specified"

  initialise_config

  echo "Bootstrapping ${host} on ${device} as ${config} using ${secrets}"

  secrets="$(readlink -f "${secrets}")"
  export PASSWORD_STORE_DIR="${secrets}"
  export GNUPGHOME="/home/${user}/.gnupg"

 download_image
 partition_device
 create_filesystems

 generate_keys
 mount_fs
 load_bootstrap_files
 umount_fs
}

main "$@"
