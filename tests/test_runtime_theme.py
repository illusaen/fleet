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
            self.assertIsNone(manifest.items[0].clobber)
            self.assertIsNone(manifest.items[0].template)
            self.assertFalse(manifest.items[0].themed)

    def test_template_is_a_flat_file_name(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "manifest.toml"
            path.write_text(
                """\
version = 1
clobber = false

[[items]]
source = "example"
destination = "$HOME/.example"
template = "nested/example.mustache"
"""
            )

            with self.assertRaisesRegex(runtime_theme.ThemeError, "file name"):
                runtime_theme.load_manifest(path)

    def test_clobber_precedence(self) -> None:
        effective = runtime_theme.effective_clobber
        self.assertTrue(effective(True, False, False))
        self.assertFalse(effective(False, True, True))
        self.assertTrue(effective(None, True, False))
        self.assertFalse(effective(None, False, True))
        self.assertTrue(effective(None, None, True))
        self.assertFalse(effective(None, None, False))

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
                        None,
                        "example.conf.mustache",
                        True,
                    ),
                ),
            )

            first, first_id = runtime_theme.render_templates(
                manifest,
                dotfiles,
                dotfiles / "built",
                "example",
                {"base00-hex": "112233"},
            )
            second, second_id = runtime_theme.render_templates(
                manifest,
                dotfiles,
                dotfiles / "built",
                "example",
                {"base00-hex": "445566"},
            )

            self.assertNotEqual(first_id, second_id)
            self.assertEqual((first / "example.conf").read_text(), "color=112233\n")
            self.assertEqual((second / "example.conf").read_text(), "color=445566\n")

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
                        None,
                        "example.mustache",
                        True,
                    ),
                ),
            )

            with self.assertRaisesRegex(runtime_theme.ThemeError, "cannot render"):
                runtime_theme.render_templates(
                    manifest, dotfiles, dotfiles / "built", "example", {}
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
                        None,
                        "included.mustache",
                        False,
                    ),
                ),
            )

            runtime_theme.render_templates(
                manifest, dotfiles, dotfiles / "built", "example", {}
            )

            self.assertEqual((dotfiles / "built/included").read_text(), "included")
            self.assertFalse((dotfiles / "built/ignored").exists())


class LinkTests(unittest.TestCase):
    def test_difft_detects_unchanged_and_changed_files(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            old = root / "old"
            new = root / "new"
            destination = root / "destination"
            old.write_text("same\n")
            new.write_text("same\n")
            destination.symlink_to(old)

            self.assertTrue(runtime_theme.compare_with_difft(destination, new))
            new.write_text("changed\n")
            self.assertFalse(runtime_theme.compare_with_difft(destination, new))

    def test_changed_link_honors_argument_and_item_clobber(self) -> None:
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

            inherited = runtime_theme.Manifest(
                False,
                (
                    runtime_theme.ManifestItem(
                        "new", "$XDG_CONFIG_HOME/config", "file", None
                    ),
                ),
            )
            forced_off = runtime_theme.Manifest(
                True,
                (
                    runtime_theme.ManifestItem(
                        "new", "$XDG_CONFIG_HOME/config", "file", False
                    ),
                ),
            )

            with mock.patch.object(runtime_theme, "compare_with_difft", return_value=False):
                replaced = runtime_theme.plan_links(
                    inherited, dotfiles, "theme", "build", True, environment
                )
                skipped = runtime_theme.plan_links(
                    forced_off, dotfiles, "theme", "build", True, environment
                )

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
            manifest = runtime_theme.Manifest(
                True,
                (
                    runtime_theme.ManifestItem(
                        "source", str(destination), "file", None
                    ),
                ),
            )

            with self.assertRaisesRegex(runtime_theme.ThemeError, "not a symlink"):
                runtime_theme.plan_links(
                    manifest,
                    dotfiles,
                    "theme",
                    "build",
                    None,
                    {"HOME": str(root)},
                )


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
source = "example"
destination = "$XDG_CONFIG_HOME/example"
template = "example.mustache"
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
