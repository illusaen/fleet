{
  description = "Node project flake";

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

    inherit (nixpkgs) lib;

    treefmtConfig = treefmt-nix.lib.evalModule pkgs {
      projectRootFile = "flake.nix";
      programs.alejandra.enable = true;
      programs.deadnix.enable = true;
      programs.statix.enable = true;
      programs.nixf-diagnose.enable = true;
      programs.prettier = {
        enable = true;
        includes = [
          "*.svelte"
          "*.js"
          "*.jsx"
          "*.ts"
          "*.tsx"
        ];
        settings = {
          plugins = ["prettier-plugin-svelte"];
          bracketSameLine = false;
          bracketSpacing = true;
          htmlWhitespaceSensitivity = "css";
          semi = true;
          jsxSingleQuote = true;
          singleQuote = true;
          trailingComma = "all";
        };
      };
      programs.jsonfmt = {
        enable = true;
        excludes = [
          "package*.json"
          "tsconfig*.json"
        ];
      };
      settings.excludes = ["*.patch" "*.png" "*.jpeg"];
    };

    _fileChecksum = path: "$(${pkgs.coreutils}/bin/cksum ${lib.escapeShellArg path} | ${pkgs.coreutils}/bin/cut -f1 -d' ')";
    initPnpmScript = ''
      function _pnpm-install()
      {
        # Avoid running "pnpm install" for every shell.
        # Only run it when the "package-lock.json" file or nodejs version has changed.
        # We do this by storing the nodejs version and a hash of "package-lock.json" in node_modules.
        local ACTUAL_PNPM_CHECKSUM="${pkgs.pnpm.version}:${_fileChecksum "pnpm-lock.yaml"}"
        local PNPM_CHECKSUM_FILE="node_modules/pnpm-lock.yaml.checksum"
        if [ -f "$PNPM_CHECKSUM_FILE" ]
          then
            read -r EXPECTED_PNPM_CHECKSUM < "$PNPM_CHECKSUM_FILE"
          else
            EXPECTED_PNPM_CHECKSUM=""
        fi

        if [ "$ACTUAL_PNPM_CHECKSUM" != "$EXPECTED_PNPM_CHECKSUM" ]
        then
          if ${pkgs.pnpm}/bin/pnpm install
          then
            echo "$ACTUAL_PNPM_CHECKSUM" > "$PNPM_CHECKSUM_FILE"
          else
            echo "Install failed. Run 'pnpm install' manually."
          fi
        fi
      }

      if [ ! -f "package.json" ]
      then
        echo "No package.json found. Run 'pnpm init' to create one." >&2
      else
        _pnpm-install
      fi
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
            treefmtConfig.config.build.wrapper
            nodejs-slim_latest
            pnpm
            nixd
          ];
          startup.initPnpm.text = initPnpmScript;
        };

        commands = [
          {
            name = "build";
            command = "pnpm build";
            help = "Build node project";
          }
          {
            name = "run";
            command = "pnpm dev";
            help = "Run node project in dev mode";
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
