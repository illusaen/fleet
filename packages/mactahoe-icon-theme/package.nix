{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  gtk3,
  hicolor-icon-theme,
  jdupes,
  boldPanelIcons ? true,
  themeVariants ? [],
}: let
  pname = "MacTahoe-icon-theme";
in
  lib.checkListOfEnum "${pname}: theme variants"
  [
    "default"
    "blue"
    "purple"
    "red"
    "orange"
    "yellow"
    "green"
    "grey"
    "nord"
    "all"
  ]
  themeVariants
  stdenvNoCC.mkDerivation
  {
    inherit pname;
    version = "2026-06-28";

    src = fetchFromGitHub {
      owner = "vinceliuice";
      repo = "MacTahoe-icon-theme";
      rev = "main";
      hash = "sha256-YCtpagkXhRwD9NJRvgskq7yf4qr4XqUxQYUfyKD7mUs=";
    };

    nativeBuildInputs = [
      gtk3
      jdupes
    ];

    buildInputs = [hicolor-icon-theme];

    # These fixup steps are slow and unnecessary
    dontPatchELF = true;
    dontRewriteSymlinks = true;
    dontDropIconThemeCache = true;

    postPatch = ''
      patchShebangs install.sh
    '';

    installPhase = ''
      runHook preInstall

      ./install.sh --dest $out/share/icons \
        --name MacTahoe \
        --theme ${toString themeVariants} \
        ${lib.optionalString boldPanelIcons "--bold"} \

      jdupes --link-soft --recurse $out/share

      runHook postInstall
    '';

    # Drop dangling symlinks from the upstream icon set.
    postFixup = ''
      find $out/share/icons -xtype l -delete
    '';
  }
