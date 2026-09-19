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
    --arg lib 'import ${nixpkgs}/lib' \
    --arg root ${self} \
    ${./unit.nix}
  touch "$out"
''
