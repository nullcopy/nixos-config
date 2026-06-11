{
  config,
  lib,
  pkgs,
  ...
}:

let
  # noctalia v5 is a single compiled binary. The same executable is both the
  # shell daemon and the IPC client: `noctalia` (no args) runs the shell, while
  # `noctalia msg <command>` talks to the running instance over its unix socket.
  # (v4's `noctalia-shell ipc call <ns> <fn>` is gone — commands are now flat
  # verbs like `panel-toggle`, `volume-up`, `media toggle`. Discover them with
  # `noctalia msg --help`.) See https://docs.noctalia.dev/v5/getting-started/nixos/
  noctalia = "${config.programs.noctalia.package}/bin/noctalia";

  # Render a niri `spawn` of `noctalia msg <command>`. `cmd` is a space-separated
  # command string; each word becomes its own quoted token because niri's `spawn`
  # takes argv as separate strings (the msg CLI re-joins them before dispatching).
  # No noctalia command argument contains spaces, so splitting on " " is safe.
  msg =
    cmd:
    ''spawn "${noctalia}" "msg" ''
    + lib.concatMapStringsSep " " (a: ''"${a}"'') (lib.splitString " " cmd);

  # Helper: noctalia bind with a friendly hotkey-overlay title.
  nocta = title: cmd: ''hotkey-overlay-title="${title}" { ${msg cmd}; }'';

  # Helper: noctalia bind hidden from the overlay (used for XF86 keys),
  # also passable through the lock screen.
  noctaSilent = cmd: "allow-when-locked=true hotkey-overlay-title=null { ${msg cmd}; }";
in

