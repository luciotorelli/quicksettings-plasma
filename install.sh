#!/usr/bin/env bash
# Installs the widget for the current user, or upgrades it if already there.
# Afterwards: right-click the panel > Add or Manage Widgets > "Quick Settings".
# After an upgrade, restart Plasma to load the new code:
#   systemctl --user restart plasma-plasmashell
set -eu

cd "$(dirname "$0")"
id=$(sed -n 's/.*"Id": *"\([^"]*\)".*/\1/p' package/metadata.json)

if kpackagetool6 --type Plasma/Applet --list | grep -qx "$id"; then
    kpackagetool6 --type Plasma/Applet --upgrade package
else
    kpackagetool6 --type Plasma/Applet --install package
fi
