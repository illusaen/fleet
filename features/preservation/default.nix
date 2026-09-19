{inputs}: {
  modules.nixos = {
    config,
    host,
    lib,
    pkgs,
    user,
    ...
  }: let
    inherit (host.preservation) homeSnapshot persistMount rootSnapshot;
  in {
    imports = [inputs.preservation.nixosModules.default];

    preservation = {
      enable = true;
      preserveAt.${persistMount} = config.persist // {users.${user.name} = config.persistUser;};
    };

    persist = {
      directories = [
        "/var/log"
        "/var/lib/systemd/timers"
        "/var/lib/systemd/rfkill"
        "/var/lib/systemd/coredump"
        {
          directory = "/var/lib/nixos";
          inInitrd = true;
        }
      ];
      files = [
        {
          file = "/etc/machine-id";
          inInitrd = true;
        }
        {
          file = "/var/lib/systemd/random-seed";
          how = "symlink";
          inInitrd = true;
          configureParent = true;
        }
      ];
    };

    persistUser = {
      commonMountOptions = [
        "x-gvfs-hide"
        "x-gvfs-trash"
      ];
      directories = [
        {
          directory = ".local/share/keyrings";
          mode = "0700";
        }
        "Downloads"
        "Projects"
        "Pictures"
      ];
    };

    boot.initrd.systemd.services.zfs-rollback = {
      description = "Rollback ZFS root dataset to blank snapshot";
      wantedBy = ["initrd.target"];
      after = ["zfs-import-zroot.service"];
      before = ["sysroot.mount"];
      path = [pkgs.zfs];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      script = ''
        zfs rollback -r ${rootSnapshot} && echo "zfs root rollback complete"
        zfs rollback -r ${homeSnapshot} && echo "zfs home rollback complete"
      '';
    };

    systemd.services.systemd-machine-id-commit = lib.mkDefault {
      unitConfig.ConditionPathIsMountPoint = [
        ""
        persistMount
      ];
      serviceConfig.ExecStart = [
        ""
        "${pkgs.systemd}/bin/systemd-machine-id-setup --commit --root ${persistMount}"
      ];
    };

    fileSystems."${persistMount}".neededForBoot = true;
    systemd.tmpfiles.settings.preservation."/home/${user.name}".d = {
      user = user.name;
      group = "users";
      mode = "0700";
    };
  };
}
