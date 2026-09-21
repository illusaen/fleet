{main}: {
  window_rule =
    [
      {
        blur = true;
        blur_optimized = false;
        blur_popups = true;
        opacity = 0.9;
      }
      {
        "match.is_focused" = true;
        opacity = 1;
      }
      {
        "match.app_id" = "^scratchpad-alacritty";
        default_scratchpad = "TERMINAL";
        default_output = main;
        default_floating = true;
        default_floating_size = {
          width = 0.4;
          height = 0.5;
        };
        default_position.anchor = "top";
        opacity = 0.8;
      }
      {
        "match.title" = "^(.*)(o|O|s|S)(pen|ave) (f|F|a|a)(ile|s)(.*)";
        default_floating = true;
        default_floating_size = {
          width = 0.3;
          height = 0.4;
        };
      }
      {
        "match.app_id" = "com.github.th-ch.youtube-music";
        default_workspace = "MUSIC";
        default_floating = true;
        default_floating_size = {
          height = 0.75;
          anchor = "top";
        };
      }
      {
        "match.app_id" = "^alacritty$";
        default_scrolling_column = "alacritty";
        default_workspace = "CODE";
      }
      {
        "match.at_startup" = true;
        default_focused = false;
      }
      {
        "match.app_id" = "1password";
        "match.at_startup" = true;
        default_workspace = "CODE";
        default_focused = true;
      }
      {
        "match.app_id" = "vesktop";
        default_scratchpad = "CHAT";
        default_output = main;
        default_floating = true;
        default_floating_size = {
          width = 0.3;
          height = 1;
        };
        default_position.anchor = "right";
      }
      {
        "match.app_id" = "steam.*";
        default_workspace = "GAME";
      }
      {
        "match.title" = "Viking Rise Steam";
        default_floating = true;
        default_floating_size_px.width = 4192;
      }
      {
        "match.title" = "^notificationtoasts_.+_desktop";
        default_position = {
          x = 2;
          y = 2;
          anchor = "bottom_right";
        };
        default_focused = false;
      }
      {
        "match.app_id" = "code";
        default_scrolling_extent = 0.45;
      }
      {
        "match.app_id" = "BambuStudio";
        default_scrolling_extent = 0.6;
      }
    ]
    ++ (map (id: {
      "match.app_id" = id;
      default_floating = true;
      default_floating_size = {
        width = 0.3;
        height = 0.4;
      };
    }) ["org.pulseaudio.pavucontrol" "^(.*)blueman-manager(.*)$" "xdg-desktop-portal-gtk" "xdg-desktop-portal-umbriel" "org.gnome.Nautilus" "dev.noctalia.Noctalia"])
    ++ (map (id: {
      "match.app_id" = id;
      default_workspace = "CODE";
    }) ["google-chrome" "code"]);

  layer_rule = [
    {
      "match.namespace" = "^noctalia-bar-";
      blur = false;
    }
  ];
}
