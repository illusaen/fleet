{inputs}: {
  imports = [
    ./shell-utils
    ./networking.nix
    ./nix-settings.nix
    ./secrets.nix
    ./ssh.nix
    ./tailscale.nix
  ];

  modules.generic = {
    host,
    user,
    ...
  }: {
    nixpkgs = {
      config.allowUnfree = true;
      hostPlatform = host.system;
    };
    hjem.users.${user.name}.enable = true;
  };

  modules.nixos = {
    fleet,
    lib,
    user,
    ...
  }: let
    inherit (builtins) attrNames any elem;
    inherit (lib) filterAttrs pipe;

    posixGroups = let
      userGroups = user.groups or [];
    in
      pipe fleet.groups [
        (filterAttrs (_name: group: (group.isPosix or false) && any (member: elem member userGroups) (group.members or [])))
        attrNames
      ];

    extraGroups = lib.unique (posixGroups ++ lib.optional (user.system.isAdmin or false) "wheel");
  in {
    imports = [
      inputs.hjem.nixosModules.default
    ];

    system.stateVersion = "26.11";

    users.users.${user.name} = {
      isNormalUser = true;
      uid = lib.mkIf ((user.system.uid or null) != null) user.system.uid;
      description = user.identity.displayName or user.name;
      inherit extraGroups;
      openssh.authorizedKeys.keys = map (key: key.key) (user.identity.sshKeys or []);
      password = "arst";
    };
  };
}
