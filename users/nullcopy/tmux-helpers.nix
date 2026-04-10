## Tmux helper functions

{ config, lib, ... }:

{
  programs.zsh.initExtra = lib.mkAfter ''
    ## --- tmux helper functions --------------------------------------------------

    # Create (or attach to) a session rooted at a directory.
    # Usage: tnew [dir]   — defaults to $PWD
    tnew() {
      local dir="''${1:-$PWD}"
      dir="$(cd "$dir" && pwd -P)" || return 1
      local name
      name="$(basename "$dir")"
      # Disambiguate if the name is taken by a session with a different root
      local i=2
      while tmux has-session -t="$name" 2>/dev/null \
         && [ "$(tmux show-option -vt "$name" @root 2>/dev/null)" != "$dir" ]; do
        name="$(basename "$dir")-$i"; i=$((i+1))
      done
      if tmux has-session -t="$name" 2>/dev/null; then
        tmux "$([ -n "$TMUX" ] && echo switch-client || echo attach-session)" -t "$name"
      else
        TMUX= tmux new-session -d -s "$name" -c "$dir"
        tmux set-option -t "$name" @root "$dir"
        tmux "$([ -n "$TMUX" ] && echo switch-client || echo attach-session)" -t "$name"
      fi
    }
  '';
}
