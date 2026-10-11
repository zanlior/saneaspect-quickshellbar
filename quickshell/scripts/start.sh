#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v quickshell >/dev/null; then
    printf 'Install Quickshell first: sudo pacman -S quickshell\n' >&2
    exit 1
fi
# Follow the monitor's refresh rate; keep an explicit user override if present.
export QSG_RENDER_LOOP="${QSG_RENDER_LOOP:-threaded}"
exec quickshell --no-duplicate -p "$root_dir"
