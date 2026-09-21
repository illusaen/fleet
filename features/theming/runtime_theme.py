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
from collections import Counter
from collections.abc import Mapping, Sequence
from contextlib import suppress
from dataclasses import dataclass
from itertools import groupby
from pathlib import Path
from string import Template
from typing import Any, Literal

import pystache
import tomllib
import yaml

MANIFEST_VERSION = 1
DEFAULT_BUILDS_TO_KEEP = 3
BUILD_ID_LENGTH = 16
ITEM_TYPES = frozenset({"file", "directory"})
MANIFEST_FIELDS = frozenset({"version", "clobber", "keep", "items"})
ITEM_FIELDS = frozenset({"source", "destination", "type", "template", "themed"})
COLOR_KEYS = tuple(f"base{index:02X}" for index in range(24))
HEX_COLOR = re.compile(r"#[0-9a-fA-F]{6}")
BUILD_ID = re.compile(rf"[0-9a-f]{{{BUILD_ID_LENGTH}}}").fullmatch
RESERVED_THEME_NAMES = frozenset({"selected", "shared"})

ItemType = Literal["file", "directory"]
LinkStatus = Literal["created", "replaced", "skipped"]


class ThemeError(RuntimeError):
    """A user-facing theme application failure."""


@dataclass(frozen=True, slots=True)
class ManifestItem:
    source: str
    destination: str
    item_type: ItemType
    template: str | None = None
    themed: bool = False

    @property
    def template_source(self) -> str | None:
        return None if self.template is None else f"{self.template}.mustache"


@dataclass(frozen=True, slots=True)
class Manifest:
    clobber: bool
    items: tuple[ManifestItem, ...]
    keep: int = DEFAULT_BUILDS_TO_KEEP


@dataclass(frozen=True, slots=True)
class ItemPartitions:
    plain: tuple[ManifestItem, ...]
    shared: tuple[ManifestItem, ...]
    themed: tuple[ManifestItem, ...]


@dataclass(frozen=True, slots=True)
class RenderedFile:
    relative_path: Path
    content: str
    mode: int


@dataclass(frozen=True, slots=True)
class BuiltItem:
    source: Path
    destination: str


@dataclass(frozen=True, slots=True)
class BuildResult:
    path: Path
    shared_path: Path
    build_id: str
    items: tuple[BuiltItem, ...]


@dataclass(frozen=True, slots=True)
class LinkItem:
    source: Path
    destination: Path


@dataclass(frozen=True, slots=True)
class LinkAction:
    destination: Path
    source: Path
    status: LinkStatus


def parse_args(argv: list[str]) -> argparse.Namespace:
    modes = {"build", "link"}
    arguments = argv if argv and argv[0] in modes else ["link", *argv]
    parser = argparse.ArgumentParser(
        description="Build a theme or build and link its dotfiles into place."
    )
    parser.add_argument("mode", choices=sorted(modes))
    parser.add_argument("theme", help="theme name")
    return parser.parse_args(arguments)


def validate_theme_name(theme: str) -> str:
    if (
        not theme
        or theme in {".", ".."}
        or theme in RESERVED_THEME_NAMES
        or Path(theme).name != theme
    ):
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


def _require_positive_int(value: object, field: str) -> int:
    if type(value) is not int or value < 1:
        raise ThemeError(f"{field} must be a positive integer")
    return value


def _reject_unknown_fields(
    data: Mapping[str, object], allowed: frozenset[str], label: str
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


def _first_duplicate(values: Sequence[str | Path]) -> str | Path | None:
    return next((value for value, count in Counter(values).items() if count > 1), None)


def load_manifest(path: Path) -> Manifest:
    try:
        data = tomllib.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, tomllib.TOMLDecodeError) as error:
        raise ThemeError(f"cannot read manifest {path}: {error}") from error
    _reject_unknown_fields(data, MANIFEST_FIELDS, "manifest")

    if type(data.get("version")) is not int or data["version"] != MANIFEST_VERSION:
        raise ThemeError(f"manifest version must be {MANIFEST_VERSION}")
    clobber = _require_bool(data.get("clobber"), "manifest clobber")
    keep = _require_positive_int(
        data.get("keep", DEFAULT_BUILDS_TO_KEEP), "manifest keep"
    )
    raw_items = data.get("items")
    if not isinstance(raw_items, list) or not raw_items:
        raise ThemeError("manifest items must be a non-empty array")

    items = tuple(
        _parse_manifest_item(raw_item, index)
        for index, raw_item in enumerate(raw_items, start=1)
    )
    destinations = tuple(item.destination for item in items)
    if (duplicate := _first_duplicate(destinations)) is not None:
        raise ThemeError(f"duplicate manifest destination: {duplicate}")
    return Manifest(clobber, items, keep)


