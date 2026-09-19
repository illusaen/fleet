{
  modules.generic = {
    fleet,
    pkgs,
    ...
  }: {
    nix.settings = {
      abort-on-warn = true;
      accept-flake-config = true;
      auto-optimise-store = true;
      experimental-features = ["nix-command" "flakes"];
      warn-dirty = false;
      use-xdg-base-directories = true;
      trusted-users = ["@wheel"];
      extra-substituters = [
        "https://cache.nixos-cuda.org"
        "https://nix-community.cachix.org"
        "https://nixpkgs-unfree.cachix.org"
        "https://illusaen.cachix.org"
      ];
      extra-trusted-public-keys = [
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
        "illusaen.cachix.org-1:fxa0K6z978YmVBWgy58TJp8qnw2XxWjC997ArJzzuxk="
      ];
    };

    time.timeZone = fleet.timeZone;

    nix.package = pkgs.lixPackageSets.latest.lix;
    nixpkgs.overlays = [
      (_final: prev: {
        inherit
          (prev.lixPackageSets.latest)
          nixpkgs-review
          nix-eval-jobs
          nix-fast-build
          colmena
          ;
      })
    ];

    security.sudo.extraConfig = ''
      Defaults lecture = never
    '';
  };

  modules.nixos = {
    security.sudo-rs = {
      enable = true;
      wheelNeedsPassword = false;
    };
  };
}
