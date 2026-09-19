{
  modules.nixos = {
    host,
    lib,
    ...
  }: let
    facterReport = ./hardware/${host.name}/facter.json;
  in {
    hardware =
      {
        facter = lib.mkIf (builtins.pathExists facterReport) {
          reportPath = facterReport;
          detected.dhcp.enable = false;
        };
      }
      // (lib.optionalAttrs (host.system != "x86_64-linux") {
        cpu.amd.updateMicrocode = lib.mkForce false;
        cpu.intel.updateMicrocode = lib.mkForce false;
      });

    services.power-profiles-daemon.enable = false;
  };
}
