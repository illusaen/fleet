{
  writeShellApplication,
  symlinkJoin,
  python3,
  ddcutil,
  dconf,
  i2c-tools,
  ...
}: let
  pythonScript = name: script: runtimeInputs:
    writeShellApplication {
      inherit name runtimeInputs;
      text = ''
        exec python3 ${script} "$@"
      '';
    };
in
  symlinkJoin {
    name = "misc-scripts";
    paths = [
      (pythonScript "dconf2nix" ./scripts/dconf-to-nix.py [
        python3
        dconf
      ])
      (pythonScript "switcher" ./scripts/switch-input.py [
        python3
        ddcutil
        i2c-tools
      ])
    ];
  }
