{
  modules.nixos = {lib, ...}: let
    inherit (lib) mkOption optionalAttrs;
    inherit (lib.types) attrsOf bool either listOf str submodule;
    withOptionsType = attrsOf (either bool str);
    mkPersistList = description:
      mkOption {
        type = listOf (either str withOptionsType);
        default = [];
        apply = lib.unique;
        inherit description;
      };
    mkPersistOption = withMountOptions: description:
      mkOption {
        type = submodule {
          options =
            {
              directories = mkPersistList "List of directories";
              files = mkPersistList "List of files";
            }
            // optionalAttrs withMountOptions {
              commonMountOptions = mkOption {
                type = listOf str;
                default = [];
              };
            };
        };
        inherit description;
      };
  in {
    options = {
      persist = mkPersistOption false "Persistent root directories/files";
      persistUser = mkPersistOption true "Persistent user directories/files";
      ignored = mkPersistOption false "Ignored root directories/files used in find ephem";
      ignoredUser = mkPersistOption false "Ignored user directories/files used in find ephem";
    };

    config = {
      persist = {
        directories = [
          "/var/log"
          "/var/lib/systemd/timers"
          "/var/lib/systemd/rfkill"
          "/var/lib/systemd/coredump"
          {
            directory = "/var/lib/nixos";
            inInitrd = true;
          }
        ];
        files = [
          {
            file = "/etc/machine-id";
            inInitrd = true;
          }
          {
            file = "/var/lib/systemd/random-seed";
            how = "symlink";
            inInitrd = true;
            configureParent = true;
          }
        ];
      };

      persistUser = {
        commonMountOptions = [
          "x-gvfs-hide"
          "x-gvfs-trash"
        ];
        directories = [
          {
            directory = ".local/share/keyrings";
            mode = "0700";
          }
          "Downloads"
          "Projects"
          "Pictures"
        ];
      };
    };
  };
}
