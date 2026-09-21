{
  domain = "home.arpa";
  timeZone = "America/Chicago";

  hosts = import ./hosts.nix;
  users = import ./users.nix;
  groups = import ./groups.nix;
  services = import ./services.nix;

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

  themes = {
    default = "tokyo-night-moon";
    profiles = {
      tokyo-night-moon = {
        colorScheme = "dark";
        base16Theme = ../../resources/themes/tokyo-night-moon.yaml;
        wallpaper = ../../resources/wallpapers/dark/dark-silk.jpeg;
      };
      catppuccin-latte = {
        colorScheme = "light";
        base16Theme = ../../resources/themes/catppuccin-latte.yaml;
        wallpaper = ../../resources/wallpapers/light/light-silk.jpeg;
      };
    };
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
