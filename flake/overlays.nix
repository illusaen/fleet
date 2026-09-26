{
  inputs,
  lib,
}: [
  inputs.devshell.overlays.default
  inputs.agenix.overlays.default
  inputs.colmena.overlays.default
  inputs.pydot.overlays.default
  inputs.noctalia.overlays.default
  inputs.umbriel.overlays.default
  inputs.umbriel.inputs.xdg-desktop-portal-umbriel.overlays.default

  (import ./packages.nix {inherit lib;})

  (_final: prev: {
    nautilus = prev.nautilus.overrideAttrs (oldAttrs: {
      buildInputs =
        (oldAttrs.buildInputs or [])
        ++ (with prev.gst_all_1; [
          gst-plugins-good
          gst-plugins-bad
        ]);
    });
  })

  (_final: prev: {
    bambu-studio = prev.bambu-studio.overrideAttrs (oldAttrs: {
      postFixup =
        (oldAttrs.postFixup or "")
        + ''
          wrapProgram $out/bin/bambu-studio \
            --set GBM_BACKEND "dri" \
            --set WEBKIT_DISABLE_DMABUF_RENDERER "1" \
            --set WEBKIT_DISABLE_COMPOSITING_MODE "1" \
            --set __GLX_VENDOR_LIBRARY_NAME "mesa" \
            --set __EGL_VENDOR_LIBRARY_FILENAMES "/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json" \
            --set MESA_LOADER_DRIVER_OVERRIDE "zink" \
            --set GALLIUM_DRIVER "zink"
        '';
    });
  })

  (_final: prev: {
    llama-cpp-cuda =
      (prev.llama-cpp.override {
        cudaSupport = true;
      }).overrideAttrs (oldAttrs: {
        passthru =
          (oldAttrs.passthru or {})
          // {
            cudaSupport = true;
          };
      });
  })

  (_final: prev: {
    vscode = prev.vscode.override {
      commandLineArgs = "--password-store=gnome-libsecret";
    };
  })
]
