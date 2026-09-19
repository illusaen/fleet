{
  modules.nixos = {
    config,
    host,
    lib,
    helpers,
    fleet,
    ...
  }: let
    service = helpers.requireRoutedService host "pihole";
    secretFile = ../../secrets/hosts/${host.name}/pihole-web-password.age;
    hasSecret = builtins.pathExists secretFile;
    proxy = helpers.reverseProxy fleet;
    proxyHostNames = builtins.attrNames proxy.routes;
  in {
    services = {
      pihole-ftl = {
        enable = true;
        openFirewallDNS = true;
        openFirewallWebserver = true;
        settings = {
          "webserver.api" = {
            cli_pw = true;
            prettyJSON = true;
          };
          dns = {
            inherit (service) port;
            upstreams = ["9.9.9.9" "1.1.1.1" "8.8.8.8"];
            hosts = map (name: "${proxy.address} ${name}") proxyHostNames;
          };
          "dns.domain".name = fleet.domain;
        };
      };
      pihole-web = {
        enable = true;
        hostName = "pihole.${host.name}.${fleet.domain}";
        ports = [service.proxyPort];
      };
    };

    age.secrets.pihole-web-password = lib.mkIf hasSecret {
      file = secretFile;
      owner = "pihole";
      group = "pihole";
    };

    systemd.services.pihole-set-web-password = lib.mkIf hasSecret {
      description = "Set Pi-hole web password from agenix";
      after = ["pihole-ftl.service"];
      requires = ["pihole-ftl.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";
      };
      script = ''
        ${config.services.pihole-ftl.pihole}/bin/pihole setpassword "$(<${config.age.secrets.pihole-web-password.path})"
      '';
    };

    persist.directories = [
      {
        directory = config.services.pihole-ftl.stateDirectory;
        user = "pihole";
        group = "pihole";
        mode = "0700";
      }
      {
        directory = config.services.pihole-ftl.logDirectory;
        user = "pihole";
        group = "pihole";
        mode = "0700";
      }
    ];
  };
}
