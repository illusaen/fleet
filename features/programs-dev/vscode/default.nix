{
  modules.generic = {
    fleet,
    host,
    lib,
    pkgs,
    user,
    ...
  }: let
    extensions = import ./_extensions.nix {inherit pkgs;};
    vscodeProfiles =
      lib.mapAttrs (name: extensionList: {
        location = name;
        icon = "globe";
        useDefaultFlags = {
          settings = true;
          keybindings = true;
          tasks = true;
          snippets = true;
          mcp = true;
        };
        extensions = extensionList;
      })
      extensions;
    vscodeUserDir = ".config/Code/User";
    vscodeExtensionJsonFile = name: text:
      pkgs.writeTextFile {
        inherit text;
        name = "extensions-json-${name}";
        destination = "/share/vscode/extensions/extensions.json";
      };
    vscodeProfilesExceptDefault = removeAttrs vscodeProfiles ["default"];
    vscodeDesiredProfilesJson = builtins.toJSON (
      lib.mapAttrsToList (name: profile: {
        inherit name;
        inherit (profile) location useDefaultFlags icon;
      })
      vscodeProfilesExceptDefault
    );
    syncVscodeProfiles = pkgs.writeShellScriptBin "sync-vscode-profiles" ''
      PATH=${lib.makeBinPath [pkgs.jq]}''${PATH:+:}$PATH
      file="$HOME/${vscodeUserDir}/globalStorage/storage.json"
      desired_profiles=${lib.escapeShellArg vscodeDesiredProfilesJson}

      if [ ! -f "$file" ]; then
        mkdir -p "$(dirname "$file")"
        echo "{}" > "$file"
      fi

      jq --argjson desired_profiles "$desired_profiles" '
        .userDataProfiles = (
          (.userDataProfiles // []) as $current
          | reduce $desired_profiles[] as $profile ($current;
              if any(.[]; .name == $profile.name) then
                map(
                  if .name == $profile.name then
                    . + {
                      location: $profile.location,
                      useDefaultFlags: $profile.useDefaultFlags,
                      icon: $profile.icon
                    }
                  else
                    .
                  end
                )
              else
                . + [$profile]
              end
            )
        )
      ' "$file" > "$file.tmp"

      mv "$file.tmp" "$file"
    '';
    vscodeExtensions = pkgs.buildEnv {
      name = "vscode-extensions";
      paths =
        (lib.flatten (map (profile: profile.extensions) (builtins.attrValues vscodeProfiles)))
        ++ [
          (vscodeExtensionJsonFile "default" (pkgs.vscode-utils.toExtensionJson vscodeProfiles.default.extensions))
        ];
    };
    vscodeGeneratedFiles =
      {
        ".vscode/argv.json" = {
          generator = lib.generators.toJSON {};
          value = {
            enable-crash-reporter = true;
            crash-reporter-id = "d17b2c57-3182-4ec0-a09f-c8abd1812a80";
            password-store = "gnome-libsecret";
          };
        };
        "${vscodeUserDir}/settings.json".source = pkgs.replaceVars ./settings.json.template {
          fontSize = builtins.floor (fleet.fonts.sizes.terminal * 1.1);
          monoFontName = "${fleet.fonts.mono.name},Maple Mono NF CN";
          serifFontName = "Monaspace Xenon Frozen";
          sansFontName = fleet.fonts.sans.name;
          zoomLevel = 1;
        };
        ".vscode/extensions".source = "${vscodeExtensions}/share/vscode/extensions";
      }
      // lib.mapAttrs' (
        name: profile:
          lib.nameValuePair "${vscodeUserDir}/profiles/${name}/extensions.json" {
            source = "${
              vscodeExtensionJsonFile name (
                pkgs.vscode-utils.toExtensionJson (profile.extensions ++ vscodeProfiles.default.extensions)
              )
            }/share/vscode/extensions/extensions.json";
          }
      )
      vscodeProfilesExceptDefault;
  in
    {
      environment.systemPackages = [pkgs.vscode syncVscodeProfiles];

      hjem.users.${user.name}.files = vscodeGeneratedFiles;
    }
    // lib.optionalAttrs (host.platform == "nixos") {
      system.userActivationScripts.syncVscodeProfiles = ''
        echo "Syncing vscode profiles."
        ${lib.getExe syncVscodeProfiles}
      '';
    };

  modules.nixos.persistUser.directories = [
    ".config/Code/User"
  ];
}
