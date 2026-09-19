{
  modules.nixos = {
    lib,
    config,
    ...
  }: let
    autostartEntryType = lib.types.submodule ({config, ...}: {
      options = {
        package = lib.mkOption {type = lib.types.package;};
        name = lib.mkOption {
          type = lib.types.str;
          default = lib.getName config.package;
        };
        exec = lib.mkOption {
          type = lib.types.str;
          default = lib.getExe config.package;
        };
      };
    });

    mkAutostartService = entry: {
      wantedBy = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      after = ["graphical-session.target"];
      description = "Autostarts ${entry.name} on login";
      serviceConfig = {
        ExecStart = entry.exec;
        Restart = "on-failure";
      };
    };
  in {
    options.systemdAutostart = lib.mkOption {
      type = lib.types.listOf autostartEntryType;
      default = [];
    };

    config.systemd.user.services =
      builtins.listToAttrs (map (entry: lib.nameValuePair entry.name (mkAutostartService entry)) config.systemdAutostart);
  };
}
