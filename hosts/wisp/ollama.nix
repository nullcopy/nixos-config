{ pkgs, ... }:

{
  ## ----- iGPU memory (GTT) ---------------------------------------------------
  # Strix Halo's iGPU shares system RAM via GTT. The kernel caps GTT at ~half
  # of total RAM by default (~48 GB here); raise to 72 GB so a Q5_K_M 70B at
  # 32k context (~63 GB working set) fits with headroom. GTT is dynamic — the
  # OS reclaims pages whenever the iGPU isn't using them.
  #
  # Value is in 4 KiB pages: 72 * 1024^3 / 4096 = 18874368.
  boot.kernelParams = [
    "ttm.pages_limit=18874368"
    "ttm.page_pool_size=18874368"
  ];

  ## ----- ollama --------------------------------------------------------------
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    host = "127.0.0.1";
    environmentVariables = {
      OLLAMA_FLASH_ATTENTION = "1";
    };
  };
}
