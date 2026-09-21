"""Build and optionally link the runtime theme managed by this repository."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from string import Template
from typing import Any

import pystache
import tomllib
import yaml


class ThemeError(RuntimeError):
    """A user-facing theme application failure."""


@dataclass(frozen=True)
class ManifestItem:
    source: str
    destination: str
    item_type: str
    clobber: bool | None
    template: str | None = None
    themed: bool = False


@dataclass(frozen=True)
class Manifest:
    clobber: bool
    items: tuple[ManifestItem, ...]


@dataclass(frozen=True)
class LinkAction:
    destination: Path
    source: Path
    status: str


def parse_bool(value: str) -> bool:
    normalized = value.casefold()
    if normalized == "true":
        return True
    if normalized == "false":
        return False
    raise argparse.ArgumentTypeError("clobber must be either 'true' or 'false'")


def parse_args(argv: list[str]) -> argparse.Namespace:
    modes = {"build", "link"}
    if not argv or argv[0] not in modes:
        argv = ["link", *argv]
    parser = argparse.ArgumentParser(
        description="Build a theme or build and link its dotfiles into place."
    )
    parser.add_argument("mode", choices=sorted(modes))
    parser.add_argument("theme", help="theme name")
    parser.add_argument(
        "clobber",
        nargs="?",
        type=parse_bool,
        help="override the manifest's global clobber value (true or false)",
    )
    return parser.parse_args(argv)


def _require_bool(value: object, field: str) -> bool:
    if not isinstance(value, bool):
        raise ThemeError(f"{field} must be a boolean")
    return value


def load_manifest(path: Path) -> Manifest:
    try:
        data = tomllib.loads(path.read_text())
    except (OSError, tomllib.TOMLDecodeError) as error:
        raise ThemeError(f"cannot read manifest {path}: {error}") from error

    if data.get("version") != 1:
        raise ThemeError("manifest version must be 1")
    global_clobber = _require_bool(data.get("clobber"), "manifest clobber")
    raw_items = data.get("items")
    if not isinstance(raw_items, list) or not raw_items:
        raise ThemeError("manifest items must be a non-empty array")

    items: list[ManifestItem] = []
    destinations: set[str] = set()
    for index, raw_item in enumerate(raw_items):
        label = f"manifest item {index + 1}"
        if not isinstance(raw_item, dict):
            raise ThemeError(f"{label} must be a table")
        source = raw_item.get("source")
        destination = raw_item.get("destination")
        if not isinstance(source, str) or not source:
            raise ThemeError(f"{label} source must be a non-empty string")
        if not isinstance(destination, str) or not destination:
            raise ThemeError(f"{label} destination must be a non-empty string")
        if destination in destinations:
            raise ThemeError(f"duplicate manifest destination: {destination}")
        destinations.add(destination)

        item_type = raw_item.get("type", "file")
        if item_type not in {"file", "directory"}:
            raise ThemeError(f"{label} type must be 'file' or 'directory'")
        item_clobber = raw_item.get("clobber")
        if item_clobber is not None:
            item_clobber = _require_bool(item_clobber, f"{label} clobber")
        template = raw_item.get("template")
        if template is not None:
            if not isinstance(template, str) or not template:
                raise ThemeError(f"{label} template must be a non-empty string")
            if Path(template).name != template:
                raise ThemeError(f"{label} template must be a file name")
        themed = _require_bool(raw_item.get("themed", False), f"{label} themed")
        if themed and template is None:
            raise ThemeError(f"{label} cannot be themed without being a template")
        if template is not None and item_type != "file":
            raise ThemeError(f"{label} template type must be 'file'")
        items.append(
            ManifestItem(
                source, destination, item_type, item_clobber, template, themed
            )
        )

    return Manifest(global_clobber, tuple(items))


def effective_clobber(
    item_clobber: bool | None,
    argument_clobber: bool | None,
    global_clobber: bool,
) -> bool:
    if item_clobber is not None:
        return item_clobber
    if argument_clobber is not None:
        return argument_clobber
    return global_clobber


def load_context(path: Path | None, theme: str) -> dict[str, Any]:
    if path is None:
        return {}
    try:
        data = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise ThemeError(f"cannot read runtime context {path}: {error}") from error
    if not isinstance(data, dict):
        raise ThemeError("runtime context must be a JSON object")

    static = data.get("static", {})
    themes = data.get("themes", {})
    if not isinstance(static, dict) or not isinstance(themes, dict):
        raise ThemeError("runtime context static and themes values must be objects")
    selected = themes.get(theme)
    if selected is None:
        raise ThemeError(f"unknown theme: {theme}")
    if not isinstance(selected, dict):
        raise ThemeError(f"runtime context for {theme} must be an object")
    return {**static, **selected}


def load_theme(path: Path) -> dict[str, Any]:
    try:
        raw = yaml.safe_load(path.read_text())
    except (OSError, yaml.YAMLError) as error:
        raise ThemeError(f"cannot read theme {path}: {error}") from error
    if not isinstance(raw, dict) or not isinstance(raw.get("palette"), dict):
        raise ThemeError(f"theme {path} must contain a palette")

    context: dict[str, Any] = {
        "scheme-system": raw.get("system", "base24"),
        "scheme-name": raw.get("name", path.stem),
        "scheme-author": raw.get("author", ""),
        "scheme-variant": raw.get("variant", "dark"),
    }
    palette = raw["palette"]
    color_labels = [f"{index:02d}" for index in range(10)]
    color_labels.extend(f"0{letter}" for letter in "ABCDEF")
    color_labels.extend(str(index) for index in range(10, 18))
    for label in color_labels:
        key = f"base{label}"
        value = palette.get(key)
        if not isinstance(value, str) or not value.startswith("#"):
            raise ThemeError(f"theme {path} is missing hexadecimal color {key}")
        context[key] = value
        context[f"{key}-hex"] = value.removeprefix("#")
    return context


def _contained_path(root: Path, value: str, field: str) -> Path:
    source = root / value
    normalized = source.resolve(strict=False)
    try:
        normalized.relative_to(root.resolve())
    except ValueError as error:
        raise ThemeError(f"{field} escapes {root}: {value}") from error
    return normalized


def render_templates(
    manifest: Manifest,
    dotfiles_dir: Path,
    built_dir: Path,
    theme: str,
    context: dict[str, Any],
) -> tuple[Path, str]:
    theme_dir = built_dir / theme
    theme_dir.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".staging-", dir=theme_dir))
    shared_staging = staging / "shared"
    themed_staging = staging / "themed"
    renderer = pystache.Renderer(missing_tags="strict", escape=lambda value: value)
    digest = hashlib.sha256()
    rendered_destinations: dict[tuple[bool, Path], str] = {}

    try:
        for item in manifest.items:
            if item.template is None:
                continue
            source = _contained_path(
                dotfiles_dir / "files", item.template, "manifest template"
            )
            if not source.is_file():
                raise ThemeError(f"manifest template source does not exist: {source}")

            rendered_relative = Path(item.source)
            if rendered_relative.is_absolute():
                raise ThemeError(f"template output must be relative: {item.source}")
            destination_key = (item.themed, rendered_relative)
            if destination_key in rendered_destinations:
                if rendered_destinations[destination_key] != item.template:
                    raise ThemeError(
                        f"conflicting templates for rendered path: {rendered_relative}"
                    )
                continue
            rendered_destinations[destination_key] = item.template
            destination_root = themed_staging if item.themed else shared_staging
            destination = _contained_path(
                destination_root, item.source, "template output"
            )
            destination.parent.mkdir(parents=True, exist_ok=True)
            try:
                rendered = renderer.render(source.read_text(), context)
                destination.write_text(rendered)
                destination.chmod(source.stat().st_mode & 0o777)
            except (OSError, pystache.context.KeyNotFoundError) as error:
                raise ThemeError(f"cannot render {source}: {error}") from error
            if item.themed:
                digest.update(rendered_relative.as_posix().encode())
                digest.update(b"\0")
                digest.update(rendered.encode())
                digest.update(b"\0")

        build_id = digest.hexdigest()[:16]
        final = theme_dir / build_id
        if final.exists():
            if not final.is_dir():
                raise ThemeError(f"rendered build path is not a directory: {final}")
        elif themed_staging.exists():
            os.replace(themed_staging, final)
        else:
            final.mkdir()

        if shared_staging.exists():
            for source in sorted(shared_staging.rglob("*")):
                if source.is_dir():
                    continue
                relative = source.relative_to(shared_staging)
                destination = built_dir / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                os.replace(source, destination)
        shutil.rmtree(staging)
        return final, build_id
    except Exception:
        if staging.exists():
            shutil.rmtree(staging)
        raise


def expand_path(value: str, environment: dict[str, str]) -> Path:
    try:
        expanded = Template(value).substitute(environment)
    except KeyError as error:
        raise ThemeError(f"path references undefined environment variable {error}") from error
    if expanded == "~" or expanded.startswith("~/"):
        expanded = environment["HOME"] + expanded[1:]
    return Path(expanded)


def resolve_source(
    dotfiles_dir: Path,
    item: ManifestItem,
    theme: str,
    build_id: str,
    environment: dict[str, str],
) -> Path:
    if item.template is not None:
        built_dir = dotfiles_dir / "built"
        source_root = built_dir / theme / build_id if item.themed else built_dir
        return _contained_path(source_root, item.source, "manifest source")

    value = item.source
    try:
        formatted = value.format(theme=theme, build=build_id)
    except (KeyError, ValueError) as error:
        raise ThemeError(f"invalid source template {value!r}: {error}") from error
    source_root = dotfiles_dir / "files"
    source = expand_path(formatted, environment)
    if not source.is_absolute():
        source = source_root / source
    normalized = source.resolve(strict=False)
    try:
        normalized.relative_to(source_root.resolve())
    except ValueError as error:
        raise ThemeError(f"manifest source escapes the files directory: {value}") from error
    return normalized


def compare_with_difft(destination: Path, source: Path) -> bool:
    old_source = destination.resolve(strict=False)
    if not old_source.exists():
        return False
    difft = shutil.which("difft")
    if difft is None:
        raise ThemeError("difft is required but was not found in PATH")
    result = subprocess.run(
        [difft, "--check-only", "--exit-code", str(old_source), str(source)],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        return True
    if result.returncode == 1:
        return False
    detail = result.stderr.strip() or result.stdout.strip() or "unknown error"
    raise ThemeError(f"difft failed for {destination}: {detail}")


def plan_links(
    manifest: Manifest,
    dotfiles_dir: Path,
    theme: str,
    build_id: str,
    argument_clobber: bool | None,
    environment: dict[str, str],
) -> list[LinkAction]:
    actions: list[LinkAction] = []
    for item in manifest.items:
        source = resolve_source(dotfiles_dir, item, theme, build_id, environment)
        if item.item_type == "file" and not source.is_file():
            raise ThemeError(f"manifest file source does not exist: {source}")
        if item.item_type == "directory" and not source.is_dir():
            raise ThemeError(f"manifest directory source does not exist: {source}")

        destination = expand_path(item.destination, environment)
        if not destination.is_absolute():
            raise ThemeError(f"manifest destination must be absolute: {destination}")
        if not os.path.lexists(destination):
            actions.append(LinkAction(destination, source, "created"))
            continue
        if not destination.is_symlink():
            raise ThemeError(f"destination exists and is not a symlink: {destination}")
        if compare_with_difft(destination, source):
            actions.append(LinkAction(destination, source, "unchanged"))
            continue
        if effective_clobber(item.clobber, argument_clobber, manifest.clobber):
            actions.append(LinkAction(destination, source, "replaced"))
        else:
            actions.append(LinkAction(destination, source, "skipped"))
    return actions


def _install_symlink(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.parent / f".{destination.name}.next-{os.getpid()}"
    try:
        temporary.symlink_to(source, target_is_directory=source.is_dir())
        os.replace(temporary, destination)
    finally:
        if os.path.lexists(temporary):
            temporary.unlink()


def apply_links(actions: list[LinkAction]) -> None:
    completed: list[tuple[LinkAction, str | None]] = []
    try:
        for action in actions:
            if action.status in {"unchanged", "skipped"}:
                continue
            old_target = os.readlink(action.destination) if action.destination.is_symlink() else None
            _install_symlink(action.source, action.destination)
            completed.append((action, old_target))
    except OSError as error:
        for action, old_target in reversed(completed):
            try:
                if old_target is None:
                    action.destination.unlink(missing_ok=True)
                else:
                    _install_symlink(Path(old_target), action.destination)
            except OSError:
                pass
        raise ThemeError(f"cannot install theme symlink: {error}") from error


def write_selected(path: Path, theme: str) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_name(f".{path.name}.next-{os.getpid()}")
        temporary.write_text(f"{theme}\n")
        os.replace(temporary, path)
    except OSError as error:
        raise ThemeError(f"cannot record selected theme: {error}") from error


def run(argv: list[str]) -> int:
    args = parse_args(argv)
    environment = dict(os.environ)
    if "HOME" not in environment:
        raise ThemeError("HOME is not set")
    environment.setdefault("XDG_CONFIG_HOME", f"{environment['HOME']}/.config")

    repository = expand_path(
        environment.get("NIX_CONFIG_FOLDER", "$HOME/Projects/fleet"), environment
    ).resolve()
    dotfiles_dir = repository / "dotfiles"
    manifest = load_manifest(dotfiles_dir / "manifest.toml")
    context_path_value = environment.get("NIX_THEME_CONTEXT")
    context = load_context(
        Path(context_path_value) if context_path_value is not None else None,
        args.theme,
    )
    context.update(load_theme(repository / "resources/themes" / f"{args.theme}.yaml"))

    build_path, build_id = render_templates(
        manifest,
        dotfiles_dir,
        dotfiles_dir / "built",
        args.theme,
        context,
    )
    if args.mode == "build":
        print(f"built     {build_path}")
        return 0

    actions = plan_links(
        manifest,
        dotfiles_dir,
        args.theme,
        build_id,
        args.clobber,
        environment,
    )
    apply_links(actions)
    selected = dotfiles_dir / "built/selected"
    write_selected(selected, args.theme)

    for action in actions:
        print(f"{action.status:9} {action.destination} -> {action.source}")
    return 0


def main() -> int:
    try:
        return run(sys.argv[1:])
    except ThemeError as error:
        print(f"theme-apply: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
