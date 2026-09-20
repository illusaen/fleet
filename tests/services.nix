{
  lib,
  root,
}: let
  serviceLib = import (root + "/lib/service.nix") {inherit lib;};

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
    hostIps = {
      "test strips CIDR prefixes and filters missing address families" = {
        expr = {
          ipv4 = serviceLib.hostIps "ipv4" hosts.odin;
          ipv6 = serviceLib.hostIps "ipv6" hosts.odin;
        };
        expected = {
          ipv4 = ["192.168.1.162" "100.64.0.2"];
          ipv6 = ["fd7a:115c:a1e0::2"];
        };
      };
    };

    primaryIpV4 = {
      "test fails when a host has no IPv4 address" = {
        expr = (builtins.tryEval (serviceLib.primaryIpV4 {name = "offline";})).success;
        expected = false;
      };
    };

    servicesForHost = {
      "test assigns primary and backup roles" = let
        serviceDefinitions = {
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
        expr = serviceLib.servicesForHost "b" serviceDefinitions;
        expected = [
          (serviceDefinitions.alpha
            // {
              name = "alpha";
              role = "backup";
            })
          (serviceDefinitions.beta
            // {
              name = "beta";
              role = "primary";
            })
        ];
      };
    };

    requireRoutedService = {
      "test finds a selected service" = let
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

      "test fails for an unselected service" = {
        expr =
          (builtins.tryEval (serviceLib.requireRoutedService {
            name = "huginn";
            services = [];
          } "linkding")).success;
        expected = false;
      };
    };

    reverseProxy = {
      "test builds routes from service primary hosts" = {
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
  };
in
  lib.coverage.addCoverage serviceLib services
