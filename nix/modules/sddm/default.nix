{ config, pkgs, lib, installConfig, ... }:

let
  sddm = installConfig.sddm or { };
  enabled = sddm.enable or true;
  themeName = sddm.theme or "Abstract";
  videoSource = sddm.videoSource or "";
  themeSource = ./assets/Abstract;
  loginUser = installConfig.username or "";
in
lib.mkIf enabled {
  home.activation.sddm = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -euo pipefail

    SUDO=/usr/bin/sudo
    INSTALL="${pkgs.coreutils}/bin/install"
    CP="${pkgs.coreutils}/bin/cp"
    MKDIR="${pkgs.coreutils}/bin/mkdir"
    RM="${pkgs.coreutils}/bin/rm"
    CMP="${pkgs.diffutils}/bin/cmp"
    FIND="${pkgs.findutils}/bin/find"
    MKTEMP="${pkgs.coreutils}/bin/mktemp"

    if [[ ! -x "$SUDO" ]]; then
      echo "sddm: sudo not available; skipping"
      exit 0
    fi

    theme_dest="/usr/share/sddm/themes/${themeName}"
    video_source="${videoSource}"
    video_dest="$theme_dest/Backgrounds/Abstract.mp4"

    if [[ "$theme_dest" == /nix/store/* ]]; then
      echo "sddm: refusing to write theme into Nix store: $theme_dest" >&2
      exit 1
    fi

    "$SUDO" "$RM" -rf "$theme_dest"
    "$SUDO" "$MKDIR" -p "$theme_dest"
    "$FIND" "${themeSource}" -mindepth 1 -maxdepth 1 ! -name Backgrounds -exec "$SUDO" "$CP" -R {} "$theme_dest/" \;
    "$SUDO" "$MKDIR" -p "$theme_dest/Backgrounds"

    if [[ -z "$video_source" ]]; then
      echo "sddm: installConfig.sddm.videoSource is empty; skipping Abstract.mp4" >&2
    elif [[ ! -f "$video_source" ]]; then
      echo "sddm: missing video source: $video_source" >&2
      exit 1
    elif [[ ! -f "$video_dest" ]] || ! "$CMP" -s "$video_source" "$video_dest"; then
      "$SUDO" "$INSTALL" -m 0644 "$video_source" "$video_dest"
    fi

    "$SUDO" "$MKDIR" -p /etc/sddm.conf.d

    hidden_users="root,nobody"
    if [[ -r /etc/passwd ]]; then
      while IFS=: read -r name _ _ _ _ _ _; do
        if [[ "$name" == nixbld* && "$name" != "${loginUser}" ]]; then
          hidden_users="$hidden_users,$name"
        fi
      done < /etc/passwd
    fi

    tmp_config="$("$MKTEMP")"
    cleanup() {
      "$RM" -f "$tmp_config"
    }
    trap cleanup EXIT

    cat > "$tmp_config" <<EOF
[General]
DisplayServer=x11-user
InputMethod=qtvirtualkeyboard

[Autologin]
Relogin=false
Session=
User=

[Users]
MinimumUid=1000
MaximumUid=29999
HideShells=/usr/sbin/nologin,/usr/bin/nologin,/sbin/nologin,/bin/false
HideUsers=$hidden_users
RememberLastUser=false
RememberLastSession=false

[Theme]
Current=${themeName}
EOF

    if [[ ! -f /etc/sddm.conf.d/99-ripper.conf ]] || ! "$CMP" -s "$tmp_config" /etc/sddm.conf.d/99-ripper.conf; then
      "$SUDO" "$INSTALL" -m 0644 "$tmp_config" /etc/sddm.conf.d/99-ripper.conf
    fi
  '';
}
