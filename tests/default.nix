{
  self,
  nixpkgs,
  pkgs,
}:
pkgs.runCommandLocal "unit-tests" {
  nativeBuildInputs = [pkgs.nix-unit];
} ''
  export HOME="$TMPDIR"
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
