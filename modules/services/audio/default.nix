{ pkgs, ... }:

let
  # Pure-PipeWire fallback: uses pw-dump (pipewire) + jq to find ALSA card
  # device IDs, then wpctl (wireplumber) to set the profile.
  # No PulseAudio dependency at all.
  audioProfileFixScript = pkgs.writeShellScript "vmware-audio-profile-fix" ''
    # Wait for wireplumber to finish device enumeration
    sleep 2
    for id in $(
      ${pkgs.pipewire}/bin/pw-dump \
        | ${pkgs.jq}/bin/jq -r '
            .[]
            | select(.type == "PipeWire:Interface:Device")
            | select(.info.props["alsa.card"] != null)
            | .id
          '
    ); do
      ${pkgs.wireplumber}/bin/wpctl set-profile "$id" output:analog-stereo 2>/dev/null || true
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
