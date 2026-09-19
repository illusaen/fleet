#!/usr/bin/env python3
"""Render the mutable Noctalia dev config from the repo template."""

import argparse
import os
import subprocess
import sys
from pathlib import Path

DEFAULTS = {
    "mono": "Monaspace Neon NF",
    "sans": "Inter",
    "main": "DP-2",
    "secondary": "HDMI-A-2",
    "image": "resources/wallpapers/dark-silk.jpeg",
    "imageDirectory": "resources/wallpapers",
    "location": "Chicago",
}


def repo_root() -> Path:
    configured = os.environ.get("NIX_CONFIG_REPO")
    if configured:
        return Path(configured).expanduser().resolve()

    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=True,
    )
    if result.returncode == 0:
        return Path(result.stdout.strip()).resolve()

    raise SystemExit(
        "Could not find repo root. Run from the nix repo or set NIX_CONFIG_REPO."
    )


def value(name: str, root: Path) -> str:
    env_name = f"NOCTALIA_{name.upper()}"
    raw = os.environ.get(env_name, DEFAULTS[name])
    if name in {"image", "imageDirectory"}:
        path = Path(raw).expanduser()
        if not path.is_absolute():
            path = root / path
        return str(path)
    return raw


def render(root: Path, output: Path) -> None:
    template = root / "resources/templates/noctalia/noctalia-config.toml.template"
    replacements = {f"@{name}@": value(name, root) for name in DEFAULTS}
    text = template.read_text()
    for needle, replacement in replacements.items():
        text = text.replace(needle, replacement)

    config_dir = output / "noctalia"
    config_dir.mkdir(parents=True, exist_ok=True)
    (config_dir / "config.toml").write_text(text)


def restart_service() -> None:
    subprocess.run(["systemctl", "--user", "restart", "noctalia.service"], check=False)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        default=os.environ.get(
            "NOCTALIA_DEV_CONFIG_DIR",
            str(Path.home() / ".config/noctalia-dev"),
        ),
    )
    parser.add_argument("--restart", action="store_true")
    args = parser.parse_args()

    output = Path(args.output).expanduser().resolve()
    render(repo_root(), output)
    print(output / "noctalia" / "config.toml")

    if args.restart:
        restart_service()

    return 0


if __name__ == "__main__":
    sys.exit(main())
