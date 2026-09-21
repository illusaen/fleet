{
  lib,
  stdenv,
  fetchFromGitHub,
  gitUpdater,
  dialog,
  glib,
  gnome-themes-extra,
  jdupes,
  libxml2,
  sassc,
  util-linux,
  altVariants ? [], # default: normal
  colorVariants ? [], # default: all
  opacityVariants ? [], # default: all
  themeVariants ? [], # default: default (BigSur-like theme)
  schemeVariants ? [], # default: standard # default: standard (Apple logo)
  nautilusStyle ? "stable", # default: stable (BigSur-like style) # default: 15% # default: 32px
  roundedMaxWindow ? true, # default: false
  darkerColor ? false, # default = false
  highDefinition ? true, # default = false
  installLibadwaita ? true,
}: let
  pname = "mactahoe-gtk-theme";
  installArgs =
    lib.concatMap (x: ["--alt" x]) altVariants
    ++ lib.concatMap (x: ["--color" x]) colorVariants
    ++ lib.concatMap (x: ["--opacity" x]) opacityVariants
    ++ lib.concatMap (x: ["--theme" x]) themeVariants
    ++ lib.concatMap (x: ["--scheme" x]) schemeVariants
    ++ lib.optionals (nautilusStyle != null) ["--nautilus" nautilusStyle]
    ++ lib.optional darkerColor "--darkercolor"
    ++ lib.optional highDefinition "--highdefinition"
    ++ lib.optional installLibadwaita "--libadwaita"
    ++ lib.optional roundedMaxWindow "--roundedmaxwindow";
in
  stdenv.mkDerivation {
    inherit pname;
    version = "2026-06-28";

    src = fetchFromGitHub {
      owner = "vinceliuice";
      repo = "MacTahoe-gtk-theme";
      rev = "main";
      hash = "sha256-tuon9XxMdrz9XNTp50sbss2gtx6H9hEZh8t2jSoqx28=";
    };

    patches = [./nautilus-background.patch];

    nativeBuildInputs = [
      dialog
      glib
      jdupes
      libxml2
      sassc
      util-linux
    ];

    buildInputs = [
      gnome-themes-extra # adwaita engine for Gtk2
    ];

    postPatch = ''
      find -name "*.sh" -print0 | while IFS= read -r -d ''' file; do
        patchShebangs "$file"
      done

      # Do not provide `sudo`, as it is not needed in our use case of the install script
      # Provides a dummy home directory
      substituteInPlace libs/lib-core.sh \
        --replace-fail '$(which sudo)' false \
        --replace-fail 'MY_HOME=$(getent passwd "''${MY_USERNAME}" | cut -d: -f6)' 'MY_HOME=/tmp'

      substituteInPlace libs/lib-install.sh \
        --replace-fail 'local TARGET_DIR="''${HOME}/.config/gtk-4.0"' 'local TARGET_DIR="$out/share/libadwaita-themes"' \
        --replace-fail '$'{HOME}'/.config/gtk-4.0' '$out/share/libadwaita-themes'

      substituteInPlace install.sh --replace-fail '$'{HOME}'/.config/gtk-4.0' '$out/share/libadwaita-themes'
    '';

    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/themes
      ./install.sh ${lib.escapeShellArgs installArgs} --dest $out/share/themes
      jdupes --quiet --link-soft --recurse $out/share

      runHook postInstall
    '';

    passthru.updateScript = gitUpdater {};
  }
