{
  modules.generic = {
    pkgs,
    config,
    user,
    ...
  }: let
    version = "0.0.5";
    packageJson = pkgs.writeText "noctalia-theme-package.json" (builtins.toJSON {
      name = "noctaliatheme";
      displayName = "NoctaliaTheme";
      inherit version;
      publisher = "noctalia";
      description = "Theme configured via NixOS or Home Manager.";
      categories = ["Themes"];
      engines.vscode = "^1.43.0";
      contributes.themes = [
        {
          label = "NoctaliaTheme";
          uiTheme = "vs";
          path = "./themes/vscode-noctalia-theme.json";
        }
      ];
    });
    noctaliaTheme =
      pkgs.runCommand "vscode-extension-noctalia-theme-${version}" rec {
        inherit version;
        vscodeExtPublisher = "noctalia";
        vscodeExtName = "noctaliatheme";
        vscodeExtUniqueId = "${vscodeExtPublisher}.${vscodeExtName}";
      } ''
        extension="$out/share/vscode/extensions/$vscodeExtUniqueId"
        mkdir -p "$extension/themes"
        cp ${packageJson} "$extension/package.json"
        ln -s "${config.users.users.${user.name}.home}/.local/state/nix-theme/vscode.json" "$extension/themes/vscode-noctalia-theme.json"
      '';
  in {
    programs.vscode = {
      enable = true;
      extensions =
        (with pkgs.vscode-extensions; [
          jnoortheen.nix-ide
          mkhl.direnv
          naumovs.color-highlight
          usernamehw.errorlens
          tamasfe.even-better-toml
          svelte.svelte-vscode
          bradlc.vscode-tailwindcss
          ms-python.python
          rust-lang.rust-analyzer
        ])
        ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          {
            publisher = "VanCoding";
            name = "vscode-treefmt-nix";
            version = "1.0.2";
            hash = "sha256-6srW1fCbXLZwQunNuUYh2pS9D2XBunt1IrCIMB7MaYA=";
          }
          {
            publisher = "inlang";
            name = "vs-code-extension";
            version = "2.3.2";
            hash = "sha256-ArTuBB+0fIYIH3myCLolVbuD46oTlLaOWb5TOZNwLPo=";
          }
          {
            publisher = "dawhite";
            name = "mustache";
            version = "1.1.1";
            hash = "sha256-PkymMex1icvDN2Df38EIuV1O9TkMNWP2sGOjl1+xGMk=";
          }
        ]
        ++ [noctaliaTheme];
      enterprisePolicies = {
        UpdateMode = "none";
        TelemetryLevel = "off";
        ExtensionsAutoUpdate = "off";
        EnableFeedback = false;
      };
    };
  };

  modules.nixos.persistUser.directories = [
    ".config/Code/User"
    ".vscode-shared"
  ];
}
