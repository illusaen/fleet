{
  symlinkJoin,
  writeShellApplication,
  niri,
  python3,
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
    name = "niri-scripts";
    paths = [
      (pythonScript "ndrop" ./scripts/ndrop.py [
        niri
        python3
      ])
      (pythonScript "niri-workspace" ./scripts/niri-workspace.py [
        niri
        python3
      ])
    ];
  }
