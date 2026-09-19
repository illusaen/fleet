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
      };
    };

    security.rtkit.enable = true;
  };
}
