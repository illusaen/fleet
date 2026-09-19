{
  modules.nixos = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [nautilus libheif];
    environment.pathsToLink = ["share/thumbnailers"];
    nixpkgs.overlays = [
      (_final: prev: {
        nautilus = prev.nautilus.overrideAttrs (nprev: {
          buildInputs =
            nprev.buildInputs
            ++ (with prev.gst_all_1; [
              gst-plugins-good
              gst-plugins-bad
            ]);
        });
      })
    ];

    programs.nautilus-open-any-terminal = {
      enable = true;
      terminal = "alacritty";
    };

    services = {
      gvfs.enable = true;
      udisks2.enable = true;
      gnome.sushi.enable = true;
    };
  };
}
