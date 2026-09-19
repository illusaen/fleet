{
  modules.nixos = {user, ...}: {
    programs.weylus = {
      enable = true;
      users = [user.name];
      openFirewall = true;
    };
    hardware.uinput.enable = true;
    boot.kernelModules = ["uinput"];
    services.udev.extraRules = ''
      KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
    '';
  };
}
