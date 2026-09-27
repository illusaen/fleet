{
  lib,
  inputs,
}: final: _prev: {
  local = let
    packageRoot = ../packages;
    packageFile = name: packageRoot + "/${name}/package.nix";
  in
    lib.pipe packageRoot [
      builtins.readDir
      (lib.filterAttrs (n: v: v == "directory" && builtins.pathExists (packageFile n)))
      (builtins.mapAttrs (n: _v:
        final.callPackage (packageFile n) {
          inherit (inputs) ace-step-src pyproject-build-systems pyproject-nix uv2nix;
        }))
    ];
}
