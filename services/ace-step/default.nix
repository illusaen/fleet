{
  modules.nixos = {
    pkgs,
    lib,
    helpers,
    host,
    ...
  }: let
    service = helpers.requireRoutedService host "ace-step";
  in {
    environment.systemPackages = [pkgs.local.ace-step];
    networking.firewall.allowedTCPPorts = [service.port];

    systemd.user.services.ace-step = {
      description = "ACE-Step music generation service";
      wantedBy = ["default.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      environment.ACESTEP_OUTPUT_DIR = "%h/Music/acestep";
      serviceConfig = {
        ExecStart = lib.escapeShellArgs [
          (lib.getExe' pkgs.local.ace-step "acestep")
          "--server-name"
          "0.0.0.0"
          "--port"
          (toString service.port)
        ];
        EnvironmentFile = "-%h/.config/acestep/.env";
        WorkingDirectory = "%h/.config/acestep";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    persistUser.directories = [
      ".config/acestep"
      "Music/acestep"
    ];
  };
}
