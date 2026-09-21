{
  keybinds = {
    "Alt+Shift+4" = "screenshot";
    "Alt+Shift+T" = "scratchpad-toggle:TERMINAL";
    "Alt+Shift+Ctrl+T" = "scratchpad-toggle:CHAT";
    "Mod+Q" = "window-close";
    "Ctrl+Alt+Delete" = "session-quit";
    "Mod+T" = "spawn:alacritty";
    "Ctrl+Space" = "spawn:noctalia msg panel-toggle launcher";
    "Mod+Ctrl+Space" = "spawn:noctalia msg panel-toggle session";
    "Ctrl+Shift+Space" = "spawn:noctalia msg panel-toggle control-center";
    "Mod+Alt+T" = "spawn:theme-select";
    "Mod+Ctrl+B" = {
      action = "spawn:monitor-brightness up";
      allow_when_locked = true;
    };
    "Mod+Ctrl+Shift+B" = {
      action = "spawn:monitor-brightness down";
      allow_when_locked = true;
    };
    "Mod+Shift+Escape" = {
      action = "shortcuts-inhibit-toggle";
      allow_when_inhibited = true;
      repeat = false;
    };
    "Mod+O" = {
      action = "overview-toggle";
      repeat = false;
    };

    "Mod+Left" = "window-focus-left";
    "Mod+Down" = "window-focus-down";
    "Mod+Up" = "window-focus-up";
    "Mod+Right" = "window-focus-right";

    "Mod+Shift+Left" = "column-move-left";
    "Mod+Shift+Down" = "window-move-down";
    "Mod+Shift+Up" = "window-move-up";
    "Mod+Shift+Right" = "column-move-right";

    "Mod+Home" = "workspace-previous";
    "Mod+End" = "workspace-next";
    "Mod+Shift+Home" = "column-move-to-workspace-previous";
    "Mod+Shift+End" = "column-move-to-workspace-next";

    "Mod+Page_Up" = "column-focus-first";
    "Mod+Page_Down" = "column-focus-last";
    "Mod+Shift+Page_Up" = "column-move-to-first";
    "Mod+Shift+Page_Down" = "column-move-to-last";

    "Mod+V" = "window-toggle-floating";
    "Mod+Shift+V" = "window-focus-switch-floating";
    "Mod+M" = "window-toggle-maximize-to-edges";
    "Mod+R" = "window-cycle-primary-extent";
    "Mod+Shift+R" = "window-cycle-primary-extent-back";
    "Mod+Ctrl+R" = "window-cycle-secondary-extent";
    "Mod+Ctrl+Shift+R" = "window-cycle-secondary-extent-back";
    "Mod+C" = "column-center";
    "Mod+H" = "cheatsheet-toggle";
    "Mod+Shift+P" = "dpms-off";

    "Mod+Comma" = "window-consume-or-expel-left";
    "Mod+Period" = "window-consume-or-expel-right";

    "Mod+Tab" = "output-focus-next";
    "Mod+Shift+Tab" = "window-move-to-output-next";

    "Mod+S" = {
      action = "submap:resize";
      repeat = false;
    };
    "submap[resize],Escape" = "submap:reset";
    "submap[resize],Left" = "window-modify-primary-extent:-0.1";
    "submap[resize],Right" = "window-modify-primary-extent:0.1";
    "submap[resize],Up" = "window-modify-secondary-extent:-0.1";
    "submap[resize],Down" = "window-modify-secondary-extent:0.1";
    "Escape" = "submap:reset";

    "XF86AudioRaiseVolume" = "spawn:noctalia msg volume-up";
    "XF86AudioLowerVolume" = "spawn:noctalia msg volume-down";
    "XF86AudioMute" = "spawn:wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
    "XF86AudioMicMute" = "spawn:wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
    "XF86AudioNext" = "spawn:playerctl next";
    "XF86AudioPrev" = "spawn:playerctl previous";
    "XF86AudioPlay" = {
      action = "spawn:playerctl play-pause";
      allow_when_locked = true;
    };
    "XF86MonBrightnessDown" = {
      action = "spawn:monitor-brightness down";
      allow_when_locked = true;
    };
    "XF86MonBrightnessUp" = {
      action = "spawn:monitor-brightness up";
      allow_when_locked = true;
    };
  };
}
