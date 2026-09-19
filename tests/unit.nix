{
  lib,
  root ? ../.,
}: let
  featureLib = import (root + "/lib/feature.nix") {
    inputs = {};
    inherit lib;
  };
  serviceLib = import (root + "/lib/service.nix") {inherit lib;};

  mkHost = overrides:
    {
      name = "test";
      platform = "nixos";
      tags = [];
      services = [];
      features = [];
      preservation.enable = false;
    }
    // overrides;
in {
  features = {
    "test base and boot are selected for a minimal NixOS host" = {
      expr = featureLib.featuresForHost (mkHost {});
      expected = ["base" "boot"];
    };

    "test tags, preservation, manual features, and services select features" = {
      expr = featureLib.featuresForHost (mkHost {
        tags = ["desktop" "gpu:nvidia" "feature:dev" "feature:gaming"];
        preservation.enable = true;
        features = ["custom"];
        services = [
          {feature = "pihole";}
          {feature = "custom";}
        ];
      });
      expected = [
        "base"
        "boot"
        "programs-core"
        "theming"
        "desktop-shell"
        "nvidia"
        "programs-dev"
        "programs-gaming"
        "preservation"
        "custom"
        "pihole"
      ];
    };

    "test Linux-only features are omitted from Darwin hosts" = {
      expr = featureLib.featuresForHost (mkHost {
        platform = "darwin";
        tags = ["desktop"];
      });
      expected = ["base" "programs-core" "theming"];
    };
  };

  services = let
    hosts = {
      huginn = {
        name = "huginn";
        networkInterfaces.enp1s0.ipv4 = "192.168.1.161/24";
      };
      odin = {
        name = "odin";
        networkInterfaces = {
          eno1.ipv4 = "192.168.1.162/24";
          tailscale0 = {
            ipv4 = "100.64.0.2/32";
            ipv6 = "fd7a:115c:a1e0::2/128";
          };
        };
      };
    };
  in {
    "test hostIps strips CIDR prefixes and filters missing address families" = {
      expr = {
        ipv4 = serviceLib.hostIps "ipv4" hosts.odin;
        ipv6 = serviceLib.hostIps "ipv6" hosts.odin;
      };
      expected = {
        ipv4 = ["192.168.1.162" "100.64.0.2"];
        ipv6 = ["fd7a:115c:a1e0::2"];
      };
    };

    "test primaryIpV4 fails when a host has no IPv4 address" = {
      expr = (builtins.tryEval (serviceLib.primaryIpV4 {name = "offline";})).success;
      expected = false;
    };

    "test servicesForHost assigns primary and backup roles" = let
      services = {
        alpha = {
          primary = "a";
          backups = ["b"];
          port = 1000;
        };
        beta = {
          primary = "b";
          backups = [];
          port = 2000;
        };
        other = {
          primary = "c";
          backups = [];
          port = 3000;
        };
      };
    in {
      expr = serviceLib.servicesForHost "b" services;
      expected = [
        (services.alpha
          // {
            name = "alpha";
            role = "backup";
          })
        (services.beta
          // {
            name = "beta";
            role = "primary";
          })
      ];
    };

    "test requireRoutedService finds a selected service" = let
      service = {
        name = "linkding";
        port = 9090;
      };
    in {
      expr = serviceLib.requireRoutedService {
        name = "huginn";
        services = [service];
      } "linkding";
      expected = service;
    };

    "test requireRoutedService fails for an unselected service" = {
      expr =
        (builtins.tryEval (serviceLib.requireRoutedService {
          name = "huginn";
          services = [];
        } "linkding")).success;
      expected = false;
    };

    "test reverseProxy builds routes from service primary hosts" = {
      expr = serviceLib.reverseProxy {
        domain = "home.arpa";
        inherit hosts;
        services = {
          caddy = {
            primary = "huginn";
            port = 443;
          };
          jellyfin = {
            primary = "huginn";
            port = 8096;
          };
          llama-cpp = {
            primary = "odin";
            port = 8080;
          };
          pihole = {
            primary = "huginn";
            port = 53;
            proxyPort = 8081;
          };
        };
      };
      expected = {
        address = "192.168.1.161";
        routes = {
          "jellyfin.huginn.home.arpa" = {
            serviceName = "jellyfin";
            hostName = "huginn";
            upstream = "192.168.1.161:8096";
          };
          "llama-cpp.odin.home.arpa" = {
            serviceName = "llama-cpp";
            hostName = "odin";
            upstream = "192.168.1.162:8080";
          };
          "pihole.huginn.home.arpa" = {
            serviceName = "pihole";
            hostName = "huginn";
            upstream = "192.168.1.161:8081";
          };
        };
      };
    };
  };
}
