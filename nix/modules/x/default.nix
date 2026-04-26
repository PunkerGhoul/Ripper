{ config, pkgs, lib, logoutScript, ... }:

let
  vmwareAutoResize = pkgs.stdenv.mkDerivation {
    pname = "ripper-vmware-auto-resize";
    version = "1.0.0";

    dontUnpack = true;
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [
      pkgs.libx11
      pkgs.libxrandr
    ];

    buildPhase = ''
      runHook preBuild
      $CC ${./scripts/vmware-auto-resize.c} \
        -o ripper-vmware-auto-resize \
        $(pkg-config --cflags --libs x11 xrandr)
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 ripper-vmware-auto-resize $out/bin/ripper-vmware-auto-resize
      runHook postInstall
    '';
  };

  vmwareAutoResizeStart = pkgs.writeShellScript "ripper-vmware-auto-resize-start" ''
    set -eu

    runtime_dir="''${XDG_RUNTIME_DIR:-/tmp/ripper-runtime-$UID}"
    mkdir -p "$runtime_dir"
    chmod 700 "$runtime_dir"
    log="$runtime_dir/ripper-vmware-auto-resize.log"
    exec >>"$log" 2>&1

    if [ -z "''${DISPLAY:-}" ]; then
      export DISPLAY=:0
    fi
    export XDG_SESSION_TYPE=x11

    if [ -z "''${XAUTHORITY:-}" ] && [ -r "$HOME/.Xauthority" ]; then
      export XAUTHORITY="$HOME/.Xauthority"
    fi

    exec 9>"$runtime_dir/ripper-vmware-auto-resize.lock"
    if ! ${pkgs.util-linux}/bin/flock -n 9; then
      echo "ripper-vmware-auto-resize: already running"
      exit 0
    fi

    echo "ripper-vmware-auto-resize: start $(${pkgs.coreutils}/bin/date) DISPLAY=''${DISPLAY:-unset} XAUTHORITY=''${XAUTHORITY:-unset}"
    exec ${vmwareAutoResize}/bin/ripper-vmware-auto-resize ${pkgs.xrandr}/bin/xrandr
  '';

  vmwareUserStart = pkgs.writeShellScript "ripper-vmware-user-start" ''
    set -eu

    runtime_dir="''${XDG_RUNTIME_DIR:-/tmp/ripper-runtime-$UID}"
    mkdir -p "$runtime_dir"
    chmod 700 "$runtime_dir"
    log="$runtime_dir/ripper-vmware-user.log"
    exec >>"$log" 2>&1

    exec 9>"$runtime_dir/ripper-vmware-user.lock"
    if ! ${pkgs.util-linux}/bin/flock -n 9; then
      echo "ripper-vmware-user: already running"
      exit 0
    fi

    if [ -z "''${DISPLAY:-}" ]; then
      export DISPLAY=:0
    fi
    export XDG_SESSION_TYPE=x11

    if [ -z "''${XAUTHORITY:-}" ] && [ -r "$HOME/.Xauthority" ]; then
      export XAUTHORITY="$HOME/.Xauthority"
    fi

    echo "ripper-vmware-user: start $(${pkgs.coreutils}/bin/date) DISPLAY=''${DISPLAY:-unset} XAUTHORITY=''${XAUTHORITY:-unset}"

    if [ -x /usr/local/libexec/ripper-vmware-user-suid-wrapper ]; then
      echo "ripper-vmware-user: exec /usr/local/libexec/ripper-vmware-user-suid-wrapper"
      exec /usr/local/libexec/ripper-vmware-user-suid-wrapper
    fi

    if [ -x ${pkgs.open-vm-tools}/bin/vmtoolsd ]; then
      echo "ripper-vmware-user: exec ${pkgs.open-vm-tools}/bin/vmtoolsd -n vmusr -c /etc/vmware-tools/tools.conf"
      exec ${pkgs.open-vm-tools}/bin/vmtoolsd -n vmusr -c /etc/vmware-tools/tools.conf
    fi

    if [ -x /usr/bin/vmtoolsd ]; then
      echo "ripper-vmware-user: exec /usr/bin/vmtoolsd -n vmusr -c /etc/vmware-tools/tools.conf"
      exec /usr/bin/vmtoolsd -n vmusr -c /etc/vmware-tools/tools.conf
    fi

    if [ -x /usr/bin/vmware-user ]; then
      echo "ripper-vmware-user: exec /usr/bin/vmware-user"
      exec /usr/bin/vmware-user
    fi

    echo "ripper-vmware-user: open-vm-tools desktop user command not found" >&2
    exit 0
  '';
in
{
  home.activation.install-vmware-tools = lib.hm.dag.entryAfter [ "writeBoundary" ]
    (builtins.replaceStrings
      [ "{{gnuGrep}}" "{{systemd}}" "{{pciUtils}}" "{{openVmTools}}" ]
      [ "${pkgs.gnugrep}" "${pkgs.systemd}" "${pkgs.pciutils}" "${pkgs.open-vm-tools}" ]
      (builtins.readFile ./scripts/install-vmware-tools.sh));

  home.activation.stop-obsolete-vmware-user-units = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    systemctl_bin=""
    for candidate in /usr/bin/systemctl /bin/systemctl; do
      if [ -x "$candidate" ]; then
        systemctl_bin="$candidate"
        break
      fi
    done

    if [ -n "$systemctl_bin" ]; then
      "$systemctl_bin" --user stop vmware-user.service vmware-auto-resize.service 2>/dev/null || true
      "$systemctl_bin" --user disable vmware-user.service vmware-auto-resize.service 2>/dev/null || true
      "$systemctl_bin" --user reset-failed vmware-user.service vmware-auto-resize.service 2>/dev/null || true
    fi
  '';

  home.file.".xinitrc".text = builtins.replaceStrings
    [ "{{homeDirectory}}" ]
    [ config.home.homeDirectory ]
    (builtins.readFile ./xinitrc);

  home.file.".local/bin/ripper-vmware-auto-resize" = {
    source = vmwareAutoResizeStart;
    executable = true;
  };

  home.file.".local/bin/ripper-vmware-user" = {
    source = vmwareUserStart;
    executable = true;
  };

  home.packages = with pkgs; [
    open-vm-tools
    pciutils    # lspci for VMware detection
    xrandr      # available in PATH for manual use
  ];

  xsession = {
    enable = true;
  };

  imports = [
    (import ./i3 { inherit config pkgs lib logoutScript; })
  ];
}
