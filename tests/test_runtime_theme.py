from __future__ import annotations

import importlib.util
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPT = Path(__file__).parents[1] / "features/theming/runtime_theme.py"
SPEC = importlib.util.spec_from_file_location("runtime_theme", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
runtime_theme = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = runtime_theme
SPEC.loader.exec_module(runtime_theme)


class ManifestTests(unittest.TestCase):
    def test_link_is_the_default_mode(self) -> None:
        self.assertEqual(runtime_theme.parse_args(["example"]).mode, "link")
        self.assertEqual(runtime_theme.parse_args(["build", "example"]).mode, "build")

    def test_type_defaults_to_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "manifest.toml"
            path.write_text(
                """\
version = 1
clobber = false

[[items]]
source = "example"
destination = "$HOME/.example"
"""
            )

            manifest = runtime_theme.load_manifest(path)

            self.assertEqual(manifest.items[0].item_type, "file")
            self.assertIsNone(manifest.items[0].template)
            self.assertFalse(manifest.items[0].themed)
            self.assertEqual(manifest.keep, runtime_theme.DEFAULT_BUILDS_TO_KEEP)

    def test_template_is_a_flat_file_name(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "manifest.toml"
            path.write_text(
                """\
version = 1
clobber = false

[[items]]
destination = "$HOME/.example"
template = "nested/example"
"""
            )

            with self.assertRaisesRegex(runtime_theme.ThemeError, "file name"):
                runtime_theme.load_manifest(path)

    def test_template_supplies_source_and_omits_mustache_extension(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "manifest.toml"
            path.write_text(
                """\
version = 1
clobber = false

[[items]]
destination = "$HOME/.example"
template = "example"
"""
            )

            item = runtime_theme.load_manifest(path).items[0]

            self.assertEqual(item.source, "example")
            self.assertEqual(item.template, "example")

    def test_template_rejects_mustache_extension(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "manifest.toml"
            path.write_text(
                """\
version = 1
clobber = false

[[items]]
destination = "$HOME/.example"
template = "example.mustache"
"""
            )

            with self.assertRaisesRegex(runtime_theme.ThemeError, "must omit"):
                runtime_theme.load_manifest(path)

    def test_item_clobber_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "manifest.toml"
            path.write_text(
                """\
version = 1
clobber = false

[[items]]
source = "example"
destination = "$HOME/.example"
clobber = true
"""
            )

            with self.assertRaisesRegex(runtime_theme.ThemeError, "manifest level"):
                runtime_theme.load_manifest(path)

    def test_invalid_type_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "manifest.toml"
            path.write_text(
                """\
version = 1
clobber = false

[[items]]
source = "example"
destination = "$HOME/.example"
type = "tree"
"""
            )

            with self.assertRaisesRegex(runtime_theme.ThemeError, "type"):
                runtime_theme.load_manifest(path)

    def test_unknown_fields_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "manifest.toml"
            path.write_text(
                """\
version = 1
clobber = false

[[items]]
source = "example"
destination = "$HOME/.example"
optional = true
"""
            )

            with self.assertRaisesRegex(runtime_theme.ThemeError, "unknown field"):
                runtime_theme.load_manifest(path)

    def test_boolean_manifest_version_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "manifest.toml"
            path.write_text(
                """\
version = true
clobber = false

[[items]]
source = "example"
destination = "$HOME/.example"
"""
            )

            with self.assertRaisesRegex(runtime_theme.ThemeError, "version"):
                runtime_theme.load_manifest(path)

    def test_manifest_keep_must_be_positive(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "manifest.toml"
            path.write_text(
                """\
version = 1
clobber = false
keep = 0

[[items]]
source = "example"
destination = "$HOME/.example"
"""
            )

            with self.assertRaisesRegex(runtime_theme.ThemeError, "positive integer"):
                runtime_theme.load_manifest(path)

    def test_theme_name_cannot_escape_theme_directories(self) -> None:
        for theme in (
            "",
            ".",
            "..",
            "../example",
            "nested/example",
            "selected",
            "shared",
        ):
            with self.subTest(theme=theme), self.assertRaisesRegex(
                runtime_theme.ThemeError, "invalid theme"
            ):
                runtime_theme.validate_theme_name(theme)

    def test_items_are_partitioned_by_build_strategy(self) -> None:
        plain = runtime_theme.ManifestItem("plain", "/plain", "file")
        shared = runtime_theme.ManifestItem(
            "shared", "/shared", "file", "shared"
        )
        themed = runtime_theme.ManifestItem(
            "themed", "/themed", "file", "themed", True
        )

        partitions = runtime_theme.partition_items((themed, plain, shared))

        self.assertEqual(partitions.plain, (plain,))
        self.assertEqual(partitions.shared, (shared,))
        self.assertEqual(partitions.themed, (themed,))


class RenderTests(unittest.TestCase):
    def test_render_is_content_addressed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            dotfiles = root / "dotfiles"
            files = dotfiles / "files"
            files.mkdir(parents=True)
            (files / "example.conf.mustache").write_text("color={{base00-hex}}\n")
            manifest = runtime_theme.Manifest(
                False,
                (
                    runtime_theme.ManifestItem(
                        "example.conf",
                        "$HOME/.example",
                        "file",
                        "example.conf",
                        True,
                    ),
                ),
            )

            first = runtime_theme.build_templates(
                runtime_theme.partition_items(manifest.items),
                dotfiles,
                dotfiles / "built",
                "example",
                {"base00-hex": "112233"},
            )
            second = runtime_theme.build_templates(
                runtime_theme.partition_items(manifest.items),
                dotfiles,
                dotfiles / "built",
                "example",
                {"base00-hex": "445566"},
            )

            self.assertNotEqual(first.build_id, second.build_id)
            self.assertEqual(
                (first.path / "example.conf").read_text(), "color=112233\n"
            )
            self.assertEqual(
                (second.path / "example.conf").read_text(), "color=445566\n"
            )
            self.assertEqual(first.items[0].source, first.path / "example.conf")

    def test_shared_render_is_content_addressed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            dotfiles = Path(temporary) / "dotfiles"
            template = dotfiles / "files/example.mustache"
            template.parent.mkdir(parents=True)
            template.write_text("value={{value}}")
            items = (
                runtime_theme.ManifestItem(
                    "example", "/example", "file", "example"
                ),
            )
            partitions = runtime_theme.partition_items(items)

            first = runtime_theme.build_templates(
                partitions, dotfiles, dotfiles / "built", "example", {"value": "one"}
            )
            second = runtime_theme.build_templates(
                partitions, dotfiles, dotfiles / "built", "example", {"value": "two"}
            )

            self.assertNotEqual(first.shared_path, second.shared_path)
            self.assertEqual((first.shared_path / "example").read_text(), "value=one")
            self.assertEqual(
                (second.shared_path / "example").read_text(), "value=two"
            )

    def test_render_id_includes_file_mode(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            dotfiles = root / "dotfiles"
            template = dotfiles / "files/example.mustache"
            template.parent.mkdir(parents=True)
            template.write_text("content")
            manifest = runtime_theme.Manifest(
                False,
                (
                    runtime_theme.ManifestItem(
                        "example", "$HOME/.example", "file", "example", True
                    ),
                ),
            )

            template.chmod(0o644)
            first = runtime_theme.build_templates(
                runtime_theme.partition_items(manifest.items),
                dotfiles,
                dotfiles / "built",
                "example",
                {},
            )
            template.chmod(0o755)
            second = runtime_theme.build_templates(
                runtime_theme.partition_items(manifest.items),
                dotfiles,
                dotfiles / "built",
                "example",
                {},
            )

            self.assertNotEqual(first.build_id, second.build_id)
            self.assertEqual((second.path / "example").stat().st_mode & 0o777, 0o755)

    def test_missing_mustache_value_aborts_render(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            dotfiles = root / "dotfiles"
            files = dotfiles / "files"
            files.mkdir(parents=True)
            (files / "example.mustache").write_text("{{missing}}")
            manifest = runtime_theme.Manifest(
                False,
                (
                    runtime_theme.ManifestItem(
                        "example",
                        "$HOME/.example",
                        "file",
                        "example",
                        True,
                    ),
                ),
            )

            with self.assertRaisesRegex(runtime_theme.ThemeError, "cannot render"):
                runtime_theme.build_templates(
                    runtime_theme.partition_items(manifest.items),
                    dotfiles,
                    dotfiles / "built",
                    "example",
                    {},
                )

    def test_only_manifest_templates_are_rendered(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            dotfiles = Path(temporary) / "dotfiles"
            files = dotfiles / "files"
            files.mkdir(parents=True)
            (files / "included.mustache").write_text("included")
            (files / "ignored.mustache").write_text("{{missing}}")
            manifest = runtime_theme.Manifest(
                False,
                (
                    runtime_theme.ManifestItem(
                        "included",
                        "$HOME/.included",
                        "file",
                        "included",
                        False,
                    ),
                ),
            )

            build = runtime_theme.build_templates(
                runtime_theme.partition_items(manifest.items),
                dotfiles,
                dotfiles / "built",
                "example",
                {},
            )

            self.assertEqual((build.shared_path / "included").read_text(), "included")
            self.assertFalse((build.shared_path / "ignored").exists())
            self.assertEqual(build.items[0].source, build.shared_path / "included")

    def test_reused_template_retains_each_link_destination(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            dotfiles = Path(temporary) / "dotfiles"
            files = dotfiles / "files"
            files.mkdir(parents=True)
            (files / "shared.mustache").write_text("content")
            items = (
                runtime_theme.ManifestItem("shared", "/first", "file", "shared"),
                runtime_theme.ManifestItem("shared", "/second", "file", "shared"),
            )

            build = runtime_theme.build_templates(
                runtime_theme.partition_items(items),
                dotfiles,
                dotfiles / "built",
                "example",
                {},
            )

            self.assertEqual(
                tuple(item.destination for item in build.items),
                ("/first", "/second"),
            )
            self.assertEqual(build.items[0].source, build.items[1].source)


class LinkTests(unittest.TestCase):
    def test_unchanged_links_are_filtered_out(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            destination = root / "destination"
            source.write_text("content")
            destination.symlink_to(source)

            changes = runtime_theme.changed_links(
                (runtime_theme.BuiltItem(source, str(destination)),),
                True,
                {"HOME": str(root)},
            )

            self.assertEqual(changes, ())

    def test_source_comparison_detects_unchanged_and_changed_files(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            old = root / "old"
            new = root / "new"
            destination = root / "destination"
            old.write_text("same\n")
            new.write_text("same\n")
            destination.symlink_to(old)

            self.assertTrue(runtime_theme.sources_match(destination, new))
            new.write_text("changed\n")
            self.assertFalse(runtime_theme.sources_match(destination, new))

    def test_source_comparison_shortcuts_identical_targets(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "source"
            destination = Path(temporary) / "destination"
            source.write_text("content")
            destination.symlink_to(source)

            with mock.patch.object(
                runtime_theme,
                "paths_equal",
                side_effect=AssertionError("content comparison should be skipped"),
            ):
                self.assertTrue(runtime_theme.sources_match(destination, source))

    def test_path_comparison_handles_directory_trees(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            left = root / "left"
            right = root / "right"
            (left / "nested").mkdir(parents=True)
            (right / "nested").mkdir(parents=True)
            (left / "nested/file").write_text("same")
            (right / "nested/file").write_text("same")

            self.assertTrue(runtime_theme.paths_equal(left, right))
            (right / "nested/file").write_text("changed")
            self.assertFalse(runtime_theme.paths_equal(left, right))

    def test_changed_link_honors_manifest_clobber(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            dotfiles = root / "dotfiles"
            source = dotfiles / "files/new"
            source.parent.mkdir(parents=True)
            source.write_text("new")
            old = dotfiles / "files/old"
            old.write_text("old")
            destination = root / "home/config"
            destination.parent.mkdir()
            destination.symlink_to(old)
            environment = {
                "HOME": str(root / "home"),
                "XDG_CONFIG_HOME": str(root / "home"),
            }

            items = (
                runtime_theme.BuiltItem(source, "$XDG_CONFIG_HOME/config"),
            )

            with mock.patch.object(runtime_theme, "sources_match", return_value=False):
                skipped = runtime_theme.changed_links(items, False, environment)
                replaced = runtime_theme.changed_links(items, True, environment)

            self.assertEqual(replaced[0].status, "replaced")
            self.assertEqual(skipped[0].status, "skipped")

    def test_non_symlink_destination_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            dotfiles = root / "dotfiles"
            source = dotfiles / "files/source"
            source.parent.mkdir(parents=True)
            source.write_text("source")
            destination = root / "destination"
            destination.write_text("owned by user")
            items = (
                runtime_theme.BuiltItem(source, str(destination)),
            )

            with self.assertRaisesRegex(runtime_theme.ThemeError, "not a symlink"):
                runtime_theme.changed_links(items, True, {"HOME": str(root)})

    def test_destinations_are_checked_after_environment_expansion(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            dotfiles = root / "dotfiles"
            files = dotfiles / "files"
            files.mkdir(parents=True)
            (files / "first").write_text("first")
            (files / "second").write_text("second")
            destination = root / "home/config"
            items = (
                runtime_theme.BuiltItem(files / "first", "$HOME/config"),
                runtime_theme.BuiltItem(files / "second", str(destination)),
            )

            with self.assertRaisesRegex(runtime_theme.ThemeError, "expanded destination"):
                runtime_theme.changed_links(
                    items, False, {"HOME": str(root / "home")}
                )

    def test_source_cannot_escape_files_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            dotfiles = root / "dotfiles"
            (dotfiles / "files").mkdir(parents=True)
            (dotfiles / "outside").write_text("outside")
            item = runtime_theme.ManifestItem(
                "../outside", "$HOME/config", "file"
            )

            with self.assertRaisesRegex(runtime_theme.ThemeError, "escapes"):
                runtime_theme.resolve_source(
                    dotfiles,
                    item,
                    "theme",
                    "build",
                    {"HOME": str(root / "home")},
                )


class BuildRetentionTests(unittest.TestCase):
    def test_builds_over_keep_limit_are_deleted_oldest_first(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            builds = tuple(root / (str(index) * 16) for index in range(3))
            for timestamp, build in enumerate(builds, start=1):
                build.mkdir()
                os.utime(build, (timestamp, timestamp))

            runtime_theme.prune_builds(root, 2)

            self.assertFalse(builds[0].exists())
            self.assertTrue(builds[1].exists())
            self.assertTrue(builds[2].exists())

    def test_referenced_build_counts_toward_keep_limit(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            builds = tuple(root / (str(index) * 16) for index in range(3))
            for timestamp, build in enumerate(builds, start=1):
                build.mkdir()
                os.utime(build, (timestamp, timestamp))

            runtime_theme.prune_builds(root, 2, frozenset({builds[0]}))

            self.assertTrue(builds[0].exists())
            self.assertFalse(builds[1].exists())
            self.assertTrue(builds[2].exists())


class IntegrationTests(unittest.TestCase):
    def test_run_renders_and_links_repository_dotfiles(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repository = root / "fleet"
            dotfiles = repository / "dotfiles"
            (dotfiles / "files").mkdir(parents=True)
            (repository / "resources/themes").mkdir(parents=True)
            (dotfiles / "files/example.mustache").write_text(
                "name={{scheme-name}} color={{base00-hex}}\n"
            )
            (dotfiles / "manifest.toml").write_text(
                """\
version = 1
clobber = true

[[items]]
destination = "$XDG_CONFIG_HOME/example"
template = "example"
themed = true
"""
            )
            labels = [f"{index:02d}" for index in range(10)]
            labels.extend(f"0{letter}" for letter in "ABCDEF")
            labels.extend(str(index) for index in range(10, 18))
            palette = "\n".join(
                f'  base{label}: "#{index:06x}"'
                for index, label in enumerate(labels)
            )
            (repository / "resources/themes/example.yaml").write_text(
                f'system: "base24"\nname: "Example"\nauthor: "Test"\nvariant: "dark"\npalette:\n{palette}\n'
            )
            context = root / "context.json"
            context.write_text(
                json.dumps({"static": {}, "themes": {"example": {}}})
            )
            home = root / "home"
            environment = {
                "HOME": str(home),
                "XDG_CONFIG_HOME": str(home / ".config"),
                "PROJECTS_FOLDER": str(root),
                "NIX_CONFIG_FOLDER": "$PROJECTS_FOLDER/fleet",
                "NIX_THEME_CONTEXT": str(context),
            }

            with mock.patch.dict(os.environ, environment, clear=True):
                build_result = runtime_theme.run(["build", "example"])

            destination = home / ".config/example"
            self.assertEqual(build_result, 0)
            self.assertFalse(destination.exists())
            self.assertFalse((dotfiles / "built/selected").exists())

            with mock.patch.dict(os.environ, environment, clear=True):
                result = runtime_theme.run(["example"])

            self.assertEqual(result, 0)
            self.assertTrue(destination.is_symlink())
            self.assertEqual(
                destination.read_text(), "name=Example color=000000\n"
            )
            self.assertEqual(
                (dotfiles / "built/selected").read_text(),
                "example\n",
            )


if __name__ == "__main__":
    unittest.main()
