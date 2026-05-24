# Abstract SDDM theme

Local Ripper SDDM theme based on the Purple leaves configuration from
Keyitdev/sddm-astronaut-theme.

The QML components and SVG assets are GPL-3.0-or-later upstream material from:
https://github.com/Keyitdev/sddm-astronaut-theme

This directory intentionally does not contain video backgrounds. The installer
copies `local/sddm/Abstract.mp4` to `/usr/share/sddm/themes/Abstract/Backgrounds/Abstract.mp4`
at apply time so the video stays out of the Nix store and Git history.
