{
  modules.nixos = {
    fleet,
    pkgs,
    user,
    ...
  }: {
    services.displayManager.noctalia-greeter = let
      inherit (fleet.theming.cursor) name size;
    in {
      enable = true;
      settings = {
        cursor.size = size;
        user.default = user.name;
        appearance.scheme = "Synced";
        appearance.hide_logo = true;
      };
      cursorTheme = {
        package = pkgs.${name};
        inherit name;
      };
      passwordlessSyncUsers = [user.name];
    };
  };
}
