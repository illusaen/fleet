#!/usr/bin/env python3
"""Workspace navigation helpers for niri."""

import argparse
import json
import re
import subprocess
import sys


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


def workspace_id(workspace):
    return field(workspace, "id", "workspace_id", "workspace-id", "workspaceId")


def workspace_name(workspace):
    return field(workspace, "name", "workspace_name", "workspace-name", "workspaceName")


def workspace_index(workspace):
    return field(workspace, "idx", "index")


def workspace_output(workspace):
    return field(workspace, "output", "output_name", "output-name", "outputName")


def is_focused(workspace):
    return bool(field(workspace, "is_focused", "is-focused", "isFocused", "focused"))


def workspace_key(workspace):
    index = workspace_index(workspace)
    if index is not None:
        return (0, int(index))

    identifier = workspace_id(workspace)
    if identifier is not None:
        return (1, int(identifier))

    return (2, str(workspace_name(workspace) or ""))


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


def find_focused(workspaces):
    for workspace in workspaces:
        if is_focused(workspace):
            return workspace
    raise RuntimeError("niri did not report a focused workspace")


def is_skipped(workspace, skip_pattern):
    name = workspace_name(workspace)
    return bool(name and skip_pattern.search(str(name)))


def next_workspace(workspaces, direction, skip_pattern):
    current = find_focused(workspaces)
    current_output = workspace_output(current)
    current_key = workspace_key(current)

    candidates = [
        workspace
        for workspace in workspaces
        if not is_skipped(workspace, skip_pattern)
        and (current_output is None or workspace_output(workspace) == current_output)
    ]

    if direction == "up":
        candidates = [
            workspace
            for workspace in candidates
            if workspace_key(workspace) < current_key
        ]
        if candidates:
            return max(candidates, key=workspace_key)
        return max(
            [
                workspace
                for workspace in workspaces
                if not is_skipped(workspace, skip_pattern)
                and (
                    current_output is None
                    or workspace_output(workspace) == current_output
                )
            ],
            key=workspace_key,
            default=None,
        )

    candidates = [
        workspace for workspace in candidates if workspace_key(workspace) > current_key
    ]
    if candidates:
        return min(candidates, key=workspace_key)
    return min(
        [
            workspace
            for workspace in workspaces
            if not is_skipped(workspace, skip_pattern)
            and (
                current_output is None or workspace_output(workspace) == current_output
            )
        ],
        key=workspace_key,
        default=None,
    )


def main():
    parser = argparse.ArgumentParser(description="niri workspace helpers")
    parser.add_argument(
        "direction",
        choices=["up", "down"],
        help="Direction to focus, skipping matching workspace names.",
    )
    parser.add_argument(
        "--skip",
        default=r"^__ndrop",
        help="Regular expression for workspace names to skip.",
    )
    args = parser.parse_args()

    target = next_workspace(
        niri_json("workspaces"), args.direction, re.compile(args.skip)
    )
    if target is None:
        return

    niri_action("focus-workspace", workspace_reference(target))


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as error:
        print(f"niri-workspace: {error}", file=sys.stderr)
        sys.exit(1)
    except subprocess.CalledProcessError as error:
        print(f"niri-workspace: command failed: {error}", file=sys.stderr)
        sys.exit(error.returncode)
