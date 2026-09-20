let
  template = name: {
    path = ./templates/${name};
    description = "nix flake new my-project -t github:illusaen/fleet#${name}";
  };
  languages = ["node" "rust"];
in
  builtins.listToAttrs (map (l: {
      name = l;
      value = template l;
    })
    languages)
