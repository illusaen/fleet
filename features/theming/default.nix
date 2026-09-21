_: {
  modules.nixos = {
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
    localThemePackage = theme: pkgs.local.${theme.packageName};
    themeNames = builtins.attrNames themes.profiles;
    themeListFile = pkgs.writeText "nix-theme-list" (lib.concatStringsSep "\n" themeNames);
    themeListJson = builtins.toJSON themeNames;

    gtkSettings = {
      gtk-font-name = "${sans.name} ${toString sizes.applications}";
      gtk-theme-name = gtk.name;
      gtk-icon-theme-name = icon.name;
      gtk-cursor-theme-name = cursor.name;
      gtk-cursor-theme-size = cursor.size;
    };
    gtkIni = lib.generators.toINI {} {Settings = gtkSettings;};

    selectedWallpaper = profile:
      if profile.wallpaper != null
      then profile.wallpaper
      else wallpaper.image;

    secondaryMonitor =
      if (host.monitors.secondary or null) != null
      then host.monitors.secondary
      else host.monitors.main;

    mkNoctaliaConfig = profile:
      builtins.replaceStrings
      [
        "@mono@"
        "@sans@"
        "@main@"
        "@secondary@"
        "@image@"
        "@imageDirectory@"
        "@location@"
        ''mode   = "dark"''
      ]
      [
        fonts.mono.name
        fonts.sans.name
        host.monitors.main
        secondaryMonitor
        (toString (selectedWallpaper profile))
        (toString wallpaper.directory)
        (lib.last (lib.splitString "/" fleet.timeZone))
        ''mode   = "${profile.colorScheme}"''
      ]
      (builtins.readFile ../../resources/templates/noctalia/noctalia-config.toml.template);

    themeContext = pkgs.writeText "nix-theme-context.json" (builtins.toJSON {
      static = {
        "application-font-size" = sizes.applications;
        "cursor-size" = cursor.size;
        "cursor-theme" = cursor.name;
        "gtk-theme" = gtk.name;
        "gtk4-theme-directory" = "${localThemePackage gtk}/share/libadwaita-themes";
        "icon-theme" = icon.name;
        "mono-font" = fonts.mono.name;
        "sans-font" = fonts.sans.name;
        "terminal-font-size" = sizes.terminal;
      };
      themes =
        lib.mapAttrs (_name: profile: {
          "color-scheme" =
            if profile.colorScheme == "dark"
            then "prefer-dark"
            else "default";
          "noctalia-config" = mkNoctaliaConfig profile;
          "prefer-dark" = lib.boolToString (profile.colorScheme == "dark");
          "qt-color-scheme" = profile.colorScheme;
          wallpaper = toString (selectedWallpaper profile);
        })
        themes.profiles;
    });

    python = pkgs.python3.withPackages (pythonPackages: [
      pythonPackages.pystache
      pythonPackages.pyyaml
    ]);

    themeApply = pkgs.writeShellApplication {
      name = "theme-apply";
      runtimeInputs = [
        pkgs.difftastic
        pkgs.glib
        pkgs.systemd
      ];
      text = ''
        export NIX_CONFIG_FOLDER="''${NIX_CONFIG_FOLDER:-$HOME/Projects/fleet}"
        export NIX_THEME_CONTEXT=${lib.escapeShellArg themeContext}
        exec ${python}/bin/python ${./runtime_theme.py} "$@"
      '';
    };

    themeList = pkgs.writeShellApplication {
      name = "theme-list";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        set -euo pipefail
        if [ "''${1:-}" = "--json" ]; then
          printf '%s\n' ${lib.escapeShellArg themeListJson}
          exit 0
        fi
        cat ${themeListFile}
      '';
    };

    themeCurrent = pkgs.writeShellApplication {
      name = "theme-current";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        set -euo pipefail
        repository="''${NIX_CONFIG_FOLDER:-$HOME/Projects/fleet}"
        selected="$repository/dotfiles/built/selected"
        if [ -s "$selected" ]; then
          cat "$selected"
          exit 0
        fi
        exit 1
      '';
    };

    themeCycle = pkgs.writeShellApplication {
      name = "theme-cycle";
      runtimeInputs = [
        pkgs.coreutils
        themeApply
        themeCurrent
      ];
      text = ''
        set -euo pipefail
        direction="''${1:-next}"
        current="$(theme-current 2>/dev/null || true)"
        first=""
        previous=""
        selected=""

        while IFS= read -r theme; do
          [ -n "$theme" ] || continue
          [ -n "$first" ] || first="$theme"
          if [ "$direction" = "previous" ] || [ "$direction" = "prev" ]; then
            if [ "$theme" = "$current" ]; then
              selected="$previous"
              break
            fi
            previous="$theme"
          else
            if [ "$previous" = "$current" ]; then
              selected="$theme"
              break
            fi
            previous="$theme"
          fi
        done < ${themeListFile}

        if [ -z "$selected" ]; then
          if [ "$direction" = "previous" ] || [ "$direction" = "prev" ]; then
            selected="$previous"
          else
            selected="$first"
          fi
        fi

        exec theme-apply "$selected"
      '';
    };

    themeSelect = pkgs.writeShellApplication {
      name = "theme-select";
      runtimeInputs = [
        pkgs.fuzzel
        themeApply
      ];
      text = ''
        set -euo pipefail
        theme="$(fuzzel --dmenu --prompt 'Theme: ' < ${themeListFile})"
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
        themeCurrent
        themeCycle
        themeList
        themeSelect
      ];

      sessionVariables = {
        BAT_CONFIG_DIR = "$HOME/.config/bat";
        GTK_THEME = gtk.name;
        QT_QPA_PLATFORMTHEME = "qt6ct";
        XCURSOR_SIZE = toString cursor.size;
        XCURSOR_THEME = cursor.name;
      };

      etc = {
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

    system.userActivationScripts.initializeRuntimeTheme = ''
      if [ "$USER" = ${lib.escapeShellArg user.name} ]; then
        ${lib.getExe themeApply} ${lib.escapeShellArg themes.default}
      fi
    '';
  };
}
