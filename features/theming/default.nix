{inputs}: {
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
    profileStateDir = "\${XDG_STATE_HOME:-$HOME/.local/state}/nix-theme";
    base16Lib = inputs.base16.lib {
      inherit pkgs lib;
    };
    themeNames = builtins.attrNames themes.profiles;
    themeListFile = pkgs.writeText "nix-theme-list" (lib.concatStringsSep "\n" themeNames);
    themeListJson = builtins.toJSON themeNames;

    toGtkIni = lib.generators.toINI {
      mkKeyValue = key: value: let
        rendered =
          if lib.isBool value
          then lib.boolToString value
          else toString value;
      in "${lib.escape ["="] key}=${rendered}";
    };

    mkGtkIni = profile:
      toGtkIni {
        Settings = lib.filterAttrs (_name: value: value != null) {
          gtk-font-name = "${sans.name} ${toString sizes.applications}";
          gtk-theme-name = gtk.name;
          gtk-icon-theme-name = icon.name;
          gtk-cursor-theme-name = cursor.name;
          gtk-cursor-theme-size = cursor.size;
          gtk-application-prefer-dark-theme =
            if profile.colorScheme == "dark"
            then true
            else null;
        };
      };

    gtkSettings = {
      gtk-font-name = "${sans.name} ${toString sizes.applications}";
      gtk-theme-name = gtk.name;
      gtk-icon-theme-name = icon.name;
      gtk-cursor-theme-name = cursor.name;
      gtk-cursor-theme-size = cursor.size;
    };
    gtkIni = lib.generators.toINI {} {Settings = gtkSettings;};

    mkQtctConf = profile:
      pkgs.writeText "qtct.conf" ''
        [Appearance]
        color_scheme_path=${profile.colorScheme}.conf
        custom_palette=false
        icon_theme=${icon.name}
        standard_dialogs=default
        style=Fusion

        [Fonts]
        fixed="${fonts.mono.name},${toString sizes.applications},-1,5,50,0,0,0,0,0"
        general="${sans.name},${toString sizes.applications},-1,5,50,0,0,0,0,0"
      '';

    mkAlacrittyToml = scheme:
      pkgs.writeText "alacritty.toml" ''
        [window]
        padding = { x = 32, y = 32 }
        dynamic_padding = true
        opacity = 0.9
        blur = true

        [selection]
        save_to_clipboard = true

        [font]
        size = ${toString sizes.terminal}

        [font.normal]
        family = "${fonts.mono.name}"

        [colors.primary]
        foreground = "${scheme.withHashtag.base05}"
        background = "${scheme.withHashtag.base00}"
        bright_foreground = "${scheme.withHashtag.base07}"

        [colors.normal]
        black = "${scheme.withHashtag.base00}"
        red = "${scheme.withHashtag.red}"
        green = "${scheme.withHashtag.green}"
        yellow = "${scheme.withHashtag.yellow}"
        blue = "${scheme.withHashtag.blue}"
        magenta = "${scheme.withHashtag.magenta}"
        cyan = "${scheme.withHashtag.cyan}"
        white = "${scheme.withHashtag.base05}"

        [colors.bright]
        black = "${scheme.withHashtag.base03}"
        red = "${scheme.withHashtag.bright-red}"
        green = "${scheme.withHashtag.bright-green}"
        yellow = "${scheme.withHashtag.bright-yellow}"
        blue = "${scheme.withHashtag.bright-blue}"
        magenta = "${scheme.withHashtag.bright-magenta}"
        cyan = "${scheme.withHashtag.bright-cyan}"
        white = "${scheme.withHashtag.base07}"
      '';

    mkZathurarc = scheme:
      pkgs.writeText "zathurarc" ''
        set font "monospace normal ${toString sizes.applications}"
        set default-bg "${scheme.withHashtag.base00}"
        set default-fg "${scheme.withHashtag.base01}"
        set statusbar-fg "${scheme.withHashtag.base04}"
        set statusbar-bg "${scheme.withHashtag.base02}"
        set inputbar-bg "${scheme.withHashtag.base00}"
        set inputbar-fg "${scheme.withHashtag.base07}"
        set recolor-lightcolor "${scheme.withHashtag.base00}"
        set recolor-darkcolor "${scheme.withHashtag.base06}"
      '';

    mkNiriColors = scheme:
      pkgs.replaceVars ../desktop-shell/niri/niri-colors.kdl {
        inherit (scheme) base00 base02 base03 base08 base12 base15 base0C base0D;
      };

    mkProfileLinkCommands = files:
      lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          target: source: ''ln -sfn ${lib.escapeShellArg source} "$out/${target}"''
        )
        files
      );

    mkProfile = name: profile: let
      scheme = base16Lib.mkSchemeAttrs profile.base16Theme;
      selectedWallpaper =
        if profile.wallpaper != null
        then profile.wallpaper
        else wallpaper.image;
      profileFiles = {
        "env" = pkgs.writeText "theme-env" ''
          THEME_NAME=${lib.escapeShellArg name}
          COLOR_SCHEME=${lib.escapeShellArg (
            if profile.colorScheme == "dark"
            then "prefer-dark"
            else "default"
          )}
          GTK_THEME=${lib.escapeShellArg gtk.name}
          ICON_THEME=${lib.escapeShellArg icon.name}
          CURSOR_THEME=${lib.escapeShellArg cursor.name}
          CURSOR_SIZE=${lib.escapeShellArg (toString cursor.size)}
          WALLPAPER=${lib.escapeShellArg (toString selectedWallpaper)}
        '';
        "alacritty/alacritty.toml" = mkAlacrittyToml scheme;
        "bat/config" = pkgs.writeText "bat-config" ''
          --theme="Base16"
          --italic-text=always
        '';
        "bat/themes/Base16.tmTheme" = scheme {
          template = ../../resources/templates/bat/bat.tmTheme.mustache;
          extension = ".tmTheme";
        };
        "gtk-3.0/settings.ini" = pkgs.writeText "gtk-settings.ini" (mkGtkIni profile);
        "gtk-4.0/settings.ini" = pkgs.writeText "gtk-settings.ini" (mkGtkIni profile);
        "noctalia/config.toml" = pkgs.replaceVars ../../resources/templates/noctalia/noctalia-config.toml.template {
          mono = fonts.mono.name;
          sans = fonts.sans.name;
          main = host.monitors.main;
          secondary =
            if (host.monitors.secondary or null) != null
            then host.monitors.secondary
            else host.monitors.main;
          image = selectedWallpaper;
          imageDirectory = wallpaper.directory;
          location = lib.last (lib.splitString "/" fleet.timeZone);
        };
        "niri-colors.kdl" = mkNiriColors scheme;
        "qt5ct/qt5ct.conf" = mkQtctConf profile;
        "qt6ct/qt6ct.conf" = mkQtctConf profile;
        "zathura/zathurarc" = mkZathurarc scheme;
      };
    in
      pkgs.runCommand "nix-theme-profile-${name}" {} ''
        mkdir -p "$out/alacritty" "$out/bat/themes" "$out/gtk-3.0" "$out/gtk-4.0" "$out/noctalia" "$out/qt5ct" "$out/qt6ct" "$out/zathura"
        cp -rs ${lib.escapeShellArg "${localThemePackage gtk}/share/libadwaita-themes"}/* "$out/gtk-4.0/" 2>/dev/null || true
        ${mkProfileLinkCommands profileFiles}
      '';

    profilesPackage = pkgs.linkFarm "nix-theme-profiles" (
      lib.mapAttrsToList (name: path: {inherit name path;}) (lib.mapAttrs mkProfile themes.profiles)
    );

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
        state_dir="${profileStateDir}"
        selected="$state_dir/selected"
        if [ -s "$selected" ]; then
          cat "$selected"
          exit 0
        fi
        if [ -e "$state_dir/current" ]; then
          basename "$(readlink -f "$state_dir/current")"
          exit 0
        fi
        exit 1
      '';
    };

    themeApply = pkgs.writeShellApplication {
      name = "theme-apply";
      runtimeInputs = with pkgs; [
        coreutils
        dconf
        glib
        gnugrep
        gnused
      ];
      text = ''
        set -euo pipefail

        dry_run=0
        if [ "''${1:-}" = "--dry-run" ]; then
          dry_run=1
          shift
        fi

        theme="''${1:-${themes.default}}"
        state_dir="${profileStateDir}"
        profile_root="''${NIX_THEME_PROFILE_DIR:-${profilesPackage}}"
        profile="$profile_root/$theme"

        if [ ! -d "$profile" ]; then
          echo "Unknown theme: $theme" >&2
          echo "Available themes:" >&2
          sed 's/^/  /' ${themeListFile} >&2
          exit 1
        fi

        if [ "$dry_run" = 1 ]; then
          echo "theme=$theme"
          echo "profile=$profile"
          echo "state_dir=$state_dir"
          exit 0
        fi

        mkdir -p "$state_dir"
        ln -sfn "$profile" "$state_dir/current.next"
        mv -Tf "$state_dir/current.next" "$state_dir/current"
        ln -sfn "$state_dir/current/niri-colors.kdl" "$state_dir/niri-colors.kdl.next"
        mv -Tf "$state_dir/niri-colors.kdl.next" "$state_dir/niri-colors.kdl"
        printf '%s\n' "$theme" > "$state_dir/selected"

        # shellcheck disable=SC1091
        . "$profile/env"

        mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/qt5ct" "$HOME/.config/qt6ct"
        ln -sfn "$state_dir/current/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
        rm -rf "$HOME/.config/gtk-4.0"
        ln -sfn "$state_dir/current/gtk-4.0" "$HOME/.config/gtk-4.0"
        ln -sfn "$state_dir/current/qt5ct/qt5ct.conf" "$HOME/.config/qt5ct/qt5ct.conf"
        ln -sfn "$state_dir/current/qt6ct/qt6ct.conf" "$HOME/.config/qt6ct/qt6ct.conf"

        if command -v gsettings >/dev/null 2>&1 && gsettings list-schemas 2>/dev/null | grep -qx org.gnome.desktop.interface; then
          gsettings set org.gnome.desktop.interface color-scheme "$COLOR_SCHEME" || true
          gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" || true
          gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" || true
          gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME" || true
          gsettings set org.gnome.desktop.interface cursor-size "uint32 $CURSOR_SIZE" || true
        fi

        if command -v systemctl >/dev/null 2>&1; then
          systemctl --user try-restart noctalia.service waybar.service 2>/dev/null || true
        fi
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
        profilesPackage
        themeApply
        themeCurrent
        themeCycle
        themeList
        themeSelect
      ];

      sessionVariables = {
        BAT_CONFIG_DIR = "${profileStateDir}/current/bat";
        GTK_THEME = gtk.name;
        NIX_THEME_STATE_DIR = profileStateDir;
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
