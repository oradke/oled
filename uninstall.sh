#!/bin/sh
set -eu

RUNNING_AS_ROOT=$(id -u)
if [ "$RUNNING_AS_ROOT" -eq 0 ]; then
    if [ -z "${SUDO_USER:-}" ] || [ "$SUDO_USER" = root ]; then
        printf 'Run this as the user whose OLED cron entry should be removed.\n' >&2
        exit 1
    fi
    INSTALL_USER=$SUDO_USER
    if ! command -v runuser >/dev/null 2>&1; then
        printf 'runuser is required when uninstall.sh is invoked through sudo.\n' >&2
        exit 1
    fi
else
    INSTALL_USER=$(id -un)
fi

if ! command -v crontab >/dev/null 2>&1; then
    printf 'Required command not found: crontab\n' >&2
    exit 1
fi

BEGIN_MARKER='# BEGIN oled_status managed cron entry'
END_MARKER='# END oled_status managed cron entry'
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

if [ "$RUNNING_AS_ROOT" -eq 0 ]; then
    runuser -u "$INSTALL_USER" -- crontab "$TEMP_CRON"
else
    crontab "$TEMP_CRON"
fi

printf 'Removed the managed OLED cron entry for %s.\n' "$INSTALL_USER"