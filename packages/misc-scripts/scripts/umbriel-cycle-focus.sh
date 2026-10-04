#!/usr/bin/env bash

set -euo pipefail

umbriel_command="${UMBRIEL_COMMAND:-umbriel}"

if ! windows="$("$umbriel_command" windows --json)"; then
  exec "$umbriel_command" msg output-focus-next
fi

focus_scratchpad() {
  local scratchpad=$1

  "$umbriel_command" msg "scratchpad-focus-next:$scratchpad" >/dev/null 2>&1 || return
  "$umbriel_command" windows --json | jq -e --arg scratchpad "$scratchpad" \
    'any(.[]; .active and (.scratchpad // "") == $scratchpad)' >/dev/null
}

# Prefer the scratchpad that currently owns keyboard focus. This matters when
# different outputs are showing different scratchpads.
active_scratchpad="$(
  jq -r 'first(.[] | select(.active and (.scratchpad // "") != "") | .scratchpad) // empty' <<<"$windows"
)"

if [[ -n "$active_scratchpad" ]] && focus_scratchpad "$active_scratchpad"; then
  exit 0
fi

# The msg IPC reports success even when scratchpad-focus-next does nothing for
# a hidden scratchpad. focus_scratchpad therefore verifies that the requested
# scratchpad became active before treating the action as handled.
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
