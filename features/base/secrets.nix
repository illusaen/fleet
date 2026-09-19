{inputs}: {
  modules.generic = {host, ...}: {
    age.identityPaths = [host.privateKey];
  };

  modules.nixos = [
    inputs.agenix.nixosModules.default
    (
      {
        host,
        lib,
        options,
        ...
      }: {
        config = lib.optionalAttrs (options ? persist) {
          persist.files = [
            {
              file = host.privateKey;
              mode = "0640";
              group = "wheel";
            }
          ];
        };
      }
    )
  ];
}
