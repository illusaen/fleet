{
  description = "Python project flake";

  inputs = {
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    devshell,
    nixpkgs,
    treefmt-nix,
    ...
  }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [devshell.overlays.default];
    };

    treefmtConfig = treefmt-nix.lib.evalModule pkgs {
      projectRootFile = "flake.nix";
      programs.alejandra.enable = true;
      programs.deadnix.enable = true;
      programs.statix.enable = true;
      programs.nixf-diagnose.enable = true;
      programs.ruff.enable = true;
      programs.mypy.enable = true;
      settings.excludes = ["*.patch" "*.png" "*.jpeg"];
    };

    initUvScript = ''
      export UV_PYTHON_DOWNLOADS=never
      export UV_PROJECT_ENVIRONMENT="$PWD/.venv"

      if [ -f "pyproject.toml" ]
      then
        if ! ${pkgs.uv}/bin/uv sync --python ${pkgs.python315}/bin/python
        then
          echo "Sync failed. Run 'uv sync' manually." >&2
        fi
      fi

      if [ ! -f "$UV_PROJECT_ENVIRONMENT/bin/activate" ]
      then
        ${pkgs.uv}/bin/uv venv \
          --python ${pkgs.python315}/bin/python \
          "$UV_PROJECT_ENVIRONMENT"
      fi

      source "$UV_PROJECT_ENVIRONMENT/bin/activate"
    '';
  in {
    formatter = treefmtConfig.config.build.wrapper;

    devShell = pkgs.devshell.mkShell (
      {extraModulesPath, ...}: {
        imports = [
          "${extraModulesPath}/git/hooks.nix"
        ];

        devshell = {
          packages = with pkgs; [
            nixd
            treefmtConfig.config.build.wrapper
            python315
            uv
          ];
          startup.initUv.text = initUvScript;
        };

        commands = [
          {
            name = "check";
            category = "quality";
            help = "Run coverage, lint, and type checks with tests";
            command = ''
              coverage run -m pytest "$@" \
                && coverage report \
                && ruff check . \
                && mypy
            '';
          }
        ];

        git.hooks = {
          enable = true;
          pre-commit.text = ''
            treefmt
          '';
        };
      }
    );
  };
}
