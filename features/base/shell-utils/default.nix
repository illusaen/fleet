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
      ripgrep
      neovim
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
      (
        pkgs.writeShellApplication {
          name = "scratchpad-alacritty";
          runtimeInputs = [pkgs.coreutils pkgs.jq];
          text = ''
            get_window_id() {
              ${lib.getExe pkgs.umbriel} windows --json |
                jq -r 'first(.[] | select(.app_id == "scratchpad-alacritty") | .id) // empty'
            }

            window_id="$(get_window_id)"
            if [[ -z "$window_id" ]]; then
              ${lib.getExe pkgs.alacritty} --class scratchpad-alacritty &

              for _ in {1..100}; do
                window_id="$(get_window_id)"
                [[ -n "$window_id" ]] && break
                sleep 0.05
              done

              if [[ -z "$window_id" ]]; then
                echo "scratchpad-alacritty: Alacritty window did not appear" >&2
                exit 1
              fi
            fi

            # The main output is left of the secondary output. This focuses it
            # when necessary and is a harmless no-op when it is already focused.
            ${lib.getExe pkgs.umbriel} msg output-focus-left 2>/dev/null || true
            ${lib.getExe pkgs.umbriel} msg scratchpad-toggle:TERMINAL
          '';
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
      EDITOR = "nvim";
    };

    persistUser.directories = [".local/share/zoxide"];
  };
}
