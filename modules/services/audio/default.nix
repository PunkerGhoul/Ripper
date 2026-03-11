{ pkgs, ... }:

{
  home.packages = with pkgs; [
    easyeffects
    pavucontrol  # useful to inspect/override pipewire audio profiles manually
  ];

  # Run EasyEffects as a headless background service so audio processing
  # (equalizers, compressors, etc.) is always active without keeping the UI open.
  services.easyeffects = {
    enable = true;
  };

  # WirePlumber: force "Analog Stereo Output" profile for every ALSA card.
  #
  # VMware's virtual audio device (vmwgfx/ensoniq) only exposes an output
  # side.  WirePlumber picks up both capture and playback directions by
  # default and tries to open an "Analog Stereo Duplex" profile, which
  # attempts to claim a capture device ID that does not exist in VMware,
  # producing:  "A device ID has been used that is out of range for your system."
  #
  # Restricting the profile to "output:analog-stereo" avoids the duplex
  # attempt entirely and gives stable playback through PipeWire.
  xdg.configFile."wireplumber/wireplumber.conf.d/50-vmware-audio.conf".text = ''
    monitor.alsa.rules = [
      {
        matches = [
          {
            device.name = "~alsa_card.*"
          }
        ]
        actions = {
          update-props = {
            device.profile = "output:analog-stereo"
          }
        }
      }
    ]
  '';
}
