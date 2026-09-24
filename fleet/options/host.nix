{lib}: let
  inherit (lib) mkOption;
  inherit (lib.types) str bool int enum path either nullOr submodule attrsOf listOf;
  supportedSystems = import ../../flake/systems.nix;

  networkInterfaceType = submodule {
    options = {
      ipv4 = mkOption {
        type = nullOr str;
        default = null;
        description = "IPv4 address in CIDR notation.";
      };

      ipv6 = mkOption {
        type = nullOr str;
        default = null;
        description = "IPv6 address in CIDR notation.";
      };
    };
  };

  preservationType = submodule {
    options = {
      enable = mkOption {
        type = bool;
        default = false;
        description = "Whether this host uses persistent state via preservation.";
      };

      disk = mkOption {
        type = nullOr str;
        default = null;
        description = "Disk used by disko when preservation is enabled.";
      };

      rootSnapshot = mkOption {
        type = str;
        default = "zroot/local/root@blank";
        description = "ZFS ephemeral snapshot used to wipe root.";
      };

      homeSnapshot = mkOption {
        type = str;
        default = "zroot/local/home@blank";
        description = "ZFS ephemeral snapshot used to wipe home.";
      };

      persistMount = mkOption {
        type = str;
        default = "/persist";
        description = "Mount point for persisted state.";
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
        description = "Fleet host name.";
      };

      system = mkOption {
        type = enum supportedSystems;
        description = "Nix system identifier.";
      };

      platform = mkOption {
        type = enum ["nixos"];
        default = "nixos";
        readOnly = true;
        description = "Host configuration platform derived from system.";
      };

      owner = mkOption {
        type = str;
        description = "Primary fleet user for this host.";
      };

      targetHost = mkOption {
        type = str;
        description = "SSH target for this host.";
      };

      localDeploymentOnly = mkOption {
        type = bool;
        default = false;
        description = "Whether this host may only be deployed locally.";
      };

      maxJobs = mkOption {
        type = either int str;
        default = "auto";
        description = "Max number of packages to build in parallel.";
      };

      cores = mkOption {
        type = int;
        default = 0;
        description = "Number of cores used to build.";
      };

      hostId = mkOption {
        type = nullOr str;
        default = null;
        description = "NixOS networking.hostId value.";
      };

      privateKey = mkOption {
        type = str;
        default = "/etc/ssh/host_ed25519";
        description = "Path to this host's SSH private key.";
      };

      publicKey = mkOption {
        type = path;
        default = ../../secrets/hosts + "/${name}/host_ed25519.pub";
        description = "Path to this host's SSH public key.";
      };

      features = mkOption {
        type = listOf str;
        default = [];
        description = "Manual feature names for this host.";
      };

      tags = mkOption {
        type = listOf str;
        default = [];
        description = "Host tags used for deploy selectors and derived features.";
      };

      networkInterfaces = mkOption {
        type = attrsOf networkInterfaceType;
        default = {};
        description = "Static network interfaces.";
      };

      monitors = mkOption {
        type = attrsOf str;
        default = {};
        description = "Named monitor connector mappings.";
      };

      preservation = mkOption {
        type = preservationType;
        default = {};
        description = "Preservation settings.";
      };
    };
  })
