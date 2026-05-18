{
  pkgs,
  ...
}:

{
  imports = [
    ../shared/base.nix
    ../shared/desktops/niri-noctalia
  ];

  ## ----- packages ------------------------------------------------------------
  # Shell base (../shared/base.nix) + GUI baseline (the niri-noctalia desktop).
  home.packages = with pkgs; [
    mypaint
    libreoffice
    joplin-desktop
  ];

  ## ----- programs ------------------------------------------------------------
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
