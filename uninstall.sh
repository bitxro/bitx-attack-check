#!/usr/bin/env bash
set -euo pipefail

APP_NAME="bitx-attack-check"
APP_DIR="/opt/${APP_NAME}"
SERVICE="/etc/systemd/system/${APP_NAME}.service"
TIMER="/etc/systemd/system/${APP_NAME}.timer"

if [[ ${EUID} -ne 0 ]]; then
    echo "Ruleaza ca root: sudo ./uninstall.sh [--purge]"
    exit 1
fi

PURGE=false
[[ "${1:-}" == "--purge" ]] && PURGE=true

systemctl disable --now "${APP_NAME}.timer" 2>/dev/null || true
systemctl stop "${APP_NAME}.service" 2>/dev/null || true

rm -f "${SERVICE}" "${TIMER}"
systemctl daemon-reload
systemctl reset-failed "${APP_NAME}.service" 2>/dev/null || true

if ${PURGE}; then
    rm -rf "${APP_DIR}"
    echo "Eliminat complet: ${APP_DIR}"
else
    rm -f "${APP_DIR}/${APP_NAME}"
    echo "Configul si state-ul au fost pastrate in ${APP_DIR}"
fi

echo "BITX Attack Check dezinstalat."
