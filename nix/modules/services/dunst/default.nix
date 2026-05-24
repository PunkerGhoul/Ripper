{ config, pkgs, ... }:

let
  laCapitaineDark = pkgs.runCommand "la-capitaine-icon-theme-dark" { } ''
    mkdir -p "$out/share/icons"
    source_dir="$(find "${pkgs.la-capitaine-icon-theme}/share/icons" -mindepth 1 -maxdepth 1 -type d | sort | head -n 1)"
    if [ -z "$source_dir" ]; then
      echo "No icon theme directory found in ${pkgs.la-capitaine-icon-theme}/share/icons" >&2
      exit 1
    fi

    cp -R --no-preserve=mode,ownership "$source_dir" "$out/share/icons/La-Capitaine"

    cd "$out/share/icons/La-Capitaine"
    replace_link() {
      link="$1"
      target="$2"
      dir="$(dirname "$link")"
      if [ -e "$dir/$target" ]; then
        rm -rf "$link"
        ln -s "$target" "$link"
      fi
    }

    replace_link actions/22x22 22x22-dark
    replace_link devices/scalable scalable-dark
    replace_link emblems/scalable/avatar-default.svg avatar-default-dark.svg
    replace_link panel/16 16-dark
    replace_link panel/24 24-dark
    replace_link places/16x16 16x16-dark
    replace_link status/scalable scalable-dark
  '';
in
{
  home.packages = [
    pkgs.libnotify
  ];

  services.dunst = {
    enable = true;
    configFile = ./dunstrc;
    iconTheme = {
      package = laCapitaineDark;
      name = "La-Capitaine";
    };
  };
}
