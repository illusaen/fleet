{
  modules.nixos = {
    pkgs,
    user,
    fleet,
    ...
  }: {
    services.displayManager.noctalia-greeter = {
      enable = true;
      settings = {
        session.default = "Umbriel";
        user.default = user.name;
        appearance = {
          hide_logo = true;
          power_buttons_position = "hidden";
          scheme_selector_position = "hidden";
          font_family = fleet.fonts.sans.name;
        };
        appearance.palette = {
          primary = "#0e0e43";
          on_primary = "#7c80b4";
          secondary = "#0e0e43";
          on_secondary = "#7c80b4";
          tertiary = "#0e0e43";
          on_tertiary = "#7c80b4";
          error = "#0e0e43";
          on_error = "#FD4663";
          surface = "#0e0e43";
          on_surface = "#f3edf7";
          surface_variant = "#0e0e43";
          on_surface_variant = "#7c80b4";
          outline = "#0e0e43";
          shadow = "#0e0e43";
          hover = "#9BFECE";
          on_hover = "#0e0e43";
        };
        appearance.wallpaper = {
          fill_color = "#0e0e43";
          fill_mode = "fit";
        };
        output.name = fleet.monitors.main;
        cursor.size = fleet.theming.cursor.size;
      };
      cursorTheme = {
        name = fleet.theming.cursor.name;
        package = pkgs.local.${fleet.theming.cursor.packageName};
      };
    };
  };
}
