#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RUNNING_AS_ROOT=$(id -u)

if [ "$RUNNING_AS_ROOT" -eq 0 ]; then
    if [ -z "${SUDO_USER:-}" ] || [ "$SUDO_USER" = root ]; then
        printf 'Run this as the user who should run the OLED script, not directly as root.\n' >&2
        exit 1
    fi
    INSTALL_USER=$SUDO_USER
    if ! command -v runuser >/dev/null 2>&1; then
        printf 'runuser is required when install.sh is invoked through sudo.\n' >&2
        exit 1
    fi
    run_as_target() { runuser -u "$INSTALL_USER" -- "$@"; }
else
    INSTALL_USER=$(id -un)
    run_as_target() { "$@"; }
fi

if ! id "$INSTALL_USER" >/dev/null 2>&1; then
    printf 'User %s does not exist.\n' "$INSTALL_USER" >&2
    exit 1
fi
for command_name in python3 crontab flock getent; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$command_name" >&2
        exit 1
    fi
done
if ! getent group i2c >/dev/null 2>&1; then
    printf 'The i2c group does not exist; enable I2C support before installing.\n' >&2
    exit 1
fi

run_as_target python3 -m venv "$SCRIPT_DIR/.venv"
run_as_target "$SCRIPT_DIR/.venv/bin/python" -m pip install -r "$SCRIPT_DIR/requirements.txt"

if [ "$RUNNING_AS_ROOT" -eq 0 ]; then
    usermod -aG i2c "$INSTALL_USER"
else
    if ! command -v sudo >/dev/null 2>&1; then
        printf 'sudo is required to add %s to the i2c group.\n' "$INSTALL_USER" >&2
        exit 1
    fi
    sudo usermod -aG i2c "$INSTALL_USER"
fi

BEGIN_MARKER='# BEGIN oled_status managed cron entry'
END_MARKER='# END oled_status managed cron entry'
CRON_LINE="*/5 * * * * \"$SCRIPT_DIR/update_oled.sh\" >/dev/null 2>&1"
TEMP_CRON=$(mktemp)
trap 'rm -f "$TEMP_CRON"' 0 HUP INT TERM

if [ "$RUNNING_AS_ROOT" -eq 0 ]; then
    CURRENT_CRON=$(runuser -u "$INSTALL_USER" -- crontab -l 2>/dev/null || true)
else
    CURRENT_CRON=$(crontab -l 2>/dev/null || true)
fi
printf '%s\n' "$CURRENT_CRON" | awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
    $0 == begin { skip = 1; next }
    $0 == end { skip = 0; next }
    !skip { print }
' > "$TEMP_CRON"
{
    cat "$TEMP_CRON"
    printf '\n%s\n%s\n%s\n' "$BEGIN_MARKER" "$CRON_LINE" "$END_MARKER"
} | if [ "$RUNNING_AS_ROOT" -eq 0 ]; then
    runuser -u "$INSTALL_USER" -- crontab -
else
    crontab -
fi

printf 'Installed OLED environment and cron entry for %s. Log out and back in for i2c group access.\n' "$INSTALL_USER"