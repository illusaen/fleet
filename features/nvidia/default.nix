{
  modules.nixos = {config, ...}: {
    services.xserver.videoDrivers = ["nvidia"];

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
}
