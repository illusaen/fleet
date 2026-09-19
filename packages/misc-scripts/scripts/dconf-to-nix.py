#!/usr/bin/env python3
from argparse import ArgumentParser
from subprocess import run

"""
dconf-to-nixos
------------
Turn a dconf directory into declarative NixOS settings

Tip: use the dconf-editor application to easily view all directories

Requirements: dconf, python3
Last update: 22 March 2026
Example usage: ./dconf-to-nixos /org/nemo/preferences/
Example output:
{
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/nemo/preferences" = {
          click-policy = "double";
          date-format = "iso";
          show-advanced-permissions = true;
          show-hidden-files = true;
          show-toggle-extra-pane-toolbar = true;
          size-prefixes = "base-10";
          tooltips-in-icon-view = false;
          tooltips-in-list-view = false;
        };

        "org/nemo/preferences/menu-config" = {
          selection-menu-open-as-root = false;
          selection-menu-open-in-new-tab = false;
          selection-menu-pin = false;
        };
      };
    }
  ];
}
"""

template = """
{
  programs.dconf.profiles.user.databases = [
    {
      settings = {
DCONF_SETTINGS
      };
    }
  ];
}"""


def _run(command):
    return run(
        command, encoding="UTF-8", capture_output=True, shell=True, check=True
    ).stdout


def dconf_read_recursive(dconf_dir, output_entries=None):
    """
    Output entries is:
    {
      dconf_dir = {
        key = val
      }
    }
    """
    dir_entries = _run("dconf list " + dconf_dir).split("\n")

    for key in dir_entries:
        if key == "":
            continue
        if key.endswith("/"):
            output_entries = dconf_read_recursive(dconf_dir + key, output_entries)
        else:
            value = _run("dconf read " + dconf_dir + key).removesuffix("\n")
            if dconf_dir not in output_entries:
                output_entries[dconf_dir] = {}
            output_entries[dconf_dir][key] = value
    return output_entries


def dconf_read_output_to_nix(dconf_settings):
    settings = ""
    first_entry = True
    for dconf_dir in dconf_settings:
        if first_entry:
            first_entry = False
        else:
            settings += "\n\n"
        dconf_dir_settings = dconf_settings[dconf_dir]
        stripped_dconf_dir = dconf_dir.removeprefix("/").removesuffix("/")
        settings += f'        "{stripped_dconf_dir}" = {{\n'
        for key in dconf_dir_settings:
            value = dconf_dir_settings[key]
            if value not in ["true", "false"]:
                value = value.replace("'", '"')

            settings += f"          {key} = {value};\n"

        settings += "        };"
    settings = template.replace("DCONF_SETTINGS", settings)
    return settings


if __name__ == "__main__":
    parser = ArgumentParser(
        prog="dconf-to-nixos",
        description="Turn a dconf directory into declarative NixOS settings",
        usage="./dconf-to-nixos /org/nemo/preferences/",
    )
    parser.add_argument("DCONF_DIR", help="Example: /org/nemo/preferences/")
    args = parser.parse_args()

    dconf_settings = dconf_read_recursive(args.DCONF_DIR)
    out = dconf_read_output_to_nix(dconf_settings)
    print(out)
