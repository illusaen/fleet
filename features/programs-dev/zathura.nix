{
  modules.nixos = {pkgs, ...}: let
    themeStateDir = "\${NIX_THEME_STATE_DIR:-\${XDG_STATE_HOME:-$HOME/.local/state}/nix-theme}";
  in {
    xdg.mime.defaultApplications = let
      reader = "org.pwmt.zathura.desktop";
    in {
      "application/pdf" = reader;
      "application/epub+zip" = reader;
      "application/postscript" = reader;
    };

    environment.systemPackages = [
      (
        pkgs.symlinkJoin {
          name = "zathura-wrapped";
          paths = [pkgs.zathura];
          nativeBuildInputs = [pkgs.makeWrapper];
          postBuild = ''
            rm -f "$out/bin/zathura"
            makeWrapper ${pkgs.zathura}/bin/zathura "$out/bin/zathura" \
              --add-flags "--config-dir ${themeStateDir}/current/zathura"
          '';
        }
      )
    ];
  };
}
