{
  lib,
  root,
}: let
  featureLib = import (root + "/lib/feature.nix") {
    inputs = {};
    inherit lib;
  };

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

  features = {
    featuresForHost = {
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
    };

    modulesForHost."test an unknown feature fails with a useful evaluation error" = {
      expr =
        (builtins.tryEval (featureLib.modulesForHost (mkHost {
          features = ["missing"];
        }))).success;
      expected = false;
    };
  };
in
  lib.coverage.addCoverage featureLib features
