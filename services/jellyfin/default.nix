{
  modules.nixos = {config, ...}: {
    services.jellyfin = {
      enable = true;
      openFirewall = true;
      # hardwareAcceleration.enable = true;
    };

    persist.directories = [
      {
        directory = config.services.jellyfin.cacheDir;
        user = "jellyfin";
        group = "jellyfin";
        mode = "0700";
      }
      {
        directory = config.services.jellyfin.dataDir;
        user = "jellyfin";
        group = "jellyfin";
        mode = "0700";
      }
    ];
  };
}
