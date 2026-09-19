{lib}: let
  inherit (lib) mkOption;
  inherit (lib.types) str attrsOf attrs;

  groupType = import ./group.nix {inherit lib;};
  hostType = import ./host.nix {inherit lib;};
  serviceType = import ./service.nix {inherit lib;};
  userType = import ./user.nix {inherit lib;};
in {
  options.fleet = {
    domain = mkOption {
      type = str;
      description = "Base domain for the fleet.";
    };

    timeZone = mkOption {
      type = str;
      default = "America/Chicago";
      description = "Default timezone for the fleet.";
    };

    hosts = mkOption {
      type = attrsOf hostType;
      default = {};
      description = "Fleet hosts.";
    };

    users = mkOption {
      type = attrsOf userType;
      default = {};
      description = "Fleet users.";
    };

    groups = mkOption {
      type = attrsOf groupType;
      default = {};
      description = "Fleet groups.";
    };

    services = mkOption {
      type = attrsOf serviceType;
      default = {};
      description = "Fleet services.";
    };

    fonts = mkOption {
      type = attrs;
      default = {};
      description = "Fleet font settings.";
    };

    theming = mkOption {
      type = attrs;
      default = {};
      description = "Fleet theming settings.";
    };

    themes = mkOption {
      type = attrs;
      default = {};
      description = "Runtime theme profiles.";
    };

    base16 = mkOption {
      type = attrs;
      default = {};
      description = "Default base16 theme settings.";
    };

    wallpaper = mkOption {
      type = attrs;
      default = {};
      description = "Default wallpaper settings.";
    };
  };
}
