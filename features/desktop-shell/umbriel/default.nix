{inputs}: {
  modules.nixos = {
    pkgs,
    fleet,
    host,
    user,
    ...
  }: {
    imports = [inputs.umbriel.nixosModules.default];
    programs.umbriel = {
      enable = true;
      package = pkgs.umbriel;
    };

    hjem.users.${user.name}.xdg.config.files."umbriel/config.toml".source = pkgs.replaceVars ./umbriel-config.toml {
      cursorName = fleet.theming.cursor.name;
      cursorSize = fleet.theming.cursor.size;
      main = fleet.monitors.main;
      secondary = fleet.monitors.secondary;
      mainConnector = host.monitors.main;
      themeStateDir = "\${NIX_THEME_STATE_DIR:-\${XDG_STATE_HOME:-$HOME/.local/state}/nix-theme/current/umbriel/umbriel-colors.toml}";
      DEFAULT_AUDIO_SINK = null;
      DEFAULT_AUDIO_SOURCE = null;
    };
  };
}
