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
    themeListFile = pkgs.writeText "nix-theme-list" (lib.concatStringsSep "\n" themeNames);

    localThemePackage = theme: pkgs.local.${theme.packageName};

    selectedWallpaper = profile:
      if profile.wallpaper != null
      then profile.wallpaper
      else wallpaper.image;

    themeContext = pkgs.writeText "nix-theme-context.json" (builtins.toJSON {
      static = {
        cursor-size = cursor.size;
        cursor-theme = cursor.name;
        icon-theme = icon.name;
        gtk-theme = gtk.name;
        gtk4-theme-directory = "${localThemePackage gtk}/share/libadwaita-themes";

        application-font-size = sizes.applications;
        terminal-font-size = sizes.terminal;
        larger-font-size = builtins.floor (sizes.terminal * 1.1);
        mono-font = fonts.mono.name;
        sans-font = fonts.sans.name;
        serif-font = fonts.serif.name;

        inherit (user.identity) email;
        account-name = user.identity.accountName;
        display-name = user.identity.displayName;
        ssh-private-key = host.privateKey;
        location = lib.last (lib.splitString "/" fleet.timeZone);

        inherit (fleet.monitors) main secondary;
        main-connector = host.monitors.main;
        secondary-connector = host.monitors.secondary;

        image-directory = toString wallpaper.directory;
        image = fleet.wallpaper.image;
      };
      themes =
        lib.mapAttrs (_name: profile: {
          "color-scheme" =
            if profile.colorScheme == "dark"
            then "prefer-dark"
            else "default";
          "prefer-dark" = lib.boolToString (profile.colorScheme == "dark");
          "qt-color-scheme" = profile.colorScheme;
          wallpaper = toString (selectedWallpaper profile);
        })
        themes.profiles;
    });

    python = pkgs.python3.withPackages (pythonPackages: [
      pythonPackages.pystache
      pythonPackages.pydantic
      pythonPackages.pyyaml
    ]);

    themeApply = pkgs.writeShellApplication {
      name = "theme-apply";
      text = ''
        export NIX_CONFIG_FOLDER="''${NIX_CONFIG_FOLDER:-$HOME/Projects/fleet}"
        export NIX_THEME_CONTEXT=${lib.escapeShellArg themeContext}
        exec ${python}/bin/python ${./runtime_theme.py} "$@"
      '';
    };

    restoreRuntimeTheme = pkgs.writeShellApplication {
      name = "restore-runtime-theme";
      text = ''
        repository="''${NIX_CONFIG_FOLDER:-$HOME/Projects/fleet}"
        selected_file="$repository/dotfiles/built/selected"
        selected=""

        if [[ -r "$selected_file" ]]; then
          IFS= read -r selected < "$selected_file" || true
        fi

        if ! ${lib.getExe pkgs.gnugrep} -Fqx -- "$selected" ${themeListFile}; then
          selected=${lib.escapeShellArg themes.default}
        fi

        exec ${lib.getExe themeApply} "$selected"
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
        theme="$(noctalia dmenu --prompt 'Theme: ' < ${themeListFile})"
        [ -n "$theme" ] || exit 0
        exec theme-apply "$theme"
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

    system.userActivationScripts.restoreRuntimeTheme = ''
      if [ "$USER" = ${lib.escapeShellArg user.name} ]; then
        ${lib.getExe restoreRuntimeTheme}
      fi
    '';

    systemd.services.restore-runtime-theme = {
      description = "Restore runtime theme and dotfile links";
      wantedBy = ["multi-user.target"];
      after = ["local-fs.target"];
      before = ["display-manager.service"];
      serviceConfig = {
        Type = "oneshot";
        User = user.name;
        Environment = "HOME=${config.users.users.${user.name}.home}";
        ExecStart = lib.getExe restoreRuntimeTheme;
      };
    };
  };
}
