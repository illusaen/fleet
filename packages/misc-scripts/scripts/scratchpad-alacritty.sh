#!/usr/bin/env bash

set -euo pipefail

umbriel_command="${UMBRIEL_COMMAND:-umbriel}"

get_window_id() {
  "$umbriel_command" windows --json |
    jq -r 'first(.[] | select(.app_id == "scratchpad-alacritty") | .id) // empty'
}

window_id="$(get_window_id)"
if [[ -z "$window_id" ]]; then
  alacritty --class scratchpad-alacritty &

  for _ in {1..100}; do
    window_id="$(get_window_id)"
    [[ -n "$window_id" ]] && break
    sleep 0.05
  done

  if [[ -z "$window_id" ]]; then
    echo "scratchpad-alacritty: Alacritty window did not appear" >&2
    exit 1
  fi
fi

# The main output is left of the secondary output. This focuses it
# when necessary and is a harmless no-op when it is already focused.
"$umbriel_command" msg output-focus-left 2>/dev/null || true
exec "$umbriel_command" msg scratchpad-toggle:TERMINAL
