#!/usr/bin/env bash
set -euo pipefail

APP_NAME="bitx-attack-check"
APP_DIR="/opt/${APP_NAME}"
INSTALL_PATH="${APP_DIR}/${APP_NAME}"
COMMAND_LINK="/usr/local/sbin/${APP_NAME}"
CONFIG_PATH="${APP_DIR}/${APP_NAME}.conf"
STATE_DIR="${APP_DIR}/data"
SERVICE_PATH="/etc/systemd/system/${APP_NAME}.service"
TIMER_PATH="/etc/systemd/system/${APP_NAME}.timer"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SCRIPT="${SCRIPT_DIR}/${APP_NAME}"
SOURCE_CONFIG="${SCRIPT_DIR}/${APP_NAME}.conf.example"

if [[ ${EUID} -ne 0 ]]; then
    echo "Ruleaza installerul ca root: sudo ./install.sh"
    exit 1
fi

[[ -f "${SOURCE_SCRIPT}" ]] || { echo "Eroare: lipseste ${SOURCE_SCRIPT}"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "Eroare: python3 nu este instalat."; exit 1; }
command -v firewall-cmd >/dev/null 2>&1 || { echo "Eroare: firewall-cmd nu este disponibil."; exit 1; }
[[ -d /var/log/virtualmin ]] || { echo "Eroare: /var/log/virtualmin nu exista."; exit 1; }

echo "Instalez ${APP_NAME} in ${APP_DIR}..."
install -d -o root -g root -m 0755 "${APP_DIR}"
install -d -o root -g root -m 0700 "${STATE_DIR}"
install -o root -g root -m 0755 "${SOURCE_SCRIPT}" "${INSTALL_PATH}"
ln -sfn "${INSTALL_PATH}" "${COMMAND_LINK}"

if [[ ! -e "${CONFIG_PATH}" ]]; then
    if [[ -f /etc/${APP_NAME}.conf ]]; then
        install -o root -g root -m 0600 /etc/${APP_NAME}.conf "${CONFIG_PATH}"
        echo "Migrat config existent: /etc/${APP_NAME}.conf -> ${CONFIG_PATH}"
    elif [[ -f "${SOURCE_CONFIG}" ]]; then
        install -o root -g root -m 0600 "${SOURCE_CONFIG}" "${CONFIG_PATH}"
        echo "Creat config din exemplu: ${CONFIG_PATH}"
    else
        echo "Eroare: nu exista config existent si nici ${SOURCE_CONFIG}"
        exit 1
    fi
else
    echo "Pastrez configuratia existenta: ${CONFIG_PATH}"
fi

# Migreaza state-ul vechi numai daca noul state nu exista deja.
if [[ ! -e "${STATE_DIR}/blocks.json" && -f /var/lib/${APP_NAME}/blocks.json ]]; then
    install -o root -g root -m 0600 /var/lib/${APP_NAME}/blocks.json "${STATE_DIR}/blocks.json"
    echo "Migrat state existent in ${STATE_DIR}/blocks.json"
fi

cat > "${SERVICE_PATH}" <<EOF
[Unit]
Description=BITX Attack Check - Virtualmin auto-block
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${INSTALL_PATH} 15 --block
EOF

cat > "${TIMER_PATH}" <<'EOF'
[Unit]
Description=Run BITX Attack Check every 10 minutes

[Timer]
OnActiveSec=10min
OnUnitActiveSec=10min
AccuracySec=1min
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now "${APP_NAME}.timer"

echo
echo "Verificare dry-run:"
"${INSTALL_PATH}" 15 --dry-run

echo
echo "Instalare terminata."
echo "App    : ${APP_DIR}"
echo "Script : ${INSTALL_PATH}"
echo "Command: ${COMMAND_LINK} -> ${INSTALL_PATH}"
echo "Config : ${CONFIG_PATH}"
echo "State  : ${STATE_DIR}/blocks.json"
echo
systemctl --no-pager status "${APP_NAME}.timer" || true
