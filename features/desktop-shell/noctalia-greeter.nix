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
          font_family = fleet.fonts.sans;
        };
        appearance.palette = {
          primary = "#fff59b";
          on_primary = "#0e0e43";
          secondary = "#a9aefe";
          on_secondary = "#0e0e43";
          tertiary = "#9BFECE";
          on_tertiary = "#0e0e43";
          error = "#FD4663";
          on_error = "#0e0e43";
          surface = "#222436";
          on_surface = "#f3edf7";
          surface_variant = "#222436";
          on_surface_variant = "#7c80b4";
          outline = "#222436";
          shadow = "#222436";
          hover = "#9BFECE";
          on_hover = "#0e0e43";
        };
        "appearance.wallpaper" = {
          fill_color = "#222436";
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
