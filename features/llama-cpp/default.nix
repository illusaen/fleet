{
  modules.nixos = {
    host,
    pkgs,
    helpers,
    ...
  }: let
    service = helpers.requireRoutedService host "llama-cpp";
    iniFormat = pkgs.formats.ini {};
    llamaCpp =
      (pkgs.llama-cpp.override {
        cudaSupport = true;
      }).overrideAttrs (old: {
        passthru =
          (old.passthru or {})
          // {
            cudaSupport = true;
          };
      });
  in {
    environment.systemPackages = [llamaCpp];

    services.llama-cpp = {
      enable = true;
      openFirewall = true;
      package = llamaCpp;
      settings = {
        host = "0.0.0.0";
        inherit (service) port;
        models-preset = iniFormat.generate "llama-cpp-models.ini" {
          "*" = {
            context-shift = true;
          };
          "Qwen3.5-9B" = {
            hf-repo = "unsloth/Qwen3.5-9B-GGUF";
            hf-file = "Qwen3.5-9B-UD-Q4_K_XL.gguf";
            alias = "unsloth/Qwen3.5-9B";
            temp = "1.0";
            top-p = "0.95";
            top-k = "20";
            presence-penalty = "1.5";
            repeat-penalty = "1.0";
          };
          "Qwen3-Coder-Next" = {
            hf-repo = "unsloth/Qwen3-Coder-Next-GGUF";
            hf-file = "Qwen3-Coder-Next-UD-IQ2_XXS.gguf";
            alias = "unsloth/Qwen3-Coder-Next";
            temp = "1.0";
            top-p = "0.95";
            top-k = "40";
            presence-penalty = "1.5";
            repeat-penalty = "1.0";
          };
        };
      };
    };
  };
}
