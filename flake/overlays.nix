{
  inputs,
  lib,
}: [
  inputs.devshell.overlays.default
  inputs.agenix.overlays.default
  inputs.colmena.overlays.default
  inputs.millennium.overlays.default
  inputs.pydot.overlays.default
  inputs.noctalia.overlays.default
  inputs.noctalia-greeter.overlays.default
  inputs.umbriel.overlays.default
  inputs.umbriel.inputs.xdg-desktop-portal-umbriel.overlays.default

  (import ./packages.nix {inherit lib inputs;})

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

  (_final: prev: {
    google-chrome = prev.google-chrome.override {
      commandLineArgs = "--force-device-scale-factor=1.1";
    };
  })
]
