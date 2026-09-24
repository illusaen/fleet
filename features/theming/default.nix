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
    inherit (fleet) fonts themes wallpaper;
    inherit (fleet.fonts) sans sizes;
    inherit (fleet.theming) cursor gtk icon;
    themeNames = builtins.attrNames themes.profiles;

    localThemePackage = theme: pkgs.local.${theme.packageName};

    themeContext = pkgs.writeText "nix-theme-context.json" (builtins.toJSON {
      cursor_size = cursor.size;
      cursor_theme = cursor.name;
      icon_theme = icon.name;
      gtk_theme = gtk.name;
      gtk4_theme_directory = "${localThemePackage gtk}/share/libadwaita-themes";

      application_font_size = sizes.applications;
      terminal_font_size = sizes.terminal;
      larger_font_size = builtins.floor (sizes.terminal * 1.1);
      mono_font = fonts.mono.name;
      sans_font = fonts.sans.name;
      serif_font = fonts.serif.name;

      inherit (user.identity) email;
      account_name = user.identity.accountName;
      display_name = user.identity.displayName;
      ssh_private_key = host.privateKey;
      location = lib.last (lib.splitString "/" fleet.timeZone);

      inherit (fleet.monitors) main secondary;
      main_connector = host.monitors.main;
      secondary_connector = host.monitors.secondary;

      image_directory = toString wallpaper.directory;
      default_image = fleet.wallpaper.image;
    });

    themeApply = pkgs.writeShellApplication {
      name = "theme-apply";
      text = ''
        export NIX_CONFIG_FOLDER="''${NIX_CONFIG_FOLDER:-$HOME/Projects/fleet}"
        export NIX_THEME_CONTEXT=${lib.escapeShellArg themeContext}
        exec ${pkgs.pydot}/bin/pydot --root "$NIX_CONFIG_FOLDER/dotfiles" "$@"
      '';
    };

    themeSelect = pkgs.writeShellApplication {
      name = "theme-select";
      runtimeInputs = [
        pkgs.noctalia
        themeApply
      ];
      text = ''
        set -euo pipefail
        theme="$(printf '%s\n' ${lib.escapeShellArgs themeNames} | noctalia dmenu --prompt 'Theme: ')"
        [ -n "$theme" ] || exit 0
        exec theme-apply -t "$theme"
      '';
    };
  in {
    environment = {
      systemPackages = [
        (localThemePackage cursor)
        (localThemePackage gtk)
        (localThemePackage icon)
        themeApply
        themeSelect
      ];

      sessionVariables = {
        GTK_THEME = gtk.name;
        QT_QPA_PLATFORMTHEME = "qt6ct";
        XCURSOR_SIZE = toString cursor.size;
        XCURSOR_THEME = cursor.name;
      };

      # This is needed even after having ~/.config/gtk-3.0/settings.ini and gtk-4.0
      # because GUI programs running as root and the login screen (which runs under
      # a different user such as greetd) cannot read the user settings.
      etc = let
        gtkIni = lib.generators.toINI {} {
          Settings = {
            gtk-font-name = "${sans.name} ${toString sizes.applications}";
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
              color-scheme =
                if fleet.base16.isDark
                then "prefer-dark"
                else "default";
              font-name = "${sans.name} ${toString sizes.applications}";
              gtk-theme = gtk.name;
              icon-theme = icon.name;
              cursor-theme = cursor.name;
              cursor-size = lib.gvariant.mkUint32 cursor.size;
            };
            "org/gnome/desktop/wm/preferences"."button-layout" = "close:";
          };
        }
      ];
    };

    system.userActivationScripts.cacheBat = {
      text = ''
        echo "Building bat cache."
        ${pkgs.bat}/bin/bat cache --build
      '';
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
        ExecStart = lib.getExe themeApply;
      };
    };
  };
}
