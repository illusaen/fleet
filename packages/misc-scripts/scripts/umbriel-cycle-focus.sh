#!/usr/bin/env bash

set -euo pipefail

umbriel_command="${UMBRIEL_COMMAND:-umbriel}"

if ! windows="$("$umbriel_command" windows --json)"; then
  exec "$umbriel_command" msg output-focus-next
fi

focus_scratchpad() {
  "$umbriel_command" msg "scratchpad-focus-next:$1" >/dev/null 2>&1
}

# Prefer the scratchpad that currently owns keyboard focus. This matters when
# different outputs are showing different scratchpads.
active_scratchpad="$(
  jq -r 'first(.[] | select(.active and (.scratchpad // "") != "") | .scratchpad) // empty' <<<"$windows"
)"

if [[ -n "$active_scratchpad" ]] && focus_scratchpad "$active_scratchpad"; then
  exit 0
fi

# Umbriel rejects scratchpad-focus-next for hidden scratchpads, so trying each
# populated scratchpad is a reliable visibility check even though the windows
# IPC does not expose visibility directly.
mapfile -t scratchpads < <(
  jq -r '[.[] | .scratchpad // empty | select(. != "")] | unique[]' <<<"$windows"
)

for scratchpad in "${scratchpads[@]}"; do
  [[ "$scratchpad" == "$active_scratchpad" ]] && continue
  if focus_scratchpad "$scratchpad"; then
    exit 0
  fi
done

exec "$umbriel_command" msg output-focus-next
