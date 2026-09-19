{
  modules.nixos = {
    pkgs,
    lib,
    options,
    ...
  }:
    lib.mkMerge [
      {
        environment.systemPackages = with pkgs; [
          inkscape
          bambu-studio
          image-roll
        ];

        xdg.mime.defaultApplications."image/*" = "com.github.weclaw1.ImageRoll.desktop";

        nixpkgs.overlays = [
          (_final: prev: {
            bambu-studio = prev.bambu-studio.overrideAttrs (oldAttrs: {
              buildInputs = oldAttrs.buildInputs or [];
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
        ];
      }
      (lib.optionalAttrs (options ? persistUser) {
        persistUser.directories = [".config/BambuStudio"];
      })
    ];
}
