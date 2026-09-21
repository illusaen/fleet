{
  modules.generic = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      gh
      git
      difftastic
    ];
  };
}
