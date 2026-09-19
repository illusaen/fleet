{
  imports = [./vscode ./zathura.nix];

  modules.nixos = {
    pkgs,
    lib,
    options,
    ...
  }:
    lib.mkMerge [
      {environment.systemPackages = with pkgs; [meld codex];}
      (lib.optionalAttrs (options ? persistUser) {
        persistUser.directories = [
          ".codex"
        ];
      })
    ];
}
