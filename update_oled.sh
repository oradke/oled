#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PYTHON="$SCRIPT_DIR/.venv/bin/python"

if [ ! -x "$PYTHON" ]; then
    printf 'Virtual environment not found at %s; run install.sh first.\n' "$PYTHON" >&2
    exit 1
fi

if ! command -v flock >/dev/null 2>&1; then
    printf 'flock is required to prevent duplicate OLED processes.\n' >&2
    exit 1
fi

exec 9>"${TMPDIR:-/tmp}/oled_status-$(id -u).lock"
flock -n 9 || exit 0
exec "$PYTHON" "$SCRIPT_DIR/oled_status.py"