let
  lg = "LG Electronics LG ULTRAGEAR+ 508RMWVJR505";
  portable = "BOE Display 000000001";
in {
  odin = {
    system = "x86_64-linux";
    owner = "wendy";

    maxJobs = 1;
    cores = 4;
    targetHost = "odin.home.arpa";
    localDeploymentOnly = true;
    hostId = "abf835ae";

    tags = ["desktop" "gpu:nvidia" "feature:dev" "feature:gaming"];

    networkInterfaces.eno1.ipv4 = "192.168.1.162/24";

    monitors = {
      main = {
        connector = "DP-2";
        name = lg;
      };
      secondary = {
        connector = "HDMI-A-2";
        name = portable;
      };
    };

    preservation = {
      enable = true;
      disk = "nvme0n1";
    };
  };

  huginn = {
    system = "x86_64-linux";
    owner = "wendy";
    targetHost = "192.168.1.161";
    hostId = "99901a95";

    tags = ["server"];

    networkInterfaces.enp1s0.ipv4 = "192.168.1.161/24";

    preservation = {
      enable = false;
      disk = "sda";
    };

    monitors.main = {
      connector = "HDMI-A-2";
      name = portable;
    };
  };

  muninn = {
    system = "aarch64-linux";
    owner = "wendy";
    targetHost = "muninn.home.arpa";
    hostId = "f687c689";

    tags = ["server"];

    networkInterfaces.eno1.ipv4 = "192.168.1.163/24";

    preservation = {
      enable = true;
      disk = "nvme0n1";
    };
  };
}
