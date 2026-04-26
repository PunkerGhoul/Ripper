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

    if [ -z "''${XAUTHORITY:-}" ] && [ -r "$HOME/.Xauthority" ]; then
      export XAUTHORITY="$HOME/.Xauthority"
    fi

    exec 9>"$runtime_dir/ripper-vmware-auto-resize.lock"
    ${pkgs.util-linux}/bin/flock -n 9 || exit 0

    echo "ripper-vmware-auto-resize: start $(${pkgs.coreutils}/bin/date) DISPLAY=''${DISPLAY:-unset} XAUTHORITY=''${XAUTHORITY:-unset}"
    exec ${vmwareAutoResize}/bin/ripper-vmware-auto-resize ${pkgs.xrandr}/bin/xrandr
  '';

  vmwareUserStart = pkgs.writeShellScript "ripper-vmware-user-start" ''
    set -eu

    runtime_dir="''${XDG_RUNTIME_DIR:-/tmp/ripper-runtime-$UID}"
    mkdir -p "$runtime_dir"
    chmod 700 "$runtime_dir"
    exec 9>"$runtime_dir/ripper-vmware-user.lock"
    ${pkgs.util-linux}/bin/flock -n 9 || exit 0

    if [ -z "''${DISPLAY:-}" ]; then
      export DISPLAY=:0
    fi

    if [ -z "''${XAUTHORITY:-}" ] && [ -r "$HOME/.Xauthority" ]; then
      export XAUTHORITY="$HOME/.Xauthority"
    fi

    for candidate in /usr/bin/vmware-user-suid-wrapper /usr/bin/vmware-user; do
      if [ -x "$candidate" ]; then
        exec "$candidate"
      fi
    done

    echo "ripper-vmware-user: open-vm-tools desktop user command not found" >&2
    exit 0
  '';
in
{
  home.activation.install-vmware-tools = lib.hm.dag.entryAfter [ "writeBoundary" ]
    (builtins.replaceStrings
      [ "{{gnuGrep}}" "{{systemd}}" "{{pciUtils}}" ]
      [ "${pkgs.gnugrep}" "${pkgs.systemd}" "${pkgs.pciutils}" ]
      (builtins.readFile ./scripts/install-vmware-tools.sh));

  systemd.user.services.vmware-user = {
    Unit = {
      Description = "VMware User Agent (clipboard, drag-and-drop, auto-resize)";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionVirtualization = "vmware";
    };
    Service = {
      Type = "simple";
      ExecStart = toString vmwareUserStart;
      Restart = "on-failure";
      RestartSec = "5s";
      Environment = [
        "DISPLAY=:0"
        "XAUTHORITY=%h/.Xauthority"
      ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

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

  # Native XRandR event loop: applies the preferred mode immediately when vmwgfx
  # emits resize events. No polling, no fixed sleeps, no udev rules.
  systemd.user.services.vmware-auto-resize = {
    Unit = {
      Description = "Apply VMware display resize via X11 RandR events";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionVirtualization = "vmware";
    };
    Service = {
      Type = "simple";
      ExecStart = toString vmwareAutoResizeStart;
      Restart = "on-failure";
      RestartSec = "3s";
      Environment = [
        "DISPLAY=:0"
        "XAUTHORITY=%h/.Xauthority"
      ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.packages = with pkgs; [
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
