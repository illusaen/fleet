{
  modules.generic = {pkgs, ...}: {
    environment.systemPackages = [pkgs.vscode];
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
            publisher = "vira";
            name = "vsc-vira-theme";
            version = "2026.6.6";
            hash = "sha256-Fn/LasrjFwHXp894z44JYVDtCIqwlXS90VjC5KXU/Jg=";
          }
          {
            publisher = "inlang";
            name = "vs-code-extension";
            version = "2.3.2";
            hash = "sha256-ArTuBB+0fIYIH3myCLolVbuD46oTlLaOWb5TOZNwLPo=";
          }
        ];
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
