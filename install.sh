#!/usr/bin/env bash
set -euo pipefail

APP_NAME="bitx-attack-check"
INSTALL_PATH="/usr/local/sbin/${APP_NAME}"
CONFIG_PATH="/etc/${APP_NAME}.conf"
STATE_DIR="/var/lib/${APP_NAME}"
SERVICE_PATH="/etc/systemd/system/${APP_NAME}.service"
TIMER_PATH="/etc/systemd/system/${APP_NAME}.timer"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SCRIPT="${SCRIPT_DIR}/${APP_NAME}"

if [[ ${EUID} -ne 0 ]]; then
    echo "Ruleaza installerul ca root: sudo ./install.sh"
    exit 1
fi

if [[ ! -f "${SOURCE_SCRIPT}" ]]; then
    echo "Eroare: nu gasesc ${SOURCE_SCRIPT}"
    echo "Ruleaza install.sh din directorul repository-ului."
    exit 1
fi

command -v python3 >/dev/null 2>&1 || {
    echo "Eroare: python3 nu este instalat."
    exit 1
}

command -v firewall-cmd >/dev/null 2>&1 || {
    echo "Eroare: firewall-cmd nu este disponibil."
    echo "Instaleaza/activeaza firewalld inainte de instalare."
    exit 1
}

if [[ ! -d /var/log/virtualmin ]]; then
    echo "Eroare: /var/log/virtualmin nu exista."
    echo "Acest installer este destinat serverelor Virtualmin."
    exit 1
fi

echo "Instalez ${APP_NAME}..."

install -o root -g root -m 0755 "${SOURCE_SCRIPT}" "${INSTALL_PATH}"
install -d -o root -g root -m 0700 "${STATE_DIR}"

if [[ ! -e "${CONFIG_PATH}" ]]; then
    cat > "${CONFIG_PATH}" <<'EOF'
# BITX Attack Check
# Valorile de mai jos corespund valorilor implicite din script.

LOGDIR=/var/log/virtualmin
FIREWALL_ZONE=public

BLOCK_TIME=24h
BLOCK_HOURS=24

# IP-uri separate prin virgula. Adauga aici IP-urile de incredere.
IGNORE_IPS=127.0.0.1,::1

SCAN_LIMIT=5
SCAN_WITH_4XX_LIMIT=2
SCAN_4XX_MIN=20
WP_LIMIT=20
EOF
    chmod 0600 "${CONFIG_PATH}"
    chown root:root "${CONFIG_PATH}"
    echo "Creat: ${CONFIG_PATH}"
else
    echo "Pastrez configuratia existenta: ${CONFIG_PATH}"
fi

cat > "${SERVICE_PATH}" <<EOF
[Unit]
Description=BITX Virtualmin attack check
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${INSTALL_PATH} 15 --block
EOF

cat > "${TIMER_PATH}" <<'EOF'
[Unit]
Description=Run BITX Virtualmin attack check every 10 minutes

[Timer]
OnBootSec=5min
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
echo "Script : ${INSTALL_PATH}"
echo "Config : ${CONFIG_PATH}"
echo "State  : ${STATE_DIR}"
echo
systemctl --no-pager status "${APP_NAME}.timer" || true
