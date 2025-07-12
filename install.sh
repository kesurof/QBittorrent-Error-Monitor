#!/bin/bash

set -e

TARGET_USER="TEMPLATE_USER"
TARGET_GROUP="TEMPLATE_USER"
SCRIPT_DIR="/home/${TARGET_USER}/scripts/qbittorrent-monitor"
SERVICE_NAME="qbittorrent-monitor"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

echo "🚀 Installation QBittorrent Monitor pour ${TARGET_USER}"
echo "=================================================="

if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être exécuté avec sudo"
    exit 1
fi

log_info "Création des répertoires pour ${TARGET_USER}"
mkdir -p "${SCRIPT_DIR}"
mkdir -p "/home/${TARGET_USER}/logs"
chown -R "${TARGET_USER}:${TARGET_GROUP}" "${SCRIPT_DIR}"
chown -R "${TARGET_USER}:${TARGET_GROUP}" "/home/${TARGET_USER}/logs"

log_info "Installation du script Python"
if [[ -f "qbittorrent-monitor.py" ]]; then
    cp qbittorrent-monitor.py "${SCRIPT_DIR}/"
    chmod +x "${SCRIPT_DIR}/qbittorrent-monitor.py"
    chown "${TARGET_USER}:${TARGET_GROUP}" "${SCRIPT_DIR}/qbittorrent-monitor.py"
else
    log_error "Fichier qbittorrent-monitor.py non trouvé"
    exit 1
fi

log_info "Installation du service systemd"
cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
# Service de monitoring automatique des erreurs qBittorrent
# Détecte "qBittorrent is reporting an error" et applique automatiquement :
# - Suppression du téléchargement
# - Ajout à la blocklist  
# - Lancement d'une recherche de remplacement
Description=QBittorrent Error Monitor for Sonarr/Radarr
Documentation=https://github.com/kesurof/QBittorrent-Error-Monitor
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=${TARGET_USER}
Group=${TARGET_GROUP}
WorkingDirectory=/home/${TARGET_USER}/scripts/qbittorrent-monitor
ExecStart=/usr/bin/python3 /home/${TARGET_USER}/scripts/qbittorrent-monitor/qbittorrent-monitor.py --interval 300
Restart=always
RestartSec=10

# Timeouts optimisés pour restart rapide
TimeoutStartSec=15
TimeoutStopSec=10
KillSignal=SIGTERM

# Variables d'environnement par défaut
Environment=USER=${TARGET_USER}
Environment=GROUP=${TARGET_GROUP}
Environment=DOCKER_NETWORK=traefik_proxy
Environment=LOG_LEVEL=INFO

# Limites de ressources
MemoryMax=64M
CPUQuota=15%

# Sécurité
PrivateTmp=true
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=false
ReadWritePaths=/home/${TARGET_USER}/logs

[Install]
WantedBy=multi-user.target
EOF

log_info "Activation du service pour ${TARGET_USER}"
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"

if systemctl start "${SERVICE_NAME}"; then
    sleep 3
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        log_info "Service ${SERVICE_NAME} démarré avec succès"
        
        echo ""
        echo "📊 Statut du service:"
        systemctl status "${SERVICE_NAME}" --no-pager -l
        
        echo ""
        echo "📋 Derniers logs:"
        journalctl -u "${SERVICE_NAME}" --no-pager -n 5
        
    else
        log_error "Service démarré mais pas actif"
        journalctl -u "${SERVICE_NAME}" --no-pager -n 10
        exit 1
    fi
else
    log_error "Échec du démarrage du service ${SERVICE_NAME}"
    journalctl -u "${SERVICE_NAME}" --no-pager -n 10
    exit 1
fi

echo ""
echo "🎉 Installation terminée avec succès pour ${TARGET_USER}"
echo ""
echo "📖 Informations utiles:"
echo "   📊 Logs temps réel: tail -f /home/${TARGET_USER}/logs/qbittorrent-error-monitor.log"
echo "   📈 Statistiques: cat /home/${TARGET_USER}/logs/qbittorrent-stats.json"
echo "   🔧 Config service: /etc/systemd/system/${SERVICE_NAME}.service"
echo ""
echo "⚙️  Commandes de gestion:"
echo "   sudo systemctl status ${SERVICE_NAME}"
echo "   sudo systemctl restart ${SERVICE_NAME}"
echo "   sudo systemctl stop ${SERVICE_NAME}"
echo "   sudo journalctl -u ${SERVICE_NAME} -f"
echo ""
echo "🎯 Le service surveille maintenant automatiquement les erreurs qBittorrent"
echo "   et appliquera les corrections dès qu'une erreur sera détectée."
