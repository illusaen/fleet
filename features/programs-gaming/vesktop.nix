{
  modules.nixos = {
    pkgs,
    fleet,
    user,
    ...
  }: {
    environment.systemPackages = with pkgs; [vesktop];

    hjem.users.${user.name}.xdg.config.files = let
      json = (pkgs.formats.json {}).generate;
    in {
      "vesktop/settings.json" = {
        generator = json "vesktop-settings.json";
        value = {
          appBadge = false;
          arRPC = false;
          checkUpdates = false;
          customTitleBar = false;
          minimizeToTray = true;
          tray = true;
          splashBackground = "#000000";
          splashColor = "#ffffff";
          splashTheming = true;
          staticTitle = true;
          hardwareAcceleration = true;
          discordBranch = "stable";
        };
      };
      "vesktop/settings/settings.json" = {
        generator = json "vencord-settings.json";
        value = {
          autoUpdate = false;
          autoUpdateNotification = false;
          notifyAboutUpdates = false;
          useQuickCss = true;
          plugins.FakeNitro.enabled = true;
        };
      };
      "vesktop/settings/quickCss.css".text = ''
        root {
          --font: "${fleet.fonts.sans.name}";
        }
      '';
    };
  };
}
