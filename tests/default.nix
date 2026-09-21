{
  self,
  nixpkgs,
  pkgs,
}:
pkgs.runCommandLocal "unit-tests" {
  nativeBuildInputs = [
    pkgs.nix-unit
    (pkgs.python3.withPackages (pythonPackages: [
      pythonPackages.pystache
      pythonPackages.pyyaml
    ]))
  ];
} ''
  export HOME="$TMPDIR"
  python -m unittest discover -s ${self}/tests -p 'test_*.py'
  nix-unit \
    --arg lib '
      let
        lib = import ${nixpkgs}/lib;
      in
        lib // (import ${pkgs.nix-unit.src}/lib { inherit lib; })
    ' \
    --arg root ${self} \
    ${./.}/unit.nix
  touch "$out"
''
