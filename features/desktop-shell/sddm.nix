{inputs}: {
  modules.nixos = {
    fleet,
    host,
    lib,
    pkgs,
    ...
  }: let
    base16Lib = inputs.base16.lib {
      inherit pkgs lib;
    };
    scheme = (base16Lib.mkSchemeAttrs fleet.base16.theme).withHashtag;
    sddmExtraPackages = with pkgs; [
      qt6.qt5compat
      sddmTheme
      weston
    ];
    sddmTheme = pkgs.where-is-my-sddm-theme.override {
      themeConfig.General = {
        background = toString fleet.wallpaper.image;
        passwordCursorColor = scheme.base0D;
      };
    };
  in {
    services = {
      displayManager = {
        enable = true;
        defaultSession = "niri";
        sddm = {
          enable = true;
          enableHidpi = true;
          extraPackages = sddmExtraPackages;
          theme = "${sddmTheme}/share/sddm/themes/where_is_my_sddm_theme";
          wayland = {
            enable = true;
            compositor = "weston";
            compositorCommand = let
              westonIni = (pkgs.formats.ini {}).generate "weston.ini" (
                lib.optionalAttrs ((host.monitors.secondary or null) != null) {
                  output = {
                    name = host.monitors.secondary;
                    mode = "off";
                  };
                }
              );
            in "${lib.getExe pkgs.weston} --shell=kiosk -c ${westonIni}";
          };
        };
      };
    };
  };
}
