{
  modules.generic = {pkgs, ...}: let
    fontPackages = with pkgs; [
      font-awesome
      inter
      maple-mono.NF-CN-unhinted
      material-symbols
      monaspace
      noto-fonts-color-emoji
    ];
  in {
    fonts.packages = fontPackages;
  };

  modules.nixos = {
    fleet,
    lib,
    ...
  }: {
    fonts.fontconfig = {
      defaultFonts = {
        monospace = [fleet.fonts.mono.name "Maple Mono NF CN"];
        serif = [fleet.fonts.sans.name];
        sansSerif = [fleet.fonts.sans.name];
        emoji = [fleet.fonts.emoji.name];
      };
      aliases = let
        fontNames =
          map (font: font.name)
          (builtins.attrValues (removeAttrs fleet.fonts ["sizes"]));
      in
        builtins.listToAttrs (
          map (name:
            lib.nameValuePair name {
              default = ["Font Awesome 7 Free"];
            })
          fontNames
        );
    };
  };
}
