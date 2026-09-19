{
  modules.generic = {
    pkgs,
    lib,
    host,
    user,
    ...
  }: let
    gitConfig = {
      core.sshCommand = "ssh -i ${host.privateKey}";
      diff.external = "difft --color auto --background dark --display side-by-side";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      fetch.prune = true;
      user = {
        inherit (user.identity) email;
        name = user.identity.displayName;
      };
      credential = {
        inherit (user.identity) accountName;
        helper = "!gh auth git-credential";
      };
    };
    settings = pkgs.writeText "gitconfig" (lib.generators.toGitINI gitConfig);
    gitWrapper = pkgs.writeShellApplication {
      name = "git";
      runtimeInputs = with pkgs; [git difftastic];
      text = ''
        export GIT_CONFIG_GLOBAL=${settings}
        exec ${pkgs.git}/bin/git "$@"
      '';
      passthru = {
        config = gitConfig;
        configFile = settings;
      };
    };
  in {
    environment.systemPackages = with pkgs; [
      gh
      gitWrapper
    ];

    hjem.users.${user.name}.xdg.config.files = {
      "gh/config.yml".text = ''
        version: "1"
      '';
      "gh/hosts.yml".text = ''
        github.com:
          git_protocol: ssh
          users:
            ${user.identity.accountName}:
          user: ${user.identity.accountName}
      '';
    };
  };
}
