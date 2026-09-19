{
  colmena,
  hostConfigurations,
  lib,
}: let
  # The nodes reuse `configuration.pkgs` below, so prevent Colmena from
  # applying its overlays and Nixpkgs configuration a second time.
  nodeNixpkgs =
    builtins.mapAttrs (
      _name: configuration:
        configuration.pkgs
        // {
          config = {};
          overlays = [];
        }
    )
    hostConfigurations;

  nodeSpecialArgs = builtins.mapAttrs (_name: configuration: configuration.specialArgs) hostConfigurations;

  nodes =
    builtins.mapAttrs (
      _name: configuration:
        configuration.modules
        ++ [
          {
            nixpkgs = {
              inherit (configuration) pkgs;
              flake.source = builtins.path {
                path = configuration.pkgs.path;
                name = "source";
              };
            };

            deployment = {
              allowLocalDeployment = configuration.host.localDeploymentOnly;
              targetHost =
                if configuration.host.localDeploymentOnly
                then null
                else configuration.host.targetHost;
              tags = configuration.host.tags;
            };
          }
        ]
    )
    hostConfigurations;
in
  colmena.lib.makeHive (
    {
      meta = {
        nixpkgs = hostConfigurations.odin.pkgs;
        inherit nodeNixpkgs nodeSpecialArgs;
        specialArgs = {inherit lib;};
      };
    }
    // nodes
  )
