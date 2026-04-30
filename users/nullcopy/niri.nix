{ config, pkgs, ... }:

let
  qs = "${pkgs.quickshell}/bin/qs";
  # Noctalia is launched by path, not by config name — so the only reliable
  # way to address its IPC handlers is `qs ipc -p <path>`. Resolving via
  # config.programs.noctalia-shell.package keeps this in sync across flake
  # updates instead of hardcoding a /nix/store hash.
  shellPath = "${config.programs.noctalia-shell.package}/share/noctalia-shell/shell.qml";

  # Helper: noctalia bind with a friendly hotkey-overlay title.
  nocta =
    title: target: fn:
    ''hotkey-overlay-title="${title}" { spawn "${qs}" "ipc" "-p" "${shellPath}" "call" "${target}" "${fn}"; }'';

  # Helper: noctalia bind hidden from the overlay (used for XF86 keys),
  # also passable through the lock screen.
  noctaSilent =
    target: fn:
    ''allow-when-locked=true hotkey-overlay-title=null { spawn "${qs}" "ipc" "-p" "${shellPath}" "call" "${target}" "${fn}"; }'';
in

{
  ## ----- niri ----------------------------------------------------------------
  # Niri's bundled default config references fuzzel/swaylock — apps we don't
  # ship. This file replaces the launcher/lock/etc. bindings with calls into
  # Noctalia's IPC. Discover more commands at:
  # https://docs.noctalia.dev/v4/getting-started/keybinds/
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
    }

    binds {
        // ----- Niri ----------------------------------------------------------
        Mod+Shift+Slash hotkey-overlay-title="Show this help"     { show-hotkey-overlay; }
        Mod+Shift+E     hotkey-overlay-title="Quit niri"          { quit; }

        // ----- Apps ----------------------------------------------------------
        Mod+T           hotkey-overlay-title="Terminal (alacritty)" { spawn "alacritty"; }
        Mod+B           hotkey-overlay-title="Browser (brave)"      { spawn "brave"; }

        // ----- Noctalia panels ----------------------------------------------
        Mod+Space   ${nocta "Launcher" "launcher" "toggle"}
        Mod+Shift+V ${nocta "Clipboard history" "launcher" "clipboard"}
        Mod+Period  ${nocta "Emoji picker" "launcher" "emoji"}
        Mod+Tab     ${nocta "Window switcher" "launcher" "windows"}
        Mod+Alt+L   ${nocta "Lock screen" "lockScreen" "lock"}
        Mod+Escape  ${nocta "Session menu" "sessionMenu" "toggle"}
        Mod+N       ${nocta "Notification history" "notifications" "toggleHistory"}
        Mod+Shift+N ${nocta "Toggle DND" "notifications" "toggleDND"}
        Mod+Comma   ${nocta "Settings" "settings" "toggle"}
        Mod+Shift+C ${nocta "Control center" "controlCenter" "toggle"}
        Mod+Shift+W ${nocta "Wallpaper picker" "wallpaper" "toggle"}
        Mod+Shift+B ${nocta "Toggle bar" "bar" "toggle"}
        Mod+Shift+D ${nocta "Toggle dark mode" "darkMode" "toggle"}

        // ----- Media / volume / brightness (route through Noctalia OSD) -----
        XF86AudioRaiseVolume  ${noctaSilent "volume" "increase"}
        XF86AudioLowerVolume  ${noctaSilent "volume" "decrease"}
        XF86AudioMute         ${noctaSilent "volume" "muteOutput"}
        XF86AudioMicMute      ${noctaSilent "volume" "muteInput"}
        XF86MonBrightnessUp   ${noctaSilent "brightness" "increase"}
        XF86MonBrightnessDown ${noctaSilent "brightness" "decrease"}
        XF86AudioPlay         ${noctaSilent "media" "playPause"}
        XF86AudioNext         ${noctaSilent "media" "next"}
        XF86AudioPrev         ${noctaSilent "media" "previous"}

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
        Mod+BracketLeft        hotkey-overlay-title="Consume/expel left"  { consume-or-expel-window-left; }
        Mod+BracketRight       hotkey-overlay-title="Consume/expel right" { consume-or-expel-window-right; }
        Mod+Shift+BracketLeft  hotkey-overlay-title="Expel from column"   { expel-window-from-column; }
        Mod+Shift+BracketRight hotkey-overlay-title="Consume into column" { consume-window-into-column; }

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
  '';
}
