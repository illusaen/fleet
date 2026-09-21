{inputs}: {
  modules.nixos = {
    pkgs,
    fleet,
    user,
    ...
  }: {
    imports = [inputs.umbriel.nixosModules.default];
    programs.umbriel = {
      enable = true;
      package = pkgs.umbriel;
    };

    hjem.users.${user.name}.xdg.config.files."umbriel/config.toml" = {
      generator = (pkgs.formats.toml {}).generate "umbriel-config.toml";
      value = let
        main = fleet.monitors.main;
        general = import ./general.nix {
          inherit main;
          secondary = fleet.monitors.secondary;
          inherit (fleet.theming) cursor;
        };
        rules = import ./rules.nix {inherit main;};
        binds = import ./binds.nix;
      in
        general // rules // binds;
    };
  };
}
