{ config, pkgs, lib, ... }:

let
  layouts = [
    {
      xkbLayout = "us";
      xkbVariant = "";
      label = "EN";
    }
    {
      xkbLayout = "latam";
      xkbVariant = "";
      label = "LA";
    }
  ];

  defaultLayout = builtins.head layouts;

  layoutLines = lib.concatMapStringsSep "\n" (
    layout:
      "${layout.xkbLayout}:${layout.xkbVariant}:${layout.label}"
  ) layouts;

  keyboardLayoutScript = pkgs.writeShellScript "ripper-keyboard-layout" ''
    set -eu

    PATH="${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gawk}/bin:${pkgs.setxkbmap}/bin''${PATH:+:$PATH}"

    state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/ripper/keyboard"
    runtime_dir="''${XDG_RUNTIME_DIR:-/tmp/ripper-runtime-$UID}"
    mkdir -p "$state_dir" "$runtime_dir"
    chmod 700 "$state_dir" "$runtime_dir" 2>/dev/null || true

    layouts_file="$state_dir/layouts"
    current_file="$state_dir/current"
    tap_file="$runtime_dir/ripper-keyboard-layout.tap"
    changed_file="$runtime_dir/ripper-keyboard-layout.changed"

    cat > "$layouts_file" <<'EOF'
    ${layoutLines}
    EOF

    default_layout="${defaultLayout.xkbLayout}"
    default_variant="${defaultLayout.xkbVariant}"

    apply_layout() {
      layout="$1"
      variant="''${2:-}"

      if [ -n "$variant" ]; then
        setxkbmap -layout "$layout" -variant "$variant"
      else
        setxkbmap -layout "$layout"
      fi

      printf '%s:%s\n' "$layout" "$variant" > "$current_file"
      date +%s%N > "$changed_file"
    }

    current_layout() {
      current="$(setxkbmap -query 2>/dev/null | awk '/^layout:/ { print $2; exit }')"
      variant="$(setxkbmap -query 2>/dev/null | awk '/^variant:/ { print $2; exit }')"
      printf '%s:%s\n' "''${current:-$default_layout}" "''${variant:-}"
    }

    layout_label() {
      wanted="$1"
      awk -F: -v wanted="$wanted" '
        $1 ":" $2 == wanted { print $3; found=1; exit }
        END { if (!found) print toupper(substr(wanted, 1, 2)) }
      ' "$layouts_file"
    }

    cycle_layout() {
      current="$(current_layout)"
      next="$(awk -F: -v current="$current" '
        {
          entries[NR] = $1 ":" $2
          layouts[NR] = $1
          variants[NR] = $2
        }
        $1 ":" $2 == current { current_index = NR }
        END {
          if (NR == 0) exit 1
          next_index = current_index ? current_index + 1 : 1
          if (next_index > NR) next_index = 1
          print layouts[next_index] ":" variants[next_index]
        }
      ' "$layouts_file")"

      apply_layout "''${next%%:*}" "''${next#*:}"
    }

    case "''${1:-status}" in
      apply-default)
        apply_layout "$default_layout" "$default_variant"
        ;;
      cycle)
        cycle_layout
        ;;
      double-tap-cycle)
        now="$(date +%s%N)"
        previous="$(cat "$tap_file" 2>/dev/null || echo 0)"
        printf '%s\n' "$now" > "$tap_file"

        if [ "$((now - previous))" -le 450000000 ]; then
          : > "$tap_file"
          cycle_layout
        fi
        ;;
      status)
        layout_label "$(current_layout)"
        ;;
      *)
        echo "usage: ripper-keyboard-layout {apply-default|cycle|double-tap-cycle|status}" >&2
        exit 2
        ;;
    esac
  '';

  keyboardStatusScript = pkgs.writeShellScript "ripper-keyboard-status" ''
    set -eu

    PATH="${pkgs.coreutils}/bin:${pkgs.inotify-tools}/bin''${PATH:+:$PATH}"

    runtime_dir="''${XDG_RUNTIME_DIR:-/tmp/ripper-runtime-$UID}"
    changed_file="$runtime_dir/ripper-keyboard-layout.changed"
    mkdir -p "$runtime_dir"

    print_status() {
      "$HOME/.local/bin/ripper-keyboard-layout" status
    }

    print_status

    if [ -x "${pkgs.inotify-tools}/bin/inotifywait" ]; then
      while ${pkgs.inotify-tools}/bin/inotifywait -q -e close_write,create,modify "$runtime_dir" >/dev/null 2>&1; do
        [ -e "$changed_file" ] || continue
        print_status
      done
    else
      while true; do
        sleep 1
        print_status
      done
    fi
  '';
in
{
  home.packages = [
    pkgs.setxkbmap
    pkgs.inotify-tools
  ];

  home.file.".local/bin/ripper-keyboard-layout" = {
    source = keyboardLayoutScript;
    executable = true;
  };

  home.file.".local/bin/ripper-keyboard-status" = {
    source = keyboardStatusScript;
    executable = true;
  };

  xsession.initExtra = ''
    "$HOME/.local/bin/ripper-keyboard-layout" apply-default >/dev/null 2>&1 || true
  '';
}
