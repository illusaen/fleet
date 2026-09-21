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
    def test_type_defaults_to_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "manifest.toml"
            path.write_text(
                """\
version = 1
clobber = false

[[items]]
source = "plain/example"
destination = "$HOME/.example"
"""
            )

            manifest = runtime_theme.load_manifest(path)

            self.assertEqual(manifest.items[0].item_type, "file")
            self.assertIsNone(manifest.items[0].clobber)

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
source = "plain/example"
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
            templates = root / "templates"
            templates.mkdir()
            (templates / "example.conf.mustache").write_text("color={{base00-hex}}\n")

            first, first_id = runtime_theme.render_templates(
                templates, root / "built", "example", {"base00-hex": "112233"}
            )
            second, second_id = runtime_theme.render_templates(
                templates, root / "built", "example", {"base00-hex": "445566"}
            )

            self.assertNotEqual(first_id, second_id)
            self.assertEqual((first / "example.conf").read_text(), "color=112233\n")
            self.assertEqual((second / "example.conf").read_text(), "color=445566\n")

    def test_missing_mustache_value_aborts_render(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            templates = root / "templates"
            templates.mkdir()
            (templates / "example.mustache").write_text("{{missing}}")

            with self.assertRaisesRegex(runtime_theme.ThemeError, "cannot render"):
                runtime_theme.render_templates(
                    templates, root / "built", "example", {}
                )


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
            source = dotfiles / "plain/new"
            source.parent.mkdir(parents=True)
            source.write_text("new")
            old = dotfiles / "plain/old"
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
                        "plain/new", "$XDG_CONFIG_HOME/config", "file", None
                    ),
                ),
            )
            forced_off = runtime_theme.Manifest(
                True,
                (
                    runtime_theme.ManifestItem(
                        "plain/new", "$XDG_CONFIG_HOME/config", "file", False
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
            source = dotfiles / "plain/source"
            source.parent.mkdir(parents=True)
            source.write_text("source")
            destination = root / "destination"
            destination.write_text("owned by user")
            manifest = runtime_theme.Manifest(
                True,
                (
                    runtime_theme.ManifestItem(
                        "plain/source", str(destination), "file", None
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
            (dotfiles / "templates").mkdir(parents=True)
            (dotfiles / "plain").mkdir()
            (repository / "resources/themes").mkdir(parents=True)
            (dotfiles / "templates/example.mustache").write_text(
                "name={{scheme-name}} color={{base00-hex}}\n"
            )
            (dotfiles / "manifest.toml").write_text(
                """\
version = 1
clobber = true

[[items]]
source = "built/{theme}/{build}/example"
destination = "$XDG_CONFIG_HOME/example"
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
                "NIX_CONFIG_FOLDER": str(repository),
                "NIX_THEME_CONTEXT": str(context),
                "NIX_THEME_SKIP_REFRESH": "1",
            }

            with mock.patch.dict(os.environ, environment, clear=True):
                result = runtime_theme.run(["example"])

            destination = home / ".config/example"
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
