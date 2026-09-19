{
  modules.nixos = {
    fleet,
    helpers,
    host,
    lib,
    ...
  }: let
    mkFleetHostEntry = name: knownHost:
      lib.nameValuePair name {
        hostNames = lib.unique (
          [
            name
            "${name}.${fleet.domain}"
            knownHost.targetHost
          ]
          ++ helpers.hostIps "ipv4" knownHost
        );
        publicKeyFile = knownHost.publicKey;
      };
    fleetKnownHosts = builtins.listToAttrs (
      map (
        name: mkFleetHostEntry name fleet.hosts.${name}
      )
      (builtins.filter (name: name != host.name) (builtins.attrNames fleet.hosts))
    );
    githubKnownHosts =
      lib.mapAttrs'
      (
        name: publicKey:
          lib.nameValuePair "github.com/${name}" {
            inherit publicKey;
            hostNames = ["github.com"];
          }
      )
      {
        ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
        rsa = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=";
        dsa = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=";
      };
  in {
    services.openssh.enable = true;
    programs.ssh.knownHosts = fleetKnownHosts // githubKnownHosts;
  };
}
