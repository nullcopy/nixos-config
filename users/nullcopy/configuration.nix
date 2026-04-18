{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  # Noctalia config files seeded into ~/.config/noctalia/ on first activation
  # as writable files so the noctalia UI can save back. After seeding,
  # subsequent rebuilds leave them alone — the drift report below shows what
  # changed in the live copy, so it can be captured back into the flake with:
  #   cp ~/.config/noctalia/{settings,colors,plugins}.json users/nullcopy/noctalia/
  noctaliaSeed = [
    "settings.json"
    "colors.json"
    "plugins.json"
  ];

  # Top-level basenames under ~/.config/noctalia/ to omit from the drift
  # report — e.g. runtime state files noctalia writes that shouldn't be
  # tracked in the flake.
  noctaliaDriftExcludes = [ ];
in
{
  imports = [
    inputs.noctalia.homeModules.default
    inputs.nixvim.homeModules.nixvim
    ./tailscale.nix
    ./git-aliases.nix
    ./neovim.nix
  ];

  ## ----- packages ------------------------------------------------------------
  home.packages = with pkgs; [
    brave
    nerd-fonts.jetbrains-mono
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
  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;
    # settings/colors/plugins are intentionally NOT passed here — the upstream
    # module would symlink them read-only from /nix/store, breaking the noctalia
    # UI's ability to save changes. They're seeded as writable files via the
    # home.activation.noctaliaSeed block below.
  };

  # Plugin sources are read-only assets — fine to symlink from the store.
  # (The noctalia home-manager module installs the shell but not plugin code.)
  xdg.configFile."noctalia/plugins/catwalk".source = ./noctalia/plugins/catwalk;

  # Seed JSON config files into ~/.config/noctalia/ on first activation, or
  # heal them if they're missing or still a leftover store symlink.
  home.activation.noctaliaSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfg="$HOME/.config/noctalia"
    src=${./noctalia}
    run mkdir -p "$cfg"
    for f in ${lib.concatStringsSep " " noctaliaSeed}; do
      if [ ! -e "$cfg/$f" ] || [ -L "$cfg/$f" ]; then
        run rm -f "$cfg/$f"
        run install -m 0644 "$src/$f" "$cfg/$f"
      fi
    done
  '';

  # Drift report: compare the live ~/.config/noctalia/ against the flake copy
  # and print actionable cp/rm commands. Read-only — never touches the live dir.
  home.activation.noctaliaDrift = lib.hm.dag.entryAfter [ "noctaliaSeed" ] ''
      cfg="$HOME/.config/noctalia"
      src=${./noctalia}
      seed="${lib.concatStringsSep " " noctaliaSeed}"
      excludes="${lib.concatStringsSep " " noctaliaDriftExcludes}"

      report=""
      for f in $seed; do
        if [ ! -e "$cfg/$f" ]; then
          report="$report
    - $f      (missing in live; rerun to reseed from flake)"
        elif ! diff -q "$src/$f" "$cfg/$f" >/dev/null 2>&1; then
          report="$report
    M $f      cp ~/.config/noctalia/$f users/nullcopy/noctalia/$f"
        fi
      done

      if [ -d "$cfg" ]; then
        for path in "$cfg"/*; do
          [ -e "$path" ] || continue
          f="''${path##*/}"
          # Skip seeded files (already reported above).
          case " $seed " in *" $f "*) continue ;; esac
          # Skip explicitly excluded basenames.
          case " $excludes " in *" $f "*) continue ;; esac
          # Skip the read-only plugins/ dir managed via xdg.configFile.
          [ "$f" = "plugins" ] && continue
          report="$report
    ? $f      rm -r ~/.config/noctalia/$f   # or add to noctaliaDriftExcludes"
        done
      fi

      if [ -n "$report" ]; then
        echo
        echo "noctalia drift (live vs. flake):$report"
        echo
      fi
  '';

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    historySubstringSearch = {
      enable = true;
      searchUpKey = [ "^[[A" ]; # Up arrow
      searchDownKey = [ "^[[B" ]; # Down arrow
    };
  };

  programs.starship = {
    enable = true;
    presets = [ "gruvbox-rainbow" ];
  };

  programs.alacritty = {
    enable = true;
    settings.font.normal.family = "JetBrainsMono Nerd Font";
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "John Boyd";
        email = "john@coldnoise.net";
      };
      core.editor = "vim";
    };
  };

  ## ----- state version -------------------------------------------------------
  # Don't change this unless you know what you're doing
  home.stateVersion = "25.11";
}
