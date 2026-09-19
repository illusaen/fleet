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
    };
  };
}
