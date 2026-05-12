{ config, pkgs, lib, ... }:

let
  resolvedConf = pkgs.writeText "99-ripper-dns.conf" (builtins.readFile ./resolved.conf);
  networkManagerConf = pkgs.writeText "99-ripper-dns.conf" (builtins.readFile ./networkmanager.conf);
  hostName = config.networking.hostName or "";
  hostEntry =
    if hostName == "" then
      ""
    else
      "127.0.1.1 ${hostName} ${hostName}.localdomain";
in
{
  home.activation.resolved = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -euo pipefail

    SYSTEMCTL="${pkgs.systemd}/bin/systemctl"
    INSTALL="${pkgs.coreutils}/bin/install"
    MKDIR="${pkgs.coreutils}/bin/mkdir"
    LN="${pkgs.coreutils}/bin/ln"
    CMP="${pkgs.diffutils}/bin/cmp"
    PRINTF="${pkgs.coreutils}/bin/printf"
    MKTEMP="${pkgs.coreutils}/bin/mktemp"
    GREP="${pkgs.gnugrep}/bin/grep"

    changed=0

    install_if_changed() {
      local src="$1"
      local dst="$2"

      if [[ ! -f "$dst" ]] || ! "$CMP" -s "$src" "$dst"; then
        sudo "$INSTALL" -m 0644 "$src" "$dst"
        changed=1
      fi
    }

    if [[ ! -x "$SYSTEMCTL" ]]; then
      echo "systemctl not found; skipping"
      exit 0
    fi

    if ! command -v sudo >/dev/null 2>&1; then
      echo "sudo not available; skipping"
      exit 0
    fi

    sudo "$SYSTEMCTL" enable systemd-resolved || \
      echo "warning: could not enable systemd-resolved"
    sudo "$SYSTEMCTL" try-restart systemd-resolved || true

    sudo "$MKDIR" -p /etc/systemd/resolved.conf.d
    install_if_changed \
      "${resolvedConf}" \
      /etc/systemd/resolved.conf.d/99-ripper-dns.conf

    if [[ -L /etc/resolv.conf ]] || [[ ! -e /etc/resolv.conf ]]; then
      sudo "$LN" -sfn \
        /run/systemd/resolve/stub-resolv.conf \
        /etc/resolv.conf
    else
      echo "warning: /etc/resolv.conf is not a symlink; skipping"
    fi

    nm_present=0
    nm_load_state="$("$SYSTEMCTL" show -p LoadState --value NetworkManager.service 2>/dev/null || echo not-found)"
    if [[ "$nm_load_state" != "not-found" ]]; then
      nm_present=1
      sudo "$MKDIR" -p /etc/NetworkManager/conf.d
      install_if_changed \
        "${networkManagerConf}" \
        /etc/NetworkManager/conf.d/99-ripper-dns.conf
    else
      echo "info: NetworkManager not installed; skipping"
    fi

    if [[ -n "${hostEntry}" ]]; then
      tmp_hosts="$($MKTEMP)"

      cleanup() {
        rm -f "$tmp_hosts"
      }

      trap cleanup EXIT

      "$GREP" -vE \
        "^(127\\.0\\.0\\.1|127\\.0\\.1\\.1)\\s+(${hostName}|${hostName}\\.localdomain)(\\s|$)" \
        /etc/hosts > "$tmp_hosts"

      "$PRINTF" '%s\n' "${hostEntry}" >> "$tmp_hosts"

      if ! "$CMP" -s "$tmp_hosts" /etc/hosts; then
        sudo "$INSTALL" -m 0644 "$tmp_hosts" /etc/hosts
        changed=1
      fi
    fi

    if (( changed )); then
      sudo "$SYSTEMCTL" reload-or-restart systemd-resolved || true
      if (( nm_present )); then
        sudo "$SYSTEMCTL" reload-or-restart NetworkManager || true
      fi
    fi
  '';
}
