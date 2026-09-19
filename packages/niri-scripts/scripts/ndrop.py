#!/usr/bin/env python3
"""Toggle a Niri drop-down application instance.

The drop-down instance is identified by a dedicated Wayland app-id. Launch the
regular app with its normal app-id to keep it in the scrolling layout.

Examples:
    ndrop --app-id ndrop-foot -- foot --app-id ndrop-foot
    ndrop --app-id ndrop-obsidian -- obsidian --class ndrop-obsidian
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path


def niri_json(*args):
    result = subprocess.run(
        ["niri", "msg", "--json", *args], capture_output=True, text=True, check=True
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "unknown error"
        raise RuntimeError(f"niri msg {' '.join(args)} failed: {detail}")
    return json.loads(result.stdout)


def niri_action(*args):
    subprocess.run(["niri", "msg", "action", *args], check=True)


def field(value, *names):
    for name in names:
        if name in value:
            return value[name]
    return None


def window_id(window):
    identifier = field(window, "id")
    return None if identifier is None else int(identifier)


def app_id(window):
    return field(window, "app_id", "app-id", "appId")


def window_workspace_id(window):
    return field(window, "workspace_id", "workspace-id", "workspaceId")


def workspace_id(workspace):
    return field(workspace, "id", "workspace_id", "workspace-id", "workspaceId")


def workspace_name(value):
    return field(value, "workspace_name", "workspace-name", "workspaceName", "name")


def workspace_index(value):
    return field(value, "idx", "index")


def is_focused(value):
    return bool(field(value, "is_focused", "is-focused", "isFocused", "focused"))


def focused_workspace():
    workspaces = niri_json("workspaces")
    for workspace in workspaces:
        if is_focused(workspace):
            return workspace
    raise RuntimeError("niri did not report a focused workspace")


def workspace_reference(workspace):
    name = workspace_name(workspace)
    if name:
        return str(name)

    index = workspace_index(workspace)
    if index is not None:
        return str(index)

    identifier = workspace_id(workspace)
    if identifier is not None:
        return str(identifier)

    raise RuntimeError(f"cannot determine workspace reference from {workspace!r}")


def window_workspace_matches(window, workspace):
    win_ws = window_workspace_id(window)
    current_ws = workspace_id(workspace)
    if win_ws is not None and current_ws is not None:
        return win_ws == current_ws

    win_ws_name = workspace_name(window)
    current_ws_name = workspace_name(workspace)
    return bool(win_ws_name and current_ws_name and win_ws_name == current_ws_name)


def matching_windows(target_app_id):
    pattern = re.compile(target_app_id)
    return [
        window
        for window in niri_json("windows")
        if app_id(window) and pattern.search(str(app_id(window)))
    ]


def all_windows():
    return niri_json("windows")


def state_file(name):
    state_home = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
    return state_home / "ndrop" / f"{name}.json"


def load_state_window(name, windows):
    path = state_file(name)
    try:
        state = json.loads(path.read_text())
        state_window_id = int(state["window_id"])
    except (FileNotFoundError, KeyError, ValueError, json.JSONDecodeError):
        return None

    for window in windows:
        if window_id(window) == state_window_id:
            return window
    return None


def save_state_window(name, window):
    identifier = window_id(window)
    if identifier is None:
        return

    path = state_file(name)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"window_id": identifier}) + "\n")


def choose_window(windows):
    if not windows:
        return None

    for window in windows:
        if is_focused(window):
            return window

    return max(windows, key=lambda window: window_id(window) or 0)[-1]


def find_new_window(previous_window_ids):
    new_windows = [
        window
        for window in all_windows()
        if window_id(window) is not None
        and window_id(window) not in previous_window_ids
    ]
    return choose_window(new_windows)


def wait_for_window(target_app_id, previous_window_ids, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        window = choose_window(matching_windows(target_app_id))
        if window:
            return window
        window = find_new_window(previous_window_ids)
        if window:
            return window
        time.sleep(0.1)
    return None


def show_window(window, workspace_ref):
    window_id = str(field(window, "id"))
    niri_action(
        "move-window-to-workspace",
        "--window-id",
        window_id,
        "--focus",
        "true",
        workspace_ref,
    )
    niri_action("move-window-to-floating", "--id", window_id)
    niri_action("focus-window", "--id", window_id)


def hide_window(window, hide_workspace):
    window_id = str(field(window, "id"))
    niri_action(
        "move-window-to-workspace",
        "--window-id",
        window_id,
        "--focus",
        "false",
        hide_workspace,
    )


def main():
    parser = argparse.ArgumentParser(
        description="Toggle a Niri drop-down application by dedicated app-id.",
    )
    parser.add_argument(
        "--app-id",
        required=True,
        help="Regular expression matching the drop-down instance app-id.",
    )
    parser.add_argument(
        "--name",
        help="Stable name used for the hidden workspace; defaults to app-id.",
    )
    parser.add_argument(
        "--hide-workspace",
        help="Workspace used to hide the drop-down window.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=5.0,
        help="Seconds to wait for a newly launched window.",
    )
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()

    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        parser.error("missing command to launch after --")

    name = args.name or re.sub(r"[^A-Za-z0-9_.-]+", "-", args.app_id).strip("-")
    hide_workspace = args.hide_workspace or "__ndrop"

    current_workspace = focused_workspace()
    current_ref = workspace_reference(current_workspace)
    windows = all_windows()
    window = load_state_window(name, windows) or choose_window(
        [
            window
            for window in windows
            if app_id(window) and re.search(args.app_id, str(app_id(window)))
        ]
    )

    if not window:
        previous_window_ids = {
            window_id(window) for window in windows if window_id(window) is not None
        }
        subprocess.Popen(command, start_new_session=True)
        window = wait_for_window(args.app_id, previous_window_ids, args.timeout)
        if window:
            save_state_window(name, window)
            show_window(window, current_ref)
        return

    save_state_window(name, window)
    if is_focused(window) or window_workspace_matches(window, current_workspace):
        hide_window(window, hide_workspace)
    else:
        show_window(window, current_ref)


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as error:
        print(f"ndrop: {error}", file=sys.stderr)
        sys.exit(1)
