{
  imports = [./niri ./audio.nix ./autostart.nix ./fonts.nix ./nautilus.nix ./noctalia.nix ./sddm.nix ./weylus.nix];

  modules.nixos = {
    config,
    lib,
    pkgs,
    ...
  }: {
    environment.systemPackages = with pkgs; [
      ddcutil
      local.misc-scripts
    ];

    hardware = {
      bluetooth.settings.General.Experimental = true;
      i2c.enable = true;
    };
    services.blueman.enable = true;

    systemdAutostart = [
      rec {
        inherit (config.services.tailscale) package;
        name = "tailscale-systray";
        exec = "${lib.getExe package} systray";
      }
    ];

    persist.directories = ["/var/lib/bluetooth"];
  };
}
