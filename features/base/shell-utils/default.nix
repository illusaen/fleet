let
  projectsFolder = "$HOME/Projects";
in {
  imports = [./git.nix ./starship.nix ./zsh.nix];

  modules.generic = {pkgs, ...}: {
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
      killall
      ripgrep
      wget
      zoxide
      (
        writeShellApplication {
          name = "bat";
          text = ''
            export BAT_CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/bat"
            exec ${bat}/bin/bat "$@"
          '';
        }
      )
      (
        writeShellApplication {
          name = "alacritty";
          text = ''
            exec ${alacritty}/bin/alacritty --config-file "''${XDG_CONFIG_HOME:-$HOME/.config}/alacritty/alacritty.toml" "$@"
          '';
        }
      )
    ];
  };

  modules.nixos = {
    pkgs,
    lib,
    ...
  }: {
    programs.nix-ld.enable = true;

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
    };

    environment.systemPackages = [
      (
        pkgs.makeDesktopItem {
          name = "alacritty";
          desktopName = "Alacritty";
          comment = "Open alacritty terminal";
          exec = "${lib.getExe pkgs.alacritty}";
          categories = ["Development"];
        }
      )
    ];

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
      # PAM expands $HOME, but not references to other session variables.
      NIX_CONFIG_FOLDER = "${projectsFolder}/fleet";

      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";

      EDITOR = "nvim";
    };

    persistUser.directories = [".local/share/zoxide"];
  };
}
