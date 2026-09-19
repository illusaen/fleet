{
  modules.nixos = {
    lib,
    options,
    ...
  }:
    lib.mkMerge [
      {
        programs.google-chrome = {
          enable = true;
          extensions = [
            "aeblfdkhhhdcdjpifhhbdiojplfjncoa" # 1Password
            "ddkjiahejlhfcafbddmgiahcphecmpfh" # Ublock
            "dbepggeogbaibhgnhhndojpepiihcmeb" # Vimium
            "ldgfbffkinooeloadekpmfoklnobpien" # Raindrop
            "nplimhmoanghlebhdiboeellhgmgommi" # Tab Groups
            "cgfpgnepljlgenjclbekbjdlgcodfmjp" # Tab Sort
            "cemphncflepgmgfhcdegkbkekifodacd" # Custom CSS
          ];
          policies = {
            PasswordManagerEnabled = false;
          };
        };

        xdg.mime.defaultApplications = {
          "text/html" = "google-chrome.desktop";
          "x-scheme-handler/http" = "google-chrome.desktop";
          "x-scheme-handler/https" = "google-chrome.desktop";
          "x-scheme-handler/about" = "google-chrome.desktop";
          "x-scheme-handler/unknown" = "google-chrome.desktop";
        };
      }
      (lib.optionalAttrs (options ? persistUser) {
        persistUser.directories = [
          ".config/google-chrome"
        ];
      })
    ];
}
