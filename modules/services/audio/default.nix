{ pkgs, lib, ... }:

let
  # Fallback script — pure PipeWire, no PulseAudio tooling.
  #
  # pw-cli enum-params output per profile block:
  #   Prop: key Spa:Pod:Object:Param:Profile:index ... Int 1
  #   Prop: key Spa:Pod:Object:Param:Profile:name  ... String "output:analog-stereo"
  # awk tracks the last seen "Int N" value; prints N when it meets the target name.
  # pw-cli set-param uses SPA-JSON: '{ index: N }'
  audioProfileFixScript = pkgs.writeShellScript "vmware-audio-profile-fix" ''
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
      profile_idx=$(
        ${pkgs.pipewire}/bin/pw-cli enum-params "$dev_id" EnumProfile 2>/dev/null \
          | ${pkgs.gawk}/bin/awk '
              /Spa:Pod:Object:Param:Profile:index/ {
                match($0, /Int ([0-9]+)/, m); idx = m[1]
              }
              /Spa:Pod:Object:Param:Profile:name/ && /output:analog-stereo/ {
                print idx; exit
              }
            '
      )
      if [ -n "$profile_idx" ]; then
        ${pkgs.pipewire}/bin/pw-cli set-param "$dev_id" Profile "{ index: $profile_idx }" 2>/dev/null \
          && echo "vmware-audio: device $dev_id → output:analog-stereo (index $profile_idx)"
      fi
    done
  '';
in
{
  home.packages = with pkgs; [
    easyeffects
    pavucontrol
  ];

  services.easyeffects.enable = true;

  # ── WirePlumber drop-in ────────────────────────────────────────────────────
  # device.profile.default  – profile WirePlumber selects at device creation.
  # api.acp.auto-profile    – prevents ACP from overriding it later with its
  #                           "best profile" heuristic (which picks Duplex).
  #
  # Together they keep the card on output:analog-stereo and stop WirePlumber
  # from probing the Duplex profile, which fails on VMware (no capture device).
  xdg.configFile."wireplumber/wireplumber.conf.d/50-vmware-audio.conf".text = ''
    monitor.alsa.rules = [
      {
        matches = [
          { device.name = "~alsa_card.*" }
        ]
        actions = {
          update-props = {
            device.profile.default  = "output:analog-stereo"
            api.acp.auto-profile    = false
          }
        }
      }
    ]
  '';

  # ── Clear WirePlumber saved state on every deploy ─────────────────────────
  # WirePlumber persists the last-used profile in ~/.local/state/wireplumber/.
  # If Duplex was ever saved there it overrides device.profile.default, so we
  # wipe it on each home-manager switch; WirePlumber rebuilds it correctly on
  # its next start using the drop-in config above.
  home.activation.clear-wireplumber-state = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -rf "$HOME/.local/state/wireplumber"
  '';

  # ── Systemd fallback ───────────────────────────────────────────────────────
  # Belt-and-suspenders: forces the correct profile via pw-cli after every
  # WirePlumber start, in case the drop-in alone isn't honoured.
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
