#!/usr/bin/env bash

set -e

fail() {
  echo "$1" >&2 && exit 1
}

parse_args() {
  while [[ $# -gt 0 ]];
  do
    case $1 in
      --secrets|-s) shift; secrets=$1; shift ;;
      --host|-h)    shift; host=$1; shift ;;
      *) fail "Unknown option: $1" ;;
    esac
  done
}

main() {
  parse_args "$@"

  [[ -n ${host} ]] || fail "No host specified"
  [[ -n ${secrets} ]] || fail "No secrets specified"

  secrets="$(readlink -f "${secrets}")"

  export PASSWORD_STORE_DIR="${secrets}"
  cd "${secrets}"

  for key_type in rsa dsa ecdsa ed25519;
  do
    local keyfile="ssh_host_${key_type}_key"
    ssh-keygen -t "${key_type}" -P "" -C "${host}" -f "${keyfile}" > /dev/null
    cat "${keyfile}" | pass insert -m "${host}/${keyfile}"
    cat "${keyfile}.pub" | pass insert -m "${host}/${keyfile}.pub"
    rm "${keyfile}" "${keyfile}.pub"
  done
}

main "$@"
