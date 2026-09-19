let
  historyFile = ".local/state/.zsh_history";
  shellAliases = {
    cat = "bat";
    e = "open_editor";
    eza = "eza --icons=auto --git --git-repos";
    fd = "fd --hidden --follow --exclude .git";
    ga = "git add -A";
    gb = "git branch";
    gbd = "git branch -vv | grep ': gone]' | awk '{print $1}' | xargs git branch -d";
    gcm = "git_commit_with_message";
    gcma = "git commit --amend";
    gco = "git checkout";
    gd = "git diff";
    gf = "git fetch";
    gl = "git pull";
    glg = "git log";
    gp = "git push";
    gpf = "git push --force-with-lease";
    gst = "git status";
    l = ''eza -alg -I "$(tr "\n" "|" < ~/.hidden | sed 's/|$//')"'';
    ll = ''eza -Ta --git-ignore -L 2 -I "$(tr "\n" "|" < ~/.hidden | sed 's/|$//')"'';
    whichstore = "nix_store_for_command";
    nd = "dix /run/current-system";
    hdmi = "switcher hdmi1";
    dp = "switcher dp";
  };
in {
  modules.generic = {
    pkgs,
    user,
    ...
  }: {
    users.users.${user.name}.shell = pkgs.zsh;
    programs.zsh = {
      enable = true;
      histFile = "$HOME/${historyFile}";
      interactiveShellInit = ''
        eval "$(${pkgs.zoxide}/bin/zoxide init zsh --cmd n)"
        source <(${pkgs.fzf}/bin/fzf --zsh)

        ${builtins.readFile ./interactive.zsh}
      '';
      shellInit = ''
        # Prevent the Zsh new user configuration menu from appearing
        zsh-newuser-install() { :; }
      '';
      promptInit = ''
        eval "$(${pkgs.starship}/bin/starship init zsh)"
      '';
    };
  };
  modules.nixos = {
    lib,
    options,
    ...
  }:
    lib.mkMerge [
      {
        programs.zsh.shellAliases = shellAliases;

        environment.sessionVariables = {
          ZSH_COMPDUMP = "$HOME/.cache/zsh/zcompdump-$ZSH_VERSION";
          FZF_DEFAULT_OPTS = "--no-height --style=full";
        };
      }
      (lib.optionalAttrs (options ? persistUser) {
        persistUser.files = [
          {
            file = historyFile;
            how = "symlink";
          }
        ];
      })
    ];
}
