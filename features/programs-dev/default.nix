{
  imports = [./vscode.nix ./zathura.nix];

  modules.nixos = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [codex inkscape orca-slicer image-roll obsidian];
    xdg.mime.defaultApplications."image/*" = "com.github.weclaw1.ImageRoll.desktop";
    persistUser.directories = [".codex" ".config/OrcaSlicer" ".config/obsidian"];
    systemdAutostart = [{package = pkgs.obsidian;}];

    networking.firewall = {
      extraInputRules = ''
        # Allow Bambu Lab SSDP device discovery (LAN mode)
        udp dport { 1990, 2021 } accept

        # Allow standard IGMP/multicast traffic required for network discovery
        pkttype multicast accept
      '';
    };
  };
}
