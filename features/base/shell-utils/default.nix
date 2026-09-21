let
  themeStateDir = "\${NIX_THEME_STATE_DIR:-\${XDG_STATE_HOME:-$HOME/.local/state}/nix-theme}";
  projectsFolder = "$HOME/Projects";
in {
  imports = [./git.nix ./starship.nix ./zsh.nix];

  modules.generic = {
    pkgs,
    user,
    ...
  }: {
    hjem.users.${user.name}.files.".hidden".text = ''
      .vscode
      .vscode-shared
      .steam
      .steampath
      .steampid
      .mozilla
    '';

    programs.direnv = {
      enable = true;
      silent = true;
      nix-direnv.enable = true;
      settings = {
        hide_env_diff = true;
        whitelist.prefix = [(builtins.replaceStrings ["$HOME"] ["~"] projectsFolder)];
      };
    };

    environment.systemPackages = with pkgs; [
      coreutils
      eza
      fd
      fzf
      ripgrep
      neovim
      wget
      zoxide
      (
        writeShellApplication {
          name = "bat";
          text = ''
            export BAT_CONFIG_DIR="${themeStateDir}/current/bat"
            exec ${bat}/bin/bat "$@"
          '';
        }
      )
      (
        writeShellApplication {
          name = "alacritty";
          text = ''
            exec ${alacritty}/bin/alacritty --config-file "${themeStateDir}/current/alacritty/alacritty.toml" "$@"
          '';
        }
      )
    ];
  };

  modules.nixos = {pkgs, ...}: {
    programs.nix-ld.enable = true;

    environment.sessionVariables = {
      # Pki files for certificate files for electron apps
      NSS_DEFAULT_DB_TYPE = "sql";
      NSS_USE_SHARED_DB = "sql:$HOME/.local/share/pki/nssdb";
      # Redirect the OpenGL/Vulkan shader cache
      __GL_SHADER_DISK_CACHE_PATH = "$HOME/.cache/nv";
      CUDA_CACHE_PATH = "$HOME/.cache/nv/ComputeCache";
      # pulseaudio
      PULSE_COOKIE = "$HOME/.config/pulse/cookie";
      NIXOS_OZONE_WL = 1;

      PROJECTS_FOLDER = projectsFolder;
      NIX_CONFIG_FOLDER = "$PROJECTS_FOLDER/fleet";
      EDITOR = "nvim";
    };

    system.userActivationScripts.cacheBat = {
      deps = ["initializeRuntimeTheme"];
      text = ''
        echo "Building bat cache."
        ${pkgs.bat}/bin/bat cache --build
      '';
    };

    persistUser.directories = [".local/share/zoxide"];
  };
}
