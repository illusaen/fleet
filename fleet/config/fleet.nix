{
  domain = "home.arpa";
  timeZone = "America/Chicago";

  fonts = {
    sans = {
      name = "Inter";
      packageName = "inter";
    };
    mono = {
      name = "Monaspace Neon NF";
      packageName = "monaspace";
    };
    serif = {
      name = "Monaspace Xenon Frozen";
      packageName = "monaspace";
    };
    emoji = {
      name = "Noto Color Emoji";
      packageName = "noto-fonts-color-emoji";
    };
    icon = {
      name = "Material Symbols Outlined";
      packageName = "material-symbols";
    };
    sizes = {
      terminal = 12;
      applications = 12;
      desktop = 13;
    };
  };

  theming = {
    icon = {
      name = "MacTahoe";
      packageName = "mactahoe-icon-theme";
    };
    cursor = {
      name = "MacTahoe-Cursors";
      packageName = "mactahoe-cursors";
      size = 32;
    };
    gtk = {
      name = "MacTahoe";
      packageName = "mactahoe-gtk-theme";
    };
  };

  themes = let
    dark = map (t: profile t "dark") ["ashes" "ayu-mirage" "chalk" "laser" "tokyo-night-moon"];
    light = map (t: profile t "dark") ["catppuccin-latte"];
    profile = name: colorScheme: {
      inherit name;
      value = {
        inherit colorScheme;
        base16Theme = ../../resources/themes/${name}.yaml;
        wallpaper =
          if (colorScheme == "light")
          then ../../resources/wallpapers/light/light-silk.jpeg
          else ../../resources/wallpapers/dark/dark-silk.jpeg;
      };
    };
  in {
    default = "tokyo-night-moon";
    profiles = (builtins.listToAttrs dark) // (builtins.listToAttrs light);
  };

  base16 = {
    theme = ../../resources/themes/tokyo-night-moon.yaml;
    colorScheme = "dark";
    isDark = true;
  };

  wallpaper = {
    directory = ../../resources/wallpapers;
    image = ../../resources/wallpapers/dark/dark-silk.jpeg;
  };

  monitors = {
    main = "LG Electronics LG ULTRAGEAR+ 508RMWVJR505";
    secondary = "BOE Display 000000001";
  };
}
