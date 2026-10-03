{
  modules.nixos = {
    config,
    fleet,
    host,
    lib,
    pkgs,
    user,
    ...
  }: let
    inherit (fleet) fonts;
    inherit (fleet.theming) cursor gtk icon;

    localThemePackage = theme: pkgs.local.${theme.packageName};

    themeContext = pkgs.writeText "nix-theme-context.json" (builtins.toJSON (let
      inherit (fleet) wallpaper;
      inherit (host.monitors) main secondary;
      inherit (fonts) mono sans serif;
      inherit (user.identity) email accountName displayName;
    in {
      cursor_size = cursor.size;
      cursor_theme = cursor.name;
      icon_theme = icon.name;
      gtk_theme = gtk.name;
      gtk4_theme_directory = "${localThemePackage gtk}/share/libadwaita-themes";

      application_font_size = fonts.sizes.applications;
      terminal_font_size = fonts.sizes.terminal;
      large_font_size = builtins.floor (fonts.sizes.terminal * 1.1);
      mono_font = mono.name;
      sans_font = sans.name;
      serif_font = serif.name;

      inherit email;
      account_name = accountName;
      display_name = displayName;
      ssh_private_key = host.privateKey;
      location = lib.last (lib.splitString "/" fleet.timeZone);

      main_monitor = main.name;
      secondary_monitor = secondary.name;
      main_connector = main.connector;
      secondary_connector = secondary.connector;

      wallpaper_directory = toString wallpaper.directory;
      default_wallpaper = fleet.wallpaper.image;
      prefer_dark = true;
    }));

    themedDots = pkgs.dots.overrideAttrs (oldAttrs: {
      nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [pkgs.makeWrapper];
      postFixup =
        (oldAttrs.postFixup or "")
        + ''
          wrapProgram $out/bin/dots \
            --set NIX_CONFIG_FOLDER ${lib.escapeShellArg "${config.users.users.${user.name}.home}/Projects/fleet/dotfiles"} \
            --set NIX_THEME_CONTEXT ${lib.escapeShellArg themeContext}
        '';
    });
  in {
    environment = {
      systemPackages = [
        (localThemePackage cursor)
        (localThemePackage gtk)
        (localThemePackage icon)
        themedDots
      ];

      sessionVariables = {
        GTK_THEME = gtk.name;
        XCURSOR_SIZE = toString cursor.size;
        XCURSOR_THEME = cursor.name;
      };

      # This is needed even after having ~/.config/gtk-3.0/settings.ini and gtk-4.0
      # because GUI programs running as root and the login screen (which runs under
      # a different user such as greetd) cannot read the user settings.
      etc = let
        gtkIni = lib.generators.toINI {} {
          Settings = {
            gtk-font-name = "${fonts.sans.name} ${toString fonts.sizes.applications}";
            gtk-theme-name = gtk.name;
            gtk-icon-theme-name = icon.name;
            gtk-cursor-theme-name = cursor.name;
            gtk-cursor-theme-size = cursor.size;
          };
        };
      in {
        "xdg/gtk-3.0/settings.ini".text = gtkIni;
        "xdg/gtk-4.0/settings.ini".text = gtkIni;
      };
    };

    programs.dconf = {
      enable = true;
      profiles.user.databases = [
        {
          settings = {
            "org/gnome/desktop/interface" = {
              font-name = "${fonts.sans.name} ${toString fonts.sizes.applications}";
              gtk-theme = gtk.name;
              icon-theme = icon.name;
              cursor-theme = cursor.name;
              cursor-size = lib.gvariant.mkUint32 cursor.size;
            };
            "org/gnome/desktop/wm/preferences"."button-layout" = ":";
          };
        }
      ];
    };

    systemd.services.restore-runtime-theme = {
      description = "Restore runtime theme and dotfile links";
      wantedBy = ["multi-user.target"];
      after = ["local-fs.target"];
      before = ["display-manager.service"];
      serviceConfig = {
        Type = "oneshot";
        User = user.name;
        Environment = "HOME=${config.users.users.${user.name}.home}";
        ExecStart = "${lib.getExe themedDots} --mode link --debug";
      };
    };
  };
}
