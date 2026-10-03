{
  caddy = {
    primary = "huginn";
    port = 443;
  };

  llama-cpp = {
    primary = "odin";
    port = 8080;
  };

  navidrome = {
    primary = "huginn";
    port = 4533;
  };

  pihole = {
    primary = "huginn";
    backups = ["muninn"];
    port = 53;
    proxyPort = 8081;
  };

  linkding = {
    primary = "huginn";
    port = 9090;
  };

  jellyfin = {
    primary = "huginn";
    port = 8096;
  };
}
