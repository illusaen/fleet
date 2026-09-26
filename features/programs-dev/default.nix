{
  imports = [./vscode.nix ./zathura.nix];

  modules.nixos = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [codex inkscape bambu-studio image-roll obsidian];
    xdg.mime.defaultApplications."image/*" = "com.github.weclaw1.ImageRoll.desktop";
    persistUser.directories = [".codex" ".config/BambuStudio"];
  };
}
