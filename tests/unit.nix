{
  lib,
  root ? ../.,
}: {
  features = import ./features.nix {inherit lib root;};
  services = import ./services.nix {inherit lib root;};
}
