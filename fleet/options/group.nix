{lib}: let
  inherit (lib) mkOption;
  inherit (lib.types) str bool submodule listOf;
in
  submodule {
    options = {
      isPosix = mkOption {
        type = bool;
        default = false;
        description = "Whether this group maps to a POSIX group.";
      };

      members = mkOption {
        type = listOf str;
        default = [];
        description = "User group names included in this group.";
      };
    };
  }
