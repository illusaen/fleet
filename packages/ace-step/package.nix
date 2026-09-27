{
  lib,
  ace-step-src,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
  python312,
  callPackage,
  callPackages,
  linuxPackages,
  cudaPackages,
  makeWrapper,
  ffmpeg,
}: let
  workspace = uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = ace-step-src;
  };

  uvLockedOverlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  pythonSet =
    (callPackage pyproject-nix.build.packages {
      python = python312;
    }).overrideScope (lib.composeManyExtensions [
      pyproject-build-systems.overlays.wheel
      uvLockedOverlay
    ]);

  inherit (callPackages pyproject-nix.build.util {}) mkApplication;

  # Define the localized hardware libraries here
  nvidiaLibs = [
    linuxPackages.nvidia_x11
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
  ];
in
  (mkApplication {
    venv = pythonSet.mkVirtualEnv "ace-step-env" workspace.deps.default;
    package = pythonSet.ace-step;
  }).overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [makeWrapper];
    postFixup = ''
      wrapProgram $out/bin/acestep \
        --prefix PATH : "${lib.makeBinPath [ffmpeg]}" \
        --prefix NIX_LD_LIBRARY_PATH : "${lib.makeLibraryPath nvidiaLibs}"
        --set ACESTEP_LM_BACKEND vllm
        --set ACESTEP_DEVICE cuda
        --set ACESTEP_LM_MODEL_PATH acestep-5Hz-lm-0.6B
        --set ACESTEP_CONFIG_PATH acestep-v15-turbo
    '';
  })
