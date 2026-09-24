{
  modules.nixos = {
    pkgs,
    user,
    fleet,
    host,
    ...
  }: {
    # Enables gnome keyring and allows Noctalia/Noctalia greeter to unlock keyring
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.login.enableGnomeKeyring = true;
    security.pam.services.greetd.enableGnomeKeyring = true;

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
          primary = "#000000";
          on_primary = "#7c80b4";
          secondary = "#000000";
          on_secondary = "#000000";
          tertiary = "#000000";
          on_tertiary = "#000000";
          error = "#000000";
          on_error = "#FD4663";
          surface = "#000000";
          on_surface = "#f3edf7";
          surface_variant = "#000000";
          on_surface_variant = "#000000";
          outline = "#000000";
          shadow = "#000000";
          hover = "#9BFECE";
          on_hover = "#000000";
        };
        appearance.wallpaper = {
          fill_color = "#000000";
          fill_mode = "fit";
        };
        output.name = host.monitors.main.name;
        cursor.size = fleet.theming.cursor.size;
      };
      cursorTheme = {
        name = fleet.theming.cursor.name;
        package = pkgs.local.${fleet.theming.cursor.packageName};
      };
    };
  };
}
