{
  modules.nixos = {
    pkgs,
    helpers,
    host,
    ...
  }: let
    service = helpers.requireRoutedService host "ace-step";
  in {
    environment.systemPackages = [pkgs.local.ace-step];
    networking.firewall.allowedTCPPorts = [service.port];
  };
}
