{
  lib,
  ace-step-src,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
  python312,
  stdenv,
  callPackage,
  callPackages,
  linuxPackages,
  cudaPackages,
  tbb,
  libsndfile,
  makeWrapper,
  ffmpeg_8,
}: let
  workspace = uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = ace-step-src;
  };

  uvLockedOverlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  addBuildInputs = prev: package: dependencies:
    prev.${package}.overrideAttrs (old: {
      buildInputs = (old.buildInputs or []) ++ dependencies;
      preFixup =
        (old.preFixup or "")
        + ''
          for dependency in ${lib.escapeShellArgs dependencies}; do
            while IFS= read -r -d "" libraryPath; do
              addAutoPatchelfSearchPath "$libraryPath"
            done < <(find "$dependency" -type d -name lib -print0)
          done
        '';
    });

  # CUDA wheels keep their shared libraries in separate Python packages.
  # Make those packages visible while autoPatchelf fixes the dependent wheel.
  cudaWheelOverlay = final: prev: let
    addCudaBuildInputs = addBuildInputs prev;
  in {
    nvidia-cudnn-cu12 = addCudaBuildInputs "nvidia-cudnn-cu12" [final.nvidia-cublas-cu12];

    nvidia-cufft-cu12 = addCudaBuildInputs "nvidia-cufft-cu12" [final.nvidia-nvjitlink-cu12];

    nvidia-cusparse-cu12 = addCudaBuildInputs "nvidia-cusparse-cu12" [final.nvidia-nvjitlink-cu12];

    nvidia-cusolver-cu12 = addCudaBuildInputs "nvidia-cusolver-cu12" (with final; [
      nvidia-cublas-cu12
      nvidia-cusparse-cu12
      nvidia-nvjitlink-cu12
    ]);

    # NVSHMEM ships optional plugins for fabrics that ACE-Step does not use.
    nvidia-nvshmem-cu12 = prev.nvidia-nvshmem-cu12.overrideAttrs {
      autoPatchelfIgnoreMissingDeps = [
        "libfabric.so.1"
        "libucs.so.0"
        "libucp.so.0"
        "libmlx5.so.1"
        "liboshmem.so.40"
        "libmpi.so.40"
        "libpmix.so.2"
      ];
    };

    # GPUDirect Storage's RDMA plugin is optional as well.
    nvidia-cufile-cu12 = prev.nvidia-cufile-cu12.overrideAttrs {
      autoPatchelfIgnoreMissingDeps = [
        "libmlx5.so.1"
        "librdmacm.so.1"
        "libibverbs.so.1"
      ];
    };

    torch = addCudaBuildInputs "torch" ((with final; [
        nvidia-cublas-cu12
        nvidia-cuda-cupti-cu12
        nvidia-cuda-nvrtc-cu12
        nvidia-cuda-runtime-cu12
        nvidia-cudnn-cu12
        nvidia-cufft-cu12
        nvidia-cufile-cu12
        nvidia-curand-cu12
        nvidia-cusolver-cu12
        nvidia-cusparse-cu12
        nvidia-cusparselt-cu12
        nvidia-nccl-cu12
        nvidia-nvjitlink-cu12
        nvidia-nvshmem-cu12
        nvidia-nvtx-cu12
      ])
      ++ [linuxPackages.nvidia_x11]);

    torchao = addCudaBuildInputs "torchao" (with final; [
      torch
      nvidia-cuda-runtime-cu12
    ]);

    torchaudio = addCudaBuildInputs "torchaudio" (with final; [
      torch
      nvidia-cuda-runtime-cu12
    ]);

    torchvision = addCudaBuildInputs "torchvision" (with final; [
      torch
      nvidia-cuda-runtime-cu12
    ]);
  };

  pythonOverlay = final: prev: {
    ace-step = prev.ace-step.overrideAttrs (old: {
      postInstall =
        (old.postInstall or "")
        + ''
          substituteInPlace "$out/${python312.sitePackages}/acestep/acestep_v15_pipeline.py" \
            --replace-fail \
              'output_dir = os.path.join(project_root, "gradio_outputs")' \
              'output_dir = os.environ.get("ACESTEP_OUTPUT_DIR", os.path.join(os.getcwd(), "gradio_outputs"))'
          substituteInPlace \
            "$out/${python312.sitePackages}/acestep/ui/gradio/api/api_routes.py" \
            "$out/${python312.sitePackages}/acestep/ui/gradio/events/results/generation_info.py" \
            --replace-fail \
              'DEFAULT_RESULTS_DIR = os.path.join(PROJECT_ROOT, "gradio_outputs").replace("\\", "/")' \
              'DEFAULT_RESULTS_DIR = os.environ.get("ACESTEP_OUTPUT_DIR", os.path.join(os.getcwd(), "gradio_outputs")).replace("\\", "/")'
          substituteInPlace "$out/${python312.sitePackages}/acestep/inference.py" \
            --replace-fail \
              'results_root = os.path.join(os.getcwd(), "gradio_outputs")' \
              'results_root = os.environ.get("ACESTEP_OUTPUT_DIR", os.path.join(os.getcwd(), "gradio_outputs"))'
          substituteInPlace "$out/${python312.sitePackages}/acestep/ui/gradio/events/generation/service_init.py" \
            --replace-fail \
              'checkpoint_dir = os.path.join(project_root, "checkpoints")' \
              'checkpoint_dir = os.path.expanduser(os.environ.get("ACESTEP_CHECKPOINTS_DIR", os.path.join(project_root, "checkpoints")))'
          substituteInPlace "$out/${python312.sitePackages}/acestep/ui/gradio/events/results/session_artifacts.py" \
            --replace-fail \
              'results_root = Path.cwd() / "gradio_outputs"' \
              'results_root = Path(os.environ.get("ACESTEP_OUTPUT_DIR", Path.cwd() / "gradio_outputs"))'
        '';
    });

    torchcodec = (addBuildInputs prev "torchcodec" [final.torch ffmpeg_8]).overrideAttrs (old: {
      postInstall =
        (old.postInstall or "")
        + ''
          # The wheel contains modules for FFmpeg 4-8; nixpkgs provides FFmpeg 8.
          rm "$out/${python312.sitePackages}/torchcodec/"*{4,5,6,7}.so
        '';
    });

    numba = addBuildInputs prev "numba" [tbb];

    # ACE-Step directly uses the newer typer-slim, while Gradio pulls in the
    # full typer distribution. They provide the same Python module, so retain
    # typer's metadata/dependencies but let typer-slim supply the module.
    typer = prev.typer.overrideAttrs (old: {
      postInstall =
        (old.postInstall or "")
        + ''
          rm -r "$out/${python312.sitePackages}/typer"
        '';
    });
  };

  pythonSet =
    (callPackage pyproject-nix.build.packages {
      python = python312;
    }).overrideScope (lib.composeManyExtensions (
      [
        pyproject-build-systems.overlays.wheel
        uvLockedOverlay
        pythonOverlay
      ]
      ++ lib.optional stdenv.hostPlatform.isx86_64 cudaWheelOverlay
    ));

  inherit (callPackages pyproject-nix.build.util {}) mkApplication;

  # Define the localized hardware libraries here
  nvidiaLibs = [
    linuxPackages.nvidia_x11
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
  ];

  # PyTorch's cuDNN wheel loads its component libraries (such as
  # libcudnn_graph.so) by name at runtime.  autoPatchelf fixes direct ELF
  # dependencies, but it cannot see these dlopen calls, so make the matching
  # wheel directory available to the dynamic loader.  Use the wheel rather
  # than cudaPackages.cudnn here to keep all cuDNN components on the same
  # version as the libcudnn.so linked by torch.
  cudnnWheelLib = "${pythonSet.nvidia-cudnn-cu12}/${python312.sitePackages}/nvidia/cudnn/lib";
in
  (mkApplication {
    venv = pythonSet.mkVirtualEnv "ace-step-env" workspace.deps.default;
    package = pythonSet.ace-step;
  }).overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [makeWrapper];
    postFixup = ''
      wrapProgram $out/bin/acestep \
        --prefix PATH : "${lib.makeBinPath [ffmpeg_8 stdenv.cc]}" \
        --prefix LD_LIBRARY_PATH : "/run/opengl-driver/lib:${lib.makeLibraryPath [libsndfile]}:${cudnnWheelLib}" \
        --prefix NIX_LD_LIBRARY_PATH : "${lib.makeLibraryPath nvidiaLibs}" \
        --set ACESTEP_LM_BACKEND vllm \
        --set ACESTEP_DEVICE cuda \
        --set ACESTEP_LM_MODEL_PATH acestep-5Hz-lm-0.6B \
        --set ACESTEP_CONFIG_PATH acestep-v15-turbo \
        --set CC ${stdenv.cc}/bin/cc \
        --set TRITON_LIBCUDA_PATH /run/opengl-driver/lib
    '';
  })