def partition_items(items: Sequence[ManifestItem]) -> ItemPartitions:
    return ItemPartitions(
        plain=tuple(item for item in items if item.template is None),
        shared=tuple(
            item for item in items if item.template is not None and not item.themed
        ),
        themed=tuple(
            item for item in items if item.template is not None and item.themed
        ),
    )


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


def _theme_color(palette: Mapping[str, object], key: str, path: Path) -> str:
    value = palette.get(key)
    if not isinstance(value, str) or HEX_COLOR.fullmatch(value) is None:
        raise ThemeError(f"theme {path} has invalid hexadecimal color {key}")
    return value


def load_theme(path: Path) -> dict[str, Any]:
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, yaml.YAMLError) as error:
        raise ThemeError(f"cannot read theme {path}: {error}") from error
    if not isinstance(raw, dict) or not isinstance(raw.get("palette"), dict):
        raise ThemeError(f"theme {path} must contain a palette")

    metadata = {
        "scheme-system": raw.get("system", "base24"),
        "scheme-name": raw.get("name", path.stem),
        "scheme-author": raw.get("author", ""),
        "scheme-variant": raw.get("variant", "dark"),
    }
    invalid_metadata = next(
        (key for key, value in metadata.items() if not isinstance(value, str)), None
    )
    if invalid_metadata is not None:
        raise ThemeError(
            f"theme {path} value {invalid_metadata} must be a string"
        )

    palette = raw["palette"]
    colors = {key: _theme_color(palette, key, path) for key in COLOR_KEYS}
    return metadata | colors | {f"{key}-hex": value[1:] for key, value in colors.items()}


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


def _relative_path(value: str) -> Path:
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or path == Path("."):
        raise ThemeError(f"template output must be a relative path: {value}")
    return path


def _template_key(item: ManifestItem) -> Path:
    return _relative_path(item.source)


def _unique_template_items(
    items: Sequence[ManifestItem],
) -> tuple[ManifestItem, ...]:
    sorted_items = sorted(items, key=_template_key)
    groups = tuple(
        (key, tuple(group))
        for key, group in groupby(sorted_items, key=_template_key)
    )
    conflict = next(
        (
            key
            for key, group in groups
            if len({item.template_source for item in group}) > 1
        ),
        None,
    )
    if conflict is not None:
        raise ThemeError(f"conflicting templates for rendered path: {conflict}")
    return tuple(group[0] for _, group in groups)


def _render_template(
    item: ManifestItem,
    files_dir: Path,
    context: Mapping[str, Any],
    renderer: pystache.Renderer,
) -> RenderedFile:
    template_source = item.template_source
    assert template_source is not None
    source = _contained_path(files_dir, template_source, "manifest template")
    if not source.is_file():
        raise ThemeError(f"manifest template source does not exist: {source}")
    try:
        content = renderer.render(source.read_text(encoding="utf-8"), context)
        mode = source.stat().st_mode & 0o777
    except (OSError, UnicodeError, pystache.context.KeyNotFoundError) as error:
        raise ThemeError(f"cannot render {source}: {error}") from error
    return RenderedFile(_template_key(item), content, mode)


def _render_manifest_templates(
    items: Sequence[ManifestItem],
    files_dir: Path,
    context: Mapping[str, Any],
) -> tuple[RenderedFile, ...]:
    renderer = pystache.Renderer(missing_tags="strict", escape=lambda value: value)
    return tuple(
        _render_template(item, files_dir, context, renderer)
        for item in _unique_template_items(items)
    )


def _rendered_bytes(item: RenderedFile) -> bytes:
    return b"\0".join(
        (
            item.relative_path.as_posix().encode(),
            f"{item.mode:o}".encode(),
            item.content.encode(),
        )
    ) + b"\0"


def _content_build_id(rendered: tuple[RenderedFile, ...]) -> str:
    ordered = sorted(rendered, key=lambda item: item.relative_path.as_posix())
    payload = b"".join(_rendered_bytes(item) for item in ordered)
    return hashlib.sha256(payload).hexdigest()[:16]


