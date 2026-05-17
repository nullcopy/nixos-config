{
  config,
  pkgs,
  ...
}:

{
  ## Desktop-agnostic baseline imported by every user regardless of which
  ## desktop they run (shell + prompt + CLI tooling). Anything tied to a
  ## particular desktop/compositor lives in users/shared/desktops/<name>/
  ## instead, and each user imports exactly one of those.
  home.packages = with pkgs; [
    fzf
  ];

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    history = {
      path = "${config.home.homeDirectory}/.zsh_history";
      size = 100000;
      save = 100000;
      share = true;
      extended = true;
      ignoreDups = true;
      ignoreSpace = true;
    };
  };

  programs.starship = {
    enable = true;
    presets = [ "gruvbox-rainbow" ];
  };
}
