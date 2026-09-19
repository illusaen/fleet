{pkgs}: {
  default =
    (with pkgs.vscode-extensions; [
      jnoortheen.nix-ide
      mkhl.direnv
      naumovs.color-highlight
      usernamehw.errorlens
    ])
    ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
      {
        publisher = "VanCoding";
        name = "vscode-treefmt-nix";
        version = "1.0.2";
        hash = "sha256-6srW1fCbXLZwQunNuUYh2pS9D2XBunt1IrCIMB7MaYA=";
      }
      {
        publisher = "openai";
        name = "chatgpt";
        version = "26.5707.41301";
        arch = "linux-x64";
        hash = "sha256-Ve0gIfS5jEvGMcQMlZVEoUDxA4SJ0UmXl2oF1cKB2Rk=";
      }
      {
        publisher = "vira";
        name = "vsc-vira-theme";
        version = "2026.6.6";
        hash = "sha256-Fn/LasrjFwHXp894z44JYVDtCIqwlXS90VjC5KXU/Jg=";
      }
    ];

  rust = with pkgs.vscode-extensions; [
    rust-lang.rust-analyzer
    tamasfe.even-better-toml
  ];

  web =
    (with pkgs.vscode-extensions; [
      svelte.svelte-vscode
      bradlc.vscode-tailwindcss
    ])
    ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
      {
        publisher = "inlang";
        name = "vs-code-extension";
        version = "2.3.2";
        hash = "sha256-ArTuBB+0fIYIH3myCLolVbuD46oTlLaOWb5TOZNwLPo=";
      }
    ];
}