def _write_rendered(root: Path, item: RenderedFile) -> None:
    destination = _contained_path(root, item.relative_path, "rendered output")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(item.content, encoding="utf-8")
    destination.chmod(item.mode)


def _temporary_sibling(destination: Path) -> Path:
    return destination.with_name(
        f".{destination.name}.next-{os.getpid()}-{secrets.token_hex(6)}"
    )


def _atomic_write(destination: Path, content: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = _temporary_sibling(destination)
    try:
        temporary.write_text(content, encoding="utf-8")
        os.replace(temporary, destination)
    finally:
        with suppress(OSError):
            temporary.unlink()


def _publish_build(
    build_root: Path,
    final: Path,
    rendered: tuple[RenderedFile, ...],
) -> None:
    if os.path.lexists(final):
        if final.is_symlink() or not final.is_dir():
            raise ThemeError(f"rendered build path is not a directory: {final}")
        final.touch()
        return

    staging = Path(tempfile.mkdtemp(prefix=".staging-", dir=build_root))
    try:
        for item in rendered:
            _write_rendered(staging, item)
        try:
            staging.rename(final)
        except FileExistsError:
            if final.is_symlink() or not final.is_dir():
                raise ThemeError(f"rendered build path is not a directory: {final}")
    finally:
        if staging.exists():
            shutil.rmtree(staging)


def _built_items(
    items: Sequence[ManifestItem], root: Path
) -> tuple[BuiltItem, ...]:
    return tuple(
        BuiltItem(
            _contained_path(root, item.source, "built source"),
            item.destination,
        )
        for item in items
    )


def build_templates(
    partitions: ItemPartitions,
    dotfiles_dir: Path,
    built_dir: Path,
    theme: str,
    context: Mapping[str, Any],
) -> BuildResult:
    theme = validate_theme_name(theme)
    files_dir = dotfiles_dir / "files"
    shared = _render_manifest_templates(partitions.shared, files_dir, context)
    themed = _render_manifest_templates(partitions.themed, files_dir, context)
    shared_build_id = _content_build_id(shared)
    build_id = _content_build_id(themed)
    shared_root = _contained_path(built_dir, "shared", "shared build directory")
    theme_root = _contained_path(built_dir, theme, "theme build directory")
    shared_path = _contained_path(shared_root, shared_build_id, "shared build")
    final = _contained_path(theme_root, build_id, "theme build")
    try:
        shared_root.mkdir(parents=True, exist_ok=True)
        theme_root.mkdir(parents=True, exist_ok=True)
        _publish_build(shared_root, shared_path, shared)
        _publish_build(theme_root, final, themed)
    except ThemeError:
        raise
    except OSError as error:
        raise ThemeError(f"cannot publish rendered theme: {error}") from error
    return BuildResult(
        final,
        shared_path,
        build_id,
        (
            *_built_items(partitions.shared, shared_path),
            *_built_items(partitions.themed, final),
        ),
    )


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
        raise ThemeError("templated item reached the plain source stage")

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


def _build_plain_item(
    item: ManifestItem,
    dotfiles_dir: Path,
    theme: str,
    build_id: str,
    environment: Mapping[str, str],
) -> BuiltItem:
    source = resolve_source(dotfiles_dir, item, theme, build_id, environment)
    _validate_source(item, source)
    return BuiltItem(source, item.destination)


def build_plain_items(
    items: Sequence[ManifestItem],
    dotfiles_dir: Path,
    theme: str,
    build_id: str,
    environment: Mapping[str, str],
) -> tuple[BuiltItem, ...]:
    return tuple(
        _build_plain_item(item, dotfiles_dir, theme, build_id, environment)
        for item in items
    )


def _resolve_destination(value: str, environment: Mapping[str, str]) -> Path:
    destination = expand_path(value, environment)
    if not destination.is_absolute():
        raise ThemeError(f"manifest destination must be absolute: {destination}")
    return Path(os.path.normpath(destination))


def _resolve_link(item: BuiltItem, environment: Mapping[str, str]) -> LinkItem:
    return LinkItem(item.source, _resolve_destination(item.destination, environment))


def _changed_link(item: LinkItem, clobber: bool) -> LinkAction | None:
    if not os.path.lexists(item.destination):
        return LinkAction(item.destination, item.source, "created")
    if not item.destination.is_symlink():
        raise ThemeError(
            f"destination exists and is not a symlink: {item.destination}"
        )
    if sources_match(item.destination, item.source):
        return None
    status: LinkStatus = "replaced" if clobber else "skipped"
    return LinkAction(item.destination, item.source, status)


def changed_links(
    items: Sequence[BuiltItem],
    clobber: bool,
    environment: Mapping[str, str],
) -> tuple[LinkAction, ...]:
    links = tuple(_resolve_link(item, environment) for item in items)
    destinations = tuple(item.destination for item in links)
    if (duplicate := _first_duplicate(destinations)) is not None:
        raise ThemeError(f"duplicate expanded destination: {duplicate}")
    return tuple(
        action
        for item in links
        if (action := _changed_link(item, clobber)) is not None
    )


def _referenced_builds(
    root: Path,
    items: Sequence[ManifestItem],
    environment: Mapping[str, str],
) -> frozenset[Path]:
    try:
        normalized_root = root.resolve()
        destinations = tuple(
            _resolve_destination(item.destination, environment) for item in items
        )
        targets = tuple(
            destination.resolve(strict=False)
            for destination in destinations
            if destination.is_symlink()
        )
        relative_targets = (
            target.relative_to(normalized_root)
            for target in targets
            if target.is_relative_to(normalized_root)
        )
        return frozenset(
            normalized_root / relative.parts[0]
            for relative in relative_targets
            if relative.parts and BUILD_ID(relative.parts[0]) is not None
        )
    except (OSError, RuntimeError) as error:
        raise ThemeError(f"cannot inspect builds in {root}: {error}") from error


def prune_builds(
    root: Path,
    keep: int,
    protected: frozenset[Path] = frozenset(),
) -> None:
    keep = _require_positive_int(keep, "build retention")
    if not root.exists():
        return
    try:
        builds = sorted(
            (
                path
                for path in root.iterdir()
                if not path.is_symlink()
                and path.is_dir()
                and BUILD_ID(path.name) is not None
            ),
            key=lambda path: path.stat().st_mtime_ns,
            reverse=True,
        )
        retained = set(builds) & protected
        available = max(keep - len(retained), 0)
        retained.update(
            tuple(path for path in builds if path not in retained)[:available]
        )
        for path in builds:
            if path not in retained:
                shutil.rmtree(path)
    except OSError as error:
        raise ThemeError(f"cannot prune builds in {root}: {error}") from error


def prune_template_builds(
    build: BuildResult,
    manifest: Manifest,
    environment: Mapping[str, str],
) -> None:
    roots = (build.shared_path.parent, build.path.parent)
    for root in roots:
        prune_builds(
            root,
            manifest.keep,
            _referenced_builds(root, manifest.items, environment),
        )


def _install_symlink(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = _temporary_sibling(destination)
    try:
        temporary.symlink_to(source, target_is_directory=source.is_dir())
        os.replace(temporary, destination)
    finally:
        with suppress(OSError):
            temporary.unlink()


def apply_links(actions: Sequence[LinkAction]) -> None:
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
    return {"XDG_CONFIG_HOME": f"{home}/.config", **environment}


def run(argv: list[str]) -> int:
    args = parse_args(argv)
    theme = validate_theme_name(args.theme)
    environment = _runtime_environment()
    repository = expand_path(
        environment.get("NIX_CONFIG_FOLDER", "$HOME/Projects/fleet"), environment
    ).resolve()
    dotfiles_dir = repository / "dotfiles"
    built_dir = dotfiles_dir / "built"
    manifest = load_manifest(dotfiles_dir / "manifest.toml")
    partitions = partition_items(manifest.items)

    context_path = environment.get("NIX_THEME_CONTEXT")
    context = load_context(
        expand_path(context_path, environment) if context_path else None, theme
    ) | load_theme(repository / "resources/themes" / f"{theme}.yaml")
    build = build_templates(partitions, dotfiles_dir, built_dir, theme, context)

    if args.mode == "build":
        prune_template_builds(build, manifest, environment)
        print(f"built     {build.path}")
        return 0

    plain = build_plain_items(
        partitions.plain,
        dotfiles_dir,
        theme,
        build.build_id,
        environment,
    )
    actions = changed_links((*plain, *build.items), manifest.clobber, environment)
    apply_links(actions)
    write_selected(built_dir / "selected", theme)
    prune_template_builds(build, manifest, environment)
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
