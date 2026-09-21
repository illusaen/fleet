"""Build and optionally link the runtime theme managed by this repository."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import secrets
import shutil
import sys
import tempfile
from collections.abc import Mapping
from contextlib import suppress
from dataclasses import dataclass
from pathlib import Path
from string import Template
from typing import Any, Literal

import pystache
import tomllib
import yaml

MANIFEST_VERSION = 1
ITEM_TYPES = {"file", "directory"}
MANIFEST_FIELDS = {"version", "clobber", "items"}
ITEM_FIELDS = {"source", "destination", "type", "template", "themed"}
COLOR_LABELS = tuple(
    [f"{index:02d}" for index in range(10)]
    + [f"0{letter}" for letter in "ABCDEF"]
    + [str(index) for index in range(10, 18)]
)
HEX_COLOR = re.compile(r"#[0-9a-fA-F]{6}")

ItemType = Literal["file", "directory"]
LinkStatus = Literal["created", "unchanged", "replaced", "skipped"]


class ThemeError(RuntimeError):
    """A user-facing theme application failure."""


@dataclass(frozen=True)
class ManifestItem:
    source: str
    destination: str
    item_type: ItemType
    template: str | None = None
    themed: bool = False

    @property
    def template_source(self) -> str | None:
        return None if self.template is None else f"{self.template}.mustache"


@dataclass(frozen=True)
class Manifest:
    clobber: bool
    items: tuple[ManifestItem, ...]


@dataclass(frozen=True)
class BuildResult:
    path: Path
    build_id: str


@dataclass(frozen=True)
class RenderedFile:
    relative_path: Path
    content: str
    mode: int
    themed: bool
    template_source: str


@dataclass(frozen=True)
class LinkAction:
    destination: Path
    source: Path
    status: LinkStatus


@dataclass(frozen=True)
class RuntimePaths:
    repository: Path

    @property
    def dotfiles(self) -> Path:
        return self.repository / "dotfiles"

    @property
    def built(self) -> Path:
        return self.dotfiles / "built"

    @property
    def manifest(self) -> Path:
        return self.dotfiles / "manifest.toml"

    @property
    def themes(self) -> Path:
        return self.repository / "resources/themes"

    @property
    def selected(self) -> Path:
        return self.built / "selected"


def parse_args(argv: list[str]) -> argparse.Namespace:
    modes = {"build", "link"}
    if not argv or argv[0] not in modes:
        argv = ["link", *argv]
    parser = argparse.ArgumentParser(
        description="Build a theme or build and link its dotfiles into place."
    )
    parser.add_argument("mode", choices=sorted(modes))
    parser.add_argument("theme", help="theme name")
    return parser.parse_args(argv)


def validate_theme_name(theme: str) -> str:
    if not theme or theme in {".", ".."} or Path(theme).name != theme:
        raise ThemeError(f"invalid theme name: {theme!r}")
    return theme


def _require_bool(value: object, field: str) -> bool:
    if not isinstance(value, bool):
        raise ThemeError(f"{field} must be a boolean")
    return value


def _require_string(value: object, field: str) -> str:
    if not isinstance(value, str) or not value:
        raise ThemeError(f"{field} must be a non-empty string")
    return value


def _reject_unknown_fields(
    data: Mapping[str, object], allowed: set[str], label: str
) -> None:
    unknown = sorted(set(data) - allowed)
    if unknown:
        fields = ", ".join(unknown)
        raise ThemeError(f"{label} has unknown field(s): {fields}")


def _parse_manifest_item(raw: object, index: int) -> ManifestItem:
    label = f"manifest item {index}"
    if not isinstance(raw, dict):
        raise ThemeError(f"{label} must be a table")
    if "clobber" in raw:
        raise ThemeError("clobber is only allowed at the manifest level")
    _reject_unknown_fields(raw, ITEM_FIELDS, label)

    destination = _require_string(raw.get("destination"), f"{label} destination")
    template_value = raw.get("template")
    template = (
        None
        if template_value is None
        else _require_string(template_value, f"{label} template")
    )
    if template is not None:
        if template in {".", ".."} or Path(template).name != template:
            raise ThemeError(f"{label} template must be a file name")
        if template.endswith(".mustache"):
            raise ThemeError(f"{label} template must omit the .mustache extension")

    source = _require_string(raw.get("source", template), f"{label} source")
    item_type = raw.get("type", "file")
    if item_type not in ITEM_TYPES:
        raise ThemeError(f"{label} type must be 'file' or 'directory'")
    themed = _require_bool(raw.get("themed", False), f"{label} themed")
    if themed and template is None:
        raise ThemeError(f"{label} cannot be themed without being a template")
    if template is not None and item_type != "file":
        raise ThemeError(f"{label} template type must be 'file'")

    return ManifestItem(source, destination, item_type, template, themed)


def load_manifest(path: Path) -> Manifest:
    try:
        data = tomllib.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, tomllib.TOMLDecodeError) as error:
        raise ThemeError(f"cannot read manifest {path}: {error}") from error
    _reject_unknown_fields(data, MANIFEST_FIELDS, "manifest")

    if type(data.get("version")) is not int or data["version"] != MANIFEST_VERSION:
        raise ThemeError(f"manifest version must be {MANIFEST_VERSION}")
    clobber = _require_bool(data.get("clobber"), "manifest clobber")
    raw_items = data.get("items")
    if not isinstance(raw_items, list) or not raw_items:
        raise ThemeError("manifest items must be a non-empty array")

    items = tuple(
        _parse_manifest_item(raw_item, index)
        for index, raw_item in enumerate(raw_items, start=1)
    )
    destinations: set[str] = set()
    for item in items:
        if item.destination in destinations:
            raise ThemeError(f"duplicate manifest destination: {item.destination}")
        destinations.add(item.destination)
    return Manifest(clobber, items)


def load_context(path: Path | None, theme: str) -> dict[str, Any]:
    if path is None:
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
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
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, yaml.YAMLError) as error:
        raise ThemeError(f"cannot read theme {path}: {error}") from error
    if not isinstance(raw, dict) or not isinstance(raw.get("palette"), dict):
        raise ThemeError(f"theme {path} must contain a palette")

    context: dict[str, Any] = {
        "scheme-system": raw.get("system", "base24"),
        "scheme-name": raw.get("name", path.stem),
        "scheme-author": raw.get("author", ""),
        "scheme-variant": raw.get("variant", "dark"),
    }
    for key, value in context.items():
        if not isinstance(value, str):
            raise ThemeError(f"theme {path} value {key} must be a string")
    palette = raw["palette"]
    for label in COLOR_LABELS:
        key = f"base{label}"
        value = palette.get(key)
        if not isinstance(value, str) or HEX_COLOR.fullmatch(value) is None:
            raise ThemeError(f"theme {path} has invalid hexadecimal color {key}")
        context[key] = value
        context[f"{key}-hex"] = value[1:]
    return context


def _contained_path(root: Path, value: str | Path, field: str) -> Path:
    try:
        normalized_root = root.resolve()
        normalized = (root / value).resolve(strict=False)
    except (OSError, RuntimeError) as error:
        raise ThemeError(f"cannot resolve {field} {value}: {error}") from error
    try:
        normalized.relative_to(normalized_root)
    except ValueError as error:
        raise ThemeError(f"{field} escapes {root}: {value}") from error
    return normalized


def _relative_path(value: str, field: str) -> Path:
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or path == Path("."):
        raise ThemeError(f"{field} must be a relative path: {value}")
    return path


def _render_manifest_templates(
    manifest: Manifest,
    files_dir: Path,
    context: Mapping[str, Any],
) -> tuple[RenderedFile, ...]:
    renderer = pystache.Renderer(missing_tags="strict", escape=lambda value: value)
    rendered: dict[tuple[bool, Path], RenderedFile] = {}

    for item in manifest.items:
        if item.template_source is None:
            continue
        relative = _relative_path(item.source, "template output")
        key = (item.themed, relative)
        existing = rendered.get(key)
        if existing is not None:
            if existing.template_source != item.template_source:
                raise ThemeError(f"conflicting templates for rendered path: {relative}")
            continue

        source = _contained_path(files_dir, item.template_source, "manifest template")
        if not source.is_file():
            raise ThemeError(f"manifest template source does not exist: {source}")
        try:
            content = renderer.render(source.read_text(encoding="utf-8"), context)
            mode = source.stat().st_mode & 0o777
        except (OSError, UnicodeError, pystache.context.KeyNotFoundError) as error:
            raise ThemeError(f"cannot render {source}: {error}") from error
        rendered[key] = RenderedFile(
            relative,
            content,
            mode,
            item.themed,
            item.template_source,
        )
    return tuple(rendered.values())


def _content_build_id(rendered: tuple[RenderedFile, ...]) -> str:
    digest = hashlib.sha256()
    themed = sorted(
        (item for item in rendered if item.themed),
        key=lambda item: item.relative_path.as_posix(),
    )
    for item in themed:
        digest.update(item.relative_path.as_posix().encode())
        digest.update(b"\0")
        digest.update(f"{item.mode:o}".encode())
        digest.update(b"\0")
        digest.update(item.content.encode())
        digest.update(b"\0")
    return digest.hexdigest()[:16]


def _write_rendered(root: Path, item: RenderedFile) -> None:
    destination = _contained_path(root, item.relative_path, "rendered output")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(item.content, encoding="utf-8")
    destination.chmod(item.mode)


def _temporary_sibling(destination: Path) -> Path:
    return destination.with_name(
        f".{destination.name}.next-{os.getpid()}-{secrets.token_hex(6)}"
    )


def _atomic_write(
    destination: Path, content: str, mode: int | None = None
) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = _temporary_sibling(destination)
    try:
        temporary.write_text(content, encoding="utf-8")
        if mode is not None:
            temporary.chmod(mode)
        os.replace(temporary, destination)
    finally:
        with suppress(OSError):
            temporary.unlink()


def _publish_shared(built_dir: Path, rendered: tuple[RenderedFile, ...]) -> None:
    for item in rendered:
        if item.themed:
            continue
        destination = _contained_path(
            built_dir, item.relative_path, "shared rendered output"
        )
        try:
            unchanged = (
                destination.is_file()
                and destination.read_text(encoding="utf-8") == item.content
                and destination.stat().st_mode & 0o777 == item.mode
            )
        except (OSError, UnicodeError):
            unchanged = False
        if not unchanged:
            _atomic_write(destination, item.content, item.mode)


def _publish_themed(
    theme_dir: Path,
    final: Path,
    rendered: tuple[RenderedFile, ...],
) -> None:
    if os.path.lexists(final):
        if final.is_symlink() or not final.is_dir():
            raise ThemeError(f"rendered build path is not a directory: {final}")
        return

    staging = Path(tempfile.mkdtemp(prefix=".staging-", dir=theme_dir))
    try:
        for item in rendered:
            if item.themed:
                _write_rendered(staging, item)
        try:
            staging.rename(final)
        except FileExistsError:
            if final.is_symlink() or not final.is_dir():
                raise ThemeError(f"rendered build path is not a directory: {final}")
    finally:
        if staging.exists():
            shutil.rmtree(staging)


def render_templates(
    manifest: Manifest,
    dotfiles_dir: Path,
    built_dir: Path,
    theme: str,
    context: Mapping[str, Any],
) -> BuildResult:
    theme = validate_theme_name(theme)
    rendered = _render_manifest_templates(manifest, dotfiles_dir / "files", context)
    build_id = _content_build_id(rendered)
    theme_dir = _contained_path(built_dir, theme, "theme build directory")
    final = _contained_path(theme_dir, build_id, "theme build")
    try:
        theme_dir.mkdir(parents=True, exist_ok=True)
        _publish_themed(theme_dir, final, rendered)
        _publish_shared(built_dir, rendered)
    except ThemeError:
        raise
    except OSError as error:
        raise ThemeError(f"cannot publish rendered theme: {error}") from error
    return BuildResult(final, build_id)


def expand_path(value: str, environment: Mapping[str, str]) -> Path:
    try:
        expanded = Template(value).substitute(environment)
    except KeyError as error:
        raise ThemeError(f"path references undefined environment variable {error}") from error
    if expanded == "~" or expanded.startswith("~/"):
        home = environment.get("HOME")
        if home is None:
            raise ThemeError("HOME is not set")
        expanded = home + expanded[1:]
    return Path(expanded)


def resolve_source(
    dotfiles_dir: Path,
    item: ManifestItem,
    theme: str,
    build_id: str,
    environment: Mapping[str, str],
) -> Path:
    if item.template is not None:
        source_root = (
            dotfiles_dir / "built" / theme / build_id
            if item.themed
            else dotfiles_dir / "built"
        )
        return _contained_path(source_root, item.source, "manifest source")

    try:
        formatted = item.source.format(theme=theme, build=build_id)
    except (IndexError, KeyError, ValueError) as error:
        raise ThemeError(f"invalid source template {item.source!r}: {error}") from error
    source_root = dotfiles_dir / "files"
    expanded = expand_path(formatted, environment)
    source = expanded if expanded.is_absolute() else source_root / expanded
    return _contained_path(source_root, source, "manifest source")


def _files_equal(left: Path, right: Path) -> bool:
    if left.stat().st_size != right.stat().st_size:
        return False
    with left.open("rb") as left_file, right.open("rb") as right_file:
        while chunk := left_file.read(128 * 1024):
            if chunk != right_file.read(len(chunk)):
                return False
        return right_file.read(1) == b""


def paths_equal(left: Path, right: Path) -> bool:
    """Compare files or directory trees without relying on an external diff tool."""

    if left.is_symlink() or right.is_symlink():
        return (
            left.is_symlink()
            and right.is_symlink()
            and os.readlink(left) == os.readlink(right)
        )
    if left.is_file() or right.is_file():
        return left.is_file() and right.is_file() and _files_equal(left, right)
    if not left.is_dir() or not right.is_dir():
        return False

    left_entries = {entry.name: entry for entry in left.iterdir()}
    right_entries = {entry.name: entry for entry in right.iterdir()}
    return left_entries.keys() == right_entries.keys() and all(
        paths_equal(left_entries[name], right_entries[name]) for name in left_entries
    )


def sources_match(destination: Path, source: Path) -> bool:
    try:
        current = destination.resolve(strict=False)
        candidate = source.resolve(strict=False)
        if current == candidate:
            return True
        if not current.exists() or not candidate.exists():
            return False
        return paths_equal(current, candidate)
    except (OSError, RuntimeError) as error:
        raise ThemeError(f"cannot compare {destination} with {source}: {error}") from error


def _validate_source(item: ManifestItem, source: Path) -> None:
    if item.item_type == "file" and not source.is_file():
        raise ThemeError(f"manifest file source does not exist: {source}")
    if item.item_type == "directory" and not source.is_dir():
        raise ThemeError(f"manifest directory source does not exist: {source}")


def plan_links(
    manifest: Manifest,
    dotfiles_dir: Path,
    theme: str,
    build_id: str,
    environment: Mapping[str, str],
) -> list[LinkAction]:
    actions: list[LinkAction] = []
    destinations: set[Path] = set()
    for item in manifest.items:
        source = resolve_source(dotfiles_dir, item, theme, build_id, environment)
        _validate_source(item, source)

        destination = expand_path(item.destination, environment)
        if not destination.is_absolute():
            raise ThemeError(f"manifest destination must be absolute: {destination}")
        normalized_destination = Path(os.path.normpath(destination))
        if normalized_destination in destinations:
            raise ThemeError(f"duplicate expanded destination: {destination}")
        destinations.add(normalized_destination)

        if not os.path.lexists(destination):
            status: LinkStatus = "created"
        elif not destination.is_symlink():
            raise ThemeError(f"destination exists and is not a symlink: {destination}")
        elif sources_match(destination, source):
            status = "unchanged"
        elif manifest.clobber:
            status = "replaced"
        else:
            status = "skipped"
        actions.append(LinkAction(destination, source, status))
    return actions


def _install_symlink(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = _temporary_sibling(destination)
    try:
        temporary.symlink_to(source, target_is_directory=source.is_dir())
        os.replace(temporary, destination)
    finally:
        with suppress(OSError):
            temporary.unlink()


def apply_links(actions: list[LinkAction]) -> None:
    completed: list[tuple[LinkAction, str | None]] = []
    try:
        for action in actions:
            if action.status not in {"created", "replaced"}:
                continue
            old_target = (
                os.readlink(action.destination)
                if action.destination.is_symlink()
                else None
            )
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
        _atomic_write(path, f"{theme}\n")
    except OSError as error:
        raise ThemeError(f"cannot record selected theme: {error}") from error


def _runtime_environment() -> dict[str, str]:
    environment = dict(os.environ)
    home = environment.get("HOME")
    if home is None:
        raise ThemeError("HOME is not set")
    environment.setdefault("XDG_CONFIG_HOME", f"{home}/.config")
    return environment


def run(argv: list[str]) -> int:
    args = parse_args(argv)
    theme = validate_theme_name(args.theme)
    environment = _runtime_environment()
    repository = expand_path(
        environment.get("NIX_CONFIG_FOLDER", "$HOME/Projects/fleet"), environment
    ).resolve()
    paths = RuntimePaths(repository)
    manifest = load_manifest(paths.manifest)

    context_path = environment.get("NIX_THEME_CONTEXT")
    context = load_context(
        expand_path(context_path, environment) if context_path else None,
        theme,
    )
    context.update(load_theme(paths.themes / f"{theme}.yaml"))
    build = render_templates(manifest, paths.dotfiles, paths.built, theme, context)

    if args.mode == "build":
        print(f"built     {build.path}")
        return 0

    actions = plan_links(
        manifest,
        paths.dotfiles,
        theme,
        build.build_id,
        environment,
    )
    apply_links(actions)
    write_selected(paths.selected, theme)
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
