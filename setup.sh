#!/bin/env bash

if [ "$(/bin/id -u)" -eq 0 ]; then
  echo "[ERROR] This script shouldn't be executed as root"
fi

USERNAME=$(/bin/id -un)
ARCHITECTURE="x86_64-linux"
SRC_DIR=$(pwd)
REPO_NAME=$(/bin/basename "$SRC_DIR")
DEST="$HOME/.config/Ripper"

EXCLUTIONS=(
  ".git"
  ".gitignore"
  ".github"
  ".devcontainer"
  "README.md"
  "CONTRIBUTING.md"
  "LICENSE"
  "env.example.nix"
  "setup.sh"
)

EXC_ARGS=()
for EXCLUTION in "${EXCLUTIONS[@]}"; do
  EXC_ARGS+=(--exclude="$EXCLUTION")
done

help() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -h, --help      Shows this message."
  echo ""
}

add_upd_channel() {
  local url="$1"
  local name="$2"

  local exist_name=$(/nix/var/nix/profiles/default/bin/nix-channel --list | /bin/grep -E "^\S+\s+$url" | /bin/cut -d' ' -f1)

  if [ -z "$exist_mame" ]; then
    echo "[INFO] Adding channel: $name"
    /nix/var/nix/profiles/default/bin/nix-channel --add "$url" "$name"
  elif [ "$exist_name" != "$name" ]; then
    echo "[WARN] Channel was already registered with a different name ($exist_name). Updating..."
    /nix/var/nix/profiles/default/bin/nix-channel --remove "$exist_name"
    /nix/var/nix/profiles/default/bin/nix-channel --add "$url" "$name"
  else
    echo "[INFO] Channel $name is registered."
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      help
      exit 0
      ;;
    *)
      echo "[ERROR] Invalid Option: $1"
      help
      exit 1
      ;;
  esac
done

add_upd_channel "https://github.com/nix-community/home-manager/archive/master.tar.gz" "home-manager"
/nix/var/nix/profiles/default/bin/nix-channel --update

if [ ! -f "$SRC_DIR/env.nix" ] || [ "$SRC_DIR/env.nix" = "$SRC_DIR/env.example.nix" ]; then
  echo "[ERROR] File env.nix doesn't exists or has the same content as env.example.nix"
  exit 1
fi

/bin/sed -i "s/USERNAME_VAR/$USERNAME/" "$SRC_DIR/flake.nix"
/bin/sed -i "s/ARCHITECTURE_VAR/$ARCHITECTURE/" "$SRC_DIR/flake.nix"

/bin/mkdir -p "$DEST"

/bin/sudo /bin/rsync -av --delete ${EXC_ARGS[@]} ${SRC_DIR}/ $DEST/

/bin/sed -i "s/$ARCHITECTURE/ARCHITECTURE_VAR/" "$SRC_DIR/flake.nix"
/bin/sed -i "s/$USERNAME/USERNAME_VAR/" "$SRC_DIR/flake.nix"

/bin/sudo /sbin/groupadd ripper
/bin/sudo /sbin/usermod -aG ripper $USERNAME

/bin/sudo /bin/find "$DEST" -type f ! -name "flake.lock" -exec /bin/chmod 640 {} \; -exec /bin/chown root:ripper {} \;

if [ -f "$DEST/flake.lock" ]; then
  /bin/sudo /bin/chown "root:ripper" "$DEST/flake.lock"
  /bin/sudo /bin/chmod 660 "$DEST/flake.lock"
fi

/bin/sudo /bin/find "$DEST" -type d -exec /bin/chmod 750 {} \; -exec /bin/chown root:ripper {} \;

export ripper_build=""

echo "[DONE] Files copied from $SRC_DIR to $DEST, excluding some files."
echo "[DONE] Run 'ripper-build'"
