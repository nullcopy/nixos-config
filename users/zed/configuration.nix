{
  config,
  pkgs,
  inputs,
  ...
}:

{
  ## ----- packages ------------------------------------------------------------
  home.packages = with pkgs; [
    brave
    fzf
  ];

  ## ----- programs ------------------------------------------------------------
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

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = ""; # fill in
        email = ""; # fill in
      };
      core.editor = "vim";
    };
  };

  ## ----- state version -------------------------------------------------------
  home.stateVersion = "25.11";
}
