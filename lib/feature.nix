{
  inputs,
  lib,
}: let
  inherit (builtins) attrNames concatLists concatMap filter listToAttrs readDir elem;
  inherit (lib) concatStringsSep optionals pipe unique filterAttrs;

  mergeFeatures = fragments: let
    declaredModulePlatforms = concatMap (fragment: attrNames (fragment.modules or {})) fragments;
    platformNames =
      filter
      (platform: elem "generic" declaredModulePlatforms || elem platform declaredModulePlatforms)
      ["nixos" "darwin"];
  in {
    modules = listToAttrs (
      map (platform: {
        name = platform;
        value =
          concatMap (
            fragment: let
              modules = fragment.modules or {};
              moduleList = platform: lib.optionals ((modules.${platform} or null) != null) (lib.toList modules.${platform});
            in
              moduleList "generic" ++ moduleList platform
          )
          fragments;
      })
      platformNames
    );
  };

  loadFeaturePath = path: let
    callFeature = feature:
      if builtins.isFunction feature
      then
        feature {
          inherit inputs;
        }
      else feature;
    feature = callFeature (import path);
    localFeatures = map loadFeaturePath (feature.imports or []);
  in
    mergeFeatures (localFeatures ++ [feature]);

  loadFeatureRoot = featureRoot:
    pipe featureRoot [
      readDir
      (filterAttrs (_name: value: value == "directory"))
      (builtins.mapAttrs (name: _value: (loadFeaturePath (featureRoot + "/${name}"))))
    ];

  regularFeatures = loadFeatureRoot ../features;
  serviceFeatures = loadFeatureRoot ../services;
  duplicateFeatureNames = filter (name: builtins.hasAttr name serviceFeatures) (attrNames regularFeatures);
  features =
    if duplicateFeatureNames != []
    then throw "Feature names must be unique across features/ and services/: ${concatStringsSep ", " duplicateFeatureNames}"
    else regularFeatures // serviceFeatures;

  featuresForHost = host: let
    tags = host.tags or [];
    services = host.services or [];
    isLinux = host.platform == "nixos";
    isDesktop = builtins.elem "desktop" tags;
    featureGroups = [
      ["base"]
      (optionals isLinux ["boot"])
      (optionals isDesktop ["programs-core" "theming"])
      (optionals (isLinux && isDesktop) ["desktop-shell"])
      (optionals (builtins.elem "gpu:nvidia" tags) ["nvidia"])
      (concatMap (
          tag: let
            match = builtins.match "feature:(.+)" tag;
          in
            optionals (match != null) ["programs-${builtins.head match}"]
        )
        tags)
      (optionals (host.preservation.enable or false) ["preservation"])
      host.features
      (builtins.catAttrs "feature" services)
    ];
  in
    unique (concatLists featureGroups);
in {
  modulesForHost = host: let
    names = featuresForHost host;
  in
    concatMap (
      name:
        if !(builtins.hasAttr name features)
        then throw "Host `${host.name}` selects unknown feature `${name}`."
        else if !(builtins.hasAttr host.platform features.${name}.modules)
        then throw "Feature `${name}` does not provide modules for `${host.platform}`."
        else features.${name}.modules.${host.platform}
    )
    names;
}
