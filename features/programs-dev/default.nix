{
  imports = [./vscode.nix ./zathura.nix];

  modules.nixos = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [codex inkscape image-roll obsidian];
    xdg.mime.defaultApplications."image/*" = "com.github.weclaw1.ImageRoll.desktop";
    persistUser.directories = [".codex" ".config/obsidian" ".var/app/com.orcaslicer.OrcaSlicer"];
    persist.directories = ["/var/lib/flatpak"];
    systemdAutostart = [{package = pkgs.obsidian;}];

    # Using flatpak for bambu studio because the network plugin constantly crashes
    services.flatpak.enable = true;

    # OrcaSlicer
    #   UDP 1900: Used for SSDP printer discovery on the local network
    #   UDP 5353: Multicast DNS (mDNS) to resolve the printer's local host name
    #   TCP 8883: MQTT secure connection used for printer status and control commands
    #   TCP 990 / range: FTPS incremental streaming/file transfer for sending print jobs.
    networking.firewall = {
      allowedUDPPorts = [1900 5353];
      allowedTCPPorts = [8883 990];
    };
  };
}
