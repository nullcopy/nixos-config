{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.noctalia.homeModules.default
    inputs.nixvim.homeModules.nixvim
    ./tailscale.nix
    ./aliases.nix
    ./neovim.nix
    ./niri.nix
    ./opencode.nix
  ];

  ## ----- packages ------------------------------------------------------------
  home.packages = with pkgs; [
    brave
    nerd-fonts.jetbrains-mono
    fzf
    nautilus
    signal-desktop
    tldr
    tor-browser
    ripgrep
    rage
    qbittorrent
  ];

  ## ----- session variables ---------------------------------------------------
  home.sessionVariables = {
    BROWSER = "brave";
    TERMINAL = "alacritty";
  };

  ## ----- default applications ------------------------------------------------
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "brave-browser.desktop";
      "x-scheme-handler/http" = "brave-browser.desktop";
      "x-scheme-handler/https" = "brave-browser.desktop";
      "x-scheme-handler/about" = "brave-browser.desktop";
      "x-scheme-handler/unknown" = "brave-browser.desktop";
    };
  };

  ## ----- programs ------------------------------------------------------------
  programs.noctalia = {
    enable = true;
    # systemd startup is opt-in (programs.noctalia.systemd.enable) and left off
    # here: it causes delayed start and unreliable IPC. The shell is spawned
    # from niri's spawn-at-startup instead.
    # See https://docs.noctalia.dev/v5/getting-started/nixos/#running-the-shell
    #
    # Base config (config.toml) is left at noctalia's built-in defaults — the
    # settings UI never writes it, only ~/.local/state/noctalia/settings.toml
    # (tracked via the symlink below). To pin a base setting declaratively, set
    # it here and this module renders a read-only config.toml, e.g.:
    #   settings.shell.font_family = "JetBrainsMono Nerd Font";
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    initContent = ''
      export PATH="$HOME/.cargo/bin:$PATH"
    '';
    history = {
      path = "${config.home.homeDirectory}/.zsh_history";
      size = 100000;
      save = 100000;
      share = true;
      extended = true;
      ignoreDups = true;
      ignoreSpace = true;
    };
    historySubstringSearch = {
      enable = true;
      # Bind both cursor-mode (^[[A) and application-mode (^[OA) escapes:v
      searchUpKey = [
        "^[[A"
        "^[OA"
      ]; # Up arrow
      searchDownKey = [
        "^[[B"
        "^[OB"
      ]; # Down arrow
    };
  };

  programs.starship = {
    enable = true;
    presets = [ "gruvbox-rainbow" ];
  };

  programs.alacritty = {
    enable = true;
    settings = {
      font.normal.family = "JetBrainsMono Nerd Font";
      window.decorations = "None";
    };
  };

  # direnv: per-directory environment loader. When you `cd` into a directory
  # containing a `.envrc`, direnv exports its env into your current shell;
  # leave the directory and it unloads. nix-direnv adds the `use flake`
  # builtin so `.envrc` can be a one-liner that loads a project's devShell
  # (and caches the evaluation so repeat `cd`s are instant).
  #
  # Per-project setup:
  #   1. Project has a `flake.nix` defining `devShells.<system>.default`.
  #   2. Add a `.envrc` next to it containing:  use flake
  #   3. First time only, run `direnv allow` — direnv won't auto-execute an
  #      .envrc until you've explicitly trusted it.
  # From then on, `cd` into the project loads the toolchain defined in
  # flake.nix (cargo/rustfmt/clang/etc) into your shell automatically.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.gpg.enable = true;

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "John Boyd";
        email = "john@coldnoise.net";
      };
      core.editor = "vim";
      commit.gpgsign = true;
      tag.gpgsign = true;
    };
  };

  ## ----- noctalia UI settings -----------------------------------------------
  # v5 writes everything changed in the settings UI to its *state* dir, not the
  # config dir: ~/.local/state/noctalia/settings.toml (layered over config.toml /
  # built-in defaults). Symlink just that one file back into the flake repo so
  # in-UI changes show up as unstaged diffs. noctalia's atomic writer is
  # symlink-aware — it canonicalises the link and renames onto the real target —
  # so the single-file out-of-store symlink survives every save.
  #
  # config.toml itself is read-only (built-in defaults, or declarative via
  # programs.noctalia.settings above), so it isn't symlinked. Note: custom
  # palettes saved in the UI land in ~/.config/noctalia/palettes/ and are NOT
  # tracked here.
  home.file.".local/state/noctalia/settings.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.nixos-config/users/nullcopy/noctalia-settings.toml";

  ## ----- state version -------------------------------------------------------
  # Don't change this unless you know what you're doing
  home.stateVersion = "25.11";
}