{
  ## ----- niri ----------------------------------------------------------------
  # Niri's bundled default config references fuzzel/swaylock — apps we don't
  # ship. This file replaces the launcher/lock/etc. bindings with calls into
  # Noctalia's IPC. Discover more commands at:
  # https://docs.noctalia.dev/v5/getting-started/keybinds/
  xdg.configFile."niri/config.kdl".force = true;
  xdg.configFile."niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                layout "us"
            }
        }
        touchpad {
            tap
            natural-scroll
        }
        focus-follows-mouse
    }

    // Launch Noctalia with niri (replaces the deprecated systemd unit).
    spawn-at-startup "${noctalia}"

    binds {
        // ----- Niri ----------------------------------------------------------
        Mod+Shift+Slash hotkey-overlay-title="Show this help"     { show-hotkey-overlay; }
        Mod+Shift+E     hotkey-overlay-title="Quit niri"          { quit; }

        // ----- Apps ----------------------------------------------------------
        Mod+T           hotkey-overlay-title="Terminal (alacritty)" { spawn "alacritty"; }
        Mod+B           hotkey-overlay-title="Browser (brave)"      { spawn "brave"; }

        // ----- Noctalia panels ----------------------------------------------
        Mod+Space   ${nocta "Launcher" "panel-toggle launcher"}
        Mod+Shift+V ${nocta "Clipboard history" "panel-toggle clipboard"}
        Mod+Period  ${nocta "Emoji picker" "panel-toggle launcher /emo"}
        Mod+Tab     ${nocta "Window switcher" "window-switcher"}
        Mod+Alt+L   ${nocta "Lock screen" "session lock"}
        Mod+Escape  ${nocta "Session menu" "panel-toggle session"}
        Mod+N       ${nocta "Notification history" "panel-toggle control-center notifications"}
        Mod+Shift+N ${nocta "Toggle DND" "notification-dnd-toggle"}
        Mod+Comma   ${nocta "Settings" "settings-toggle"}
        Mod+Shift+C ${nocta "Control center" "panel-toggle control-center"}
        Mod+Shift+W ${nocta "Wallpaper picker" "panel-toggle wallpaper"}
        Mod+Shift+B ${nocta "Toggle bar" "bar-toggle"}
        Mod+Shift+D ${nocta "Toggle dark mode" "theme-mode-toggle"}

        // ----- Media / volume / brightness (route through Noctalia OSD) -----
        XF86AudioRaiseVolume  ${noctaSilent "volume-up"}
        XF86AudioLowerVolume  ${noctaSilent "volume-down"}
        XF86AudioMute         ${noctaSilent "volume-mute"}
        XF86AudioMicMute      ${noctaSilent "mic-mute"}
        XF86MonBrightnessUp   ${noctaSilent "brightness-up"}
        XF86MonBrightnessDown ${noctaSilent "brightness-down"}
        XF86AudioPlay         ${noctaSilent "media toggle"}
        XF86AudioNext         ${noctaSilent "media next"}
        XF86AudioPrev         ${noctaSilent "media previous"}

        // ----- Screenshots (grim/slurp/satty are in common/desktop.nix) -----
        Print           hotkey-overlay-title="Screenshot region"  { spawn "sh" "-c" "grim -g \"$(slurp)\" - | satty --filename -"; }
        Mod+Print       hotkey-overlay-title="Screenshot window"  { screenshot-window; }
        Ctrl+Print      hotkey-overlay-title="Screenshot screen"  { screenshot-screen; }

        // ----- Window management --------------------------------------------
        Mod+Q                  hotkey-overlay-title="Close window"        { close-window; }
        Mod+O                  hotkey-overlay-title="Toggle overview"     { toggle-overview; }
        Mod+F                  hotkey-overlay-title="Maximize column"     { maximize-column; }
        Mod+Shift+F            hotkey-overlay-title="Fullscreen window"   { fullscreen-window; }
        Mod+V                  hotkey-overlay-title="Toggle floating"     { toggle-window-floating; }
        Mod+R                  hotkey-overlay-title="Cycle column width"  { switch-preset-column-width; }
        Mod+C                  hotkey-overlay-title="Center column"       { center-column; }
        Mod+Shift+BracketLeft  hotkey-overlay-title="Consume/expel left"  { consume-or-expel-window-left; }
        Mod+Shift+BracketRight hotkey-overlay-title="Consume/expel right" { consume-or-expel-window-right; }

        // ----- Focus (arrows + vim) -----------------------------------------
        Mod+Left        hotkey-overlay-title=null { focus-column-left; }
        Mod+Right       hotkey-overlay-title=null { focus-column-right; }
        Mod+Up          hotkey-overlay-title=null { focus-window-up; }
        Mod+Down        hotkey-overlay-title=null { focus-window-down; }
        Mod+H           hotkey-overlay-title="Focus column left"  { focus-column-left; }
        Mod+J           hotkey-overlay-title="Focus window down"  { focus-window-down; }
        Mod+K           hotkey-overlay-title="Focus window up"    { focus-window-up; }
        Mod+L           hotkey-overlay-title="Focus column right" { focus-column-right; }

        // ----- Move windows -------------------------------------------------
        Mod+Shift+Left  hotkey-overlay-title=null { move-column-left; }
        Mod+Shift+Right hotkey-overlay-title=null { move-column-right; }
        Mod+Shift+Up    hotkey-overlay-title=null { move-window-up; }
        Mod+Shift+Down  hotkey-overlay-title=null { move-window-down; }
        Mod+Shift+H     hotkey-overlay-title="Move column left"  { move-column-left; }
        Mod+Shift+J     hotkey-overlay-title="Move window down"  { move-window-down; }
        Mod+Shift+K     hotkey-overlay-title="Move window up"    { move-window-up; }
        Mod+Shift+L     hotkey-overlay-title="Move column right" { move-column-right; }

        // ----- Workspaces ---------------------------------------------------
        Mod+Page_Up           hotkey-overlay-title="Workspace up"             { focus-workspace-up; }
        Mod+Page_Down         hotkey-overlay-title="Workspace down"           { focus-workspace-down; }
        Mod+Shift+Page_Up     hotkey-overlay-title="Move column workspace up" { move-column-to-workspace-up; }
        Mod+Shift+Page_Down   hotkey-overlay-title="Move column workspace down" { move-column-to-workspace-down; }
        Mod+1 hotkey-overlay-title="Workspace 1" { focus-workspace 1; }
        Mod+2 hotkey-overlay-title=null { focus-workspace 2; }
        Mod+3 hotkey-overlay-title=null { focus-workspace 3; }
        Mod+4 hotkey-overlay-title=null { focus-workspace 4; }
        Mod+5 hotkey-overlay-title=null { focus-workspace 5; }
        Mod+Shift+1 hotkey-overlay-title="Move column to workspace N" { move-column-to-workspace 1; }
        Mod+Shift+2 hotkey-overlay-title=null { move-column-to-workspace 2; }
        Mod+Shift+3 hotkey-overlay-title=null { move-column-to-workspace 3; }
        Mod+Shift+4 hotkey-overlay-title=null { move-column-to-workspace 4; }
        Mod+Shift+5 hotkey-overlay-title=null { move-column-to-workspace 5; }
    }

    switch-events {
        // Lock screen on laptop lid close
        lid-close { ${msg "session lock"}; }
    }
  '';
}
