#!/bin/bash
set -xeu
# I'm a big fan of nushell for interactive use, and I want to support
# using it in our test suite because it's better than bash. First,
# enable EPEL to get it.
. /usr/lib/os-release
if echo $ID_LIKE $ID | grep -q centos; then
  dnf config-manager --set-enabled crb
  dnf -y install epel-release epel-next-release
fi
# Ensure this is pre-created
mkdir -p -m 0700 /var/roothome
mkdir -p ~/.config/nushell
echo '$env.config = { show_banner: false, }' > ~/.config/nushell/config.nu
touch ~/.config/nushell/env.nu
dnf -y install nu
dnf clean all && rm /var/log/* -rf
