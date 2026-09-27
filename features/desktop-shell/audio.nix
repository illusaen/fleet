{
  modules.nixos = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [pavucontrol];

    services = {
      playerctld.enable = true;
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        alsa = {
          enable = true;
          support32Bit = true;
        };
        pulse.enable = true;
        wireplumber.extraConfig."10-default-volume" = {
          "wireplumber.settings"."device.routes.default-sink-volume" = 0.25;
        };
      };
    };

    security.rtkit.enable = true;
  };
}
