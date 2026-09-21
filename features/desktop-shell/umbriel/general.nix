{
  main,
  secondary,
  cursor,
}: {
  "include.optional".files = [];
  general = {
    xwayland = false;
    show_cheatsheet = false;
    autostart = ["alacritty --class scratchpad-alacritty"];
  };
  "output.${main}" = {
    enabled = true;
    mode = "5120x2160@165.058";
    workspaces = "dynamic";
  };
  "output.${secondary}" = {
    enabled = true;
    mode = "1920x1080@60";
    transform = "270";
    workspaces = "dynamic";
  };
  "output.${secondary}.layout.scrolling".default_extent_fraction = 1;
  "workspace" = [
    {
      name = "GAME";
      output = main;
    }
    {
      name = "CODE";
      output = main;
    }
    {
      name = "MUSIC";
      output = secondary;
    }
  ];
  scratchpad = [{name = "TERMINAL";} {name = "CHAT";}];
  appearance = {
    border_width = 0;
    corner_radius = 12;
  };
  input.middle_click_paste = false;
  "input.mouse" = {
    natural_scroll = true;
    scroll_button = "MouseMiddle";
    scroll_wheel_step = 100;
  };
  "input.cursor" = {
    theme = cursor.name;
    inherit (cursor) size;
  };
  layout = {
    mode = "scrolling";
    extent_presets = [0.333 0.667 1];
  };
  "layout.scrolling" = {
    default_extent_fraction = 0.333;
    center_focused = "on_overflow";
  };
  "animation.scratchpad" = {
    enabled = true;
    blur = true;
  };
  "animation.dim_unfocused".enabled = true;
}
