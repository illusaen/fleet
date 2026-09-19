{lib}: let
  inherit (lib) mkOption;
  inherit (lib.types) str bool int nullOr submodule listOf;

  identityType = name:
    submodule {
      options = {
        displayName = mkOption {
          type = str;
          default = name;
          description = "Human-readable display name.";
        };

        accountName = mkOption {
          type = str;
          default = name;
          description = "External account name.";
        };

        email = mkOption {
          type = str;
          default = "";
          description = "User email address.";
        };

        sshKeys = mkOption {
          type = listOf sshKeyType;
          default = [];
          description = "SSH public keys for this user.";
        };
      };
    };

  sshKeyType = submodule {
    options = {
      tag = mkOption {
        type = nullOr str;
        default = null;
        description = "Optional label for the SSH key.";
      };

      key = mkOption {
        type = str;
        description = "SSH public key.";
      };
    };
  };

  systemType = submodule {
    options = {
      uid = mkOption {
        type = nullOr int;
        default = null;
        description = "Unix user id.";
      };

      isAdmin = mkOption {
        type = bool;
        default = false;
        description = "Whether this user should have administrative access.";
      };
    };
  };
in
  submodule ({name, ...}: {
    options = {
      name = mkOption {
        type = str;
        default = name;
        readOnly = true;
        description = "Fleet user name.";
      };

      identity = mkOption {
        type = identityType name;
        default = {};
        description = "User identity metadata.";
      };

      groups = mkOption {
        type = listOf str;
        default = [];
        description = "Logical groups this user belongs to.";
      };

      system = mkOption {
        type = systemType;
        default = {};
        description = "System account settings.";
      };
    };
  })
