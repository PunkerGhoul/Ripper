{ pkgs, ... }:

let
  # Pure-PipeWire fallback script.
  #
  # wpctl set-profile requires a NUMERIC index, not the profile name string.
  # We use pw-cli enum-params to discover the index for "output:analog-stereo"
  # and then pass that integer to wpctl — no PulseAudio tooling involved.
  audioProfileFixScript = pkgs.writeShellScript "vmware-audio-profile-fix" ''
    # Wait for WirePlumber to finish device enumeration
    sleep 3

    for dev_id in $(
      ${pkgs.pipewire}/bin/pw-dump \
        | ${pkgs.jq}/bin/jq -r '
            .[]
            | select(.type == "PipeWire:Interface:Device")
            | select(.info.props["alsa.card"] != null)
            | .id
          '
    ); do
      # pw-cli enum-params prints each profile block with "index: N" before
      # "name: ...", so grep -B2 on the name reliably captures its index line.
      profile_idx=$(
        ${pkgs.pipewire}/bin/pw-cli enum-params "$dev_id" EnumProfile 2>/dev/null \
          | ${pkgs.gnugrep}/bin/grep -B2 '"output:analog-stereo"' \
          | ${pkgs.gnugrep}/bin/grep -o 'index: [0-9]*' \
          | ${pkgs.gnused}/bin/sed 's/index: //' \
          | tail -1
      )
      [ -n "$profile_idx" ] && \
        ${pkgs.wireplumber}/bin/wpctl set-profile "$dev_id" "$profile_idx" 2>/dev/null || true
    done
  '';
in
{
  home.packages = with pkgs; [
    easyeffects
    pavucontrol
  ];

  # Run EasyEffects as a headless background service.
  services.easyeffects = {
    enable = true;
  };

  # ── WirePlumber drop-in ────────────────────────────────────────────────────
  # VMware's virtual audio device (ES1371/Ensoniq) only exposes an output
  # side.  WirePlumber defaults to "Analog Stereo Duplex", which tries to
  # claim a capture device ID that doesn't exist in VMware → "out of range".
  #
  # device.profile.default tells WirePlumber which profile to activate when
  # it first creates the device object, before any other policy runs.
  xdg.configFile."wireplumber/wireplumber.conf.d/50-vmware-audio.conf".text = ''
    monitor.alsa.rules = [
      {
        matches = [
          { device.name = "~alsa_card.*" }
        ]
        actions = {
          update-props = {
            device.profile.default = "output:analog-stereo"
          }
        }
      }
    ]
  '';

  # ── Systemd fallback ───────────────────────────────────────────────────────
  # Runs once per login after wireplumber is up.  Handles sessions where
  # WirePlumber already started with the wrong profile before the drop-in
  # was deployed, or on first boot before the drop-in takes effect.
  systemd.user.services.vmware-audio-profile = {
    Unit = {
      Description = "Set Analog Stereo Output profile for VMware audio";
      After = [ "wireplumber.service" "pipewire.service" ];
      Wants = [ "wireplumber.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${audioProfileFixScript}";
      RemainAfterExit = true;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
