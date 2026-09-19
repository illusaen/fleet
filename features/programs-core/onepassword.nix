{
  modules.generic = {pkgs, ...}: {
    programs = {
      _1password.enable = true;
      _1password-gui = {
        enable = true;
        package = pkgs._1password-gui-beta;
      };
    };
  };

  modules.nixos = {
    user,
    config,
    lib,
    options,
    ...
  }:
    lib.mkMerge [
      {
        programs._1password-gui.polkitPolicyOwners = [user.name];
        systemdAutostart = [
          {
            name = "one-password";
            package = config.programs._1password-gui.package;
          }
        ];
      }
      (lib.optionalAttrs (options ? persistUser) {
        persistUser.directories = [
          ".config/1Password"
        ];
      })
    ];
}
