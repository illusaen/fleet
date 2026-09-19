{lib}: let
  inherit (lib) mkOption;
  inherit (lib.types) str port submodule listOf;
in
  submodule ({
    name,
    config,
    ...
  }: {
    options = {
      name = mkOption {
        type = str;
        default = name;
        description = "Service name";
        readOnly = true;
      };

      feature = mkOption {
        type = str;
        default = name;
        description = "Feature enabled by this service.";
      };

      primary = mkOption {
        type = str;
        description = "Primary host for this service.";
      };

      backups = mkOption {
        type = listOf str;
        default = [];
        description = "Backup hosts for this service.";
      };

      port = mkOption {
        type = port;
        description = "Service port.";
      };

      proxyPort = mkOption {
        type = port;
        default = config.port;
        description = "HTTP port used by the central reverse proxy.";
      };
    };
  })
