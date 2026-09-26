{inputs}: {
  modules.nixos = {
    pkgs,
    user,
    fleet,
    host,
    ...
  }: {
    imports = [inputs.noctalia-greeter.nixosModules.default];

    # Enables gnome keyring and allows Noctalia/Noctalia greeter to unlock keyring
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.login.enableGnomeKeyring = true;
    security.pam.services.greetd.enableGnomeKeyring = true;

    # programs.noctalia-greeter.passwordless-sync-users = {};

    services.displayManager.noctalia-greeter = {
      enable = true;
      package = pkgs.noctalia-greeter;
      passwordless-sync-users = [user.name];
      settings = {
        session.default = "Umbriel";
        user.default = user.name;
        appearance = {
          hide_logo = true;
          power_buttons_position = "hidden";
          scheme_selector_position = "hidden";
          font_family = fleet.fonts.sans.name;
        };
        output.name = host.monitors.main.name;
        cursor = with fleet.theming.cursor; {
          theme = name;
          inherit size;
        };
      };
      cursorTheme.package = pkgs.local.${fleet.theming.cursor.packageName};
    };
  };
}
