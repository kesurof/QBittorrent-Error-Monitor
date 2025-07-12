#!/bin/bash

# Configuration stricte pour la sécurité
set -euo pipefail
IFS=$'\n\t'

# Variables sécurisées
readonly TARGET_USER="TEMPLATE_USER"
readonly TARGET_GROUP="TEMPLATE_USER"
readonly SCRIPT_DIR="/home/${TARGET_USER}/scripts/qbittorrent-monitor"
readonly SERVICE_NAME="qbittorrent-monitor"
readonly SCRIPT_VERSION="2.0"

# Couleurs pour l'affichage
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Fonctions de logging sécurisées
log_info() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_step() { echo -e "${BLUE}🔧 $1${NC}"; }

# Fonction de validation sécurisée
validate_user() {
    local user="$1"
    
    # Vérification que l'utilisateur existe
    if ! id "$user" &>/dev/null; then
        log_error "L'utilisateur '$user' n'existe pas"
        return 1
    fi
    
    # Vérification des caractères autorisés
    if [[ ! "$user" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        log_error "Nom d'utilisateur contient des caractères non autorisés: $user"
        return 1
    fi
    
    return 0
}

# Fonction pour créer des répertoires de manière sécurisée
create_directory_secure() {
    local dir="$1"
    local owner="$2"
    local permissions="${3:-755}"
    
    if [[ -d "$dir" ]]; then
        log_info "Répertoire existant: $dir"
    else
        if ! mkdir -p "$dir"; then
            log_error "Impossible de créer le répertoire: $dir"
            return 1
        fi
        log_info "Répertoire créé: $dir"
    fi
    
    # Application sécurisée des permissions
    if ! chown "$owner:$owner" "$dir"; then
        log_error "Impossible de changer le propriétaire de: $dir"
        return 1
    fi
    
    if ! chmod "$permissions" "$dir"; then
        log_error "Impossible de changer les permissions de: $dir"
        return 1
    fi
    
    return 0
}

# Fonction pour valider et installer un fichier
install_file_secure() {
    local source="$1"
    local destination="$2"
    local owner="$3"
    local permissions="${4:-644}"
    
    if [[ ! -f "$source" ]]; then
        log_error "Fichier source non trouvé: $source"
        return 1
    fi
    
    # Validation basique du fichier Python
    if [[ "$source" == *.py ]]; then
        if ! python3 -m py_compile "$source"; then
            log_error "Erreur de syntaxe Python dans: $source"
            return 1
        fi
    fi
    
    # Copie sécurisée
    if ! cp "$source" "$destination"; then
        log_error "Échec de la copie: $source -> $destination"
        return 1
    fi
    
    # Application des permissions
    if ! chown "$owner:$owner" "$destination"; then
        log_error "Impossible de changer le propriétaire de: $destination"
        return 1
    fi
    
    if ! chmod "$permissions" "$destination"; then
        log_error "Impossible de changer les permissions de: $destination"
        return 1
    fi
    
    log_info "Fichier installé: $destination"
    return 0
}

show_banner() {
    echo -e "${BLUE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║                QBittorrent Monitor Installation                  ║
║                    Version 2.0 - Sécurisée                      ║
╚══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo "🚀 Installation QBittorrent Monitor pour ${TARGET_USER}"
    echo "=================================================="
}

# Vérifications de sécurité initiales
if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être exécuté avec sudo"
    exit 1
fi

# Validation de l'utilisateur cible
if ! validate_user "$TARGET_USER"; then
    exit 1
fi

show_banner

# Création sécurisée des répertoires
log_step "Création des répertoires pour ${TARGET_USER}"
if ! create_directory_secure "${SCRIPT_DIR}" "${TARGET_USER}" "755"; then
    exit 1
fi

if ! create_directory_secure "/home/${TARGET_USER}/logs" "${TARGET_USER}" "755"; then
    exit 1
fi

# Installation sécurisée du script Python
log_step "Installation du script Python"
if ! install_file_secure "qbittorrent-monitor.py" "${SCRIPT_DIR}/qbittorrent-monitor.py" "${TARGET_USER}" "755"; then
    exit 1
fi

# Installation du fichier de configuration s'il existe
if [[ -f "config/config.yaml" ]]; then
    log_step "Installation du fichier de configuration"
    if ! create_directory_secure "${SCRIPT_DIR}/config" "${TARGET_USER}" "755"; then
        exit 1
    fi
    
    if ! install_file_secure "config/config.yaml" "${SCRIPT_DIR}/config/config.yaml" "${TARGET_USER}" "644"; then
        log_warn "Impossible d'installer le fichier de configuration"
    fi
fi

# Installation sécurisée du service systemd
log_step "Installation du service systemd sécurisé"

# Création du fichier de service avec validation
cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
# Service de monitoring automatique des erreurs qBittorrent v2.0
# Fonctionnalités de sécurité intégrées :
# - Validation stricte des entrées
# - Retry automatique avec backoff exponentiel  
# - Modes test et dry-run disponibles
# - Health check intégré
# - Logging rotatif avec métriques
Description=QBittorrent Error Monitor for Sonarr/Radarr (Secured v${SCRIPT_VERSION})
Documentation=https://github.com/kesurof/QBittorrent-Error-Monitor
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=${TARGET_USER}
Group=${TARGET_GROUP}
WorkingDirectory=${SCRIPT_DIR}
ExecStart=/usr/bin/python3 ${SCRIPT_DIR}/qbittorrent-monitor.py --config ${SCRIPT_DIR}/config/config.yaml --interval 300
ExecReload=/bin/kill -HUP \$MAINPID

# Commandes de health check
ExecStartPre=/usr/bin/python3 ${SCRIPT_DIR}/qbittorrent-monitor.py --health-check
ExecStartPost=/usr/bin/sleep 5

# Restart politique avec backoff
Restart=always
RestartSec=10
StartLimitInterval=300
StartLimitBurst=5

# Timeouts optimisés
TimeoutStartSec=30
TimeoutStopSec=15
KillSignal=SIGTERM
KillMode=process

# Variables d'environnement sécurisées
Environment=USER=${TARGET_USER}
Environment=GROUP=${TARGET_GROUP}
Environment=PYTHONUNBUFFERED=1
Environment=DOCKER_NETWORK=traefik_proxy
Environment=LOG_LEVEL=INFO

# Sécurité renforcée
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ProtectSystem=strict
NoNewPrivileges=true
ReadWritePaths=/home/${TARGET_USER}/logs
ReadWritePaths=${SCRIPT_DIR}

# Limites de ressources
MemoryMax=128M
CPUQuota=25%
TasksMax=50

# Réseau
IPAccounting=true

[Install]
WantedBy=multi-user.target
EOF

if [[ ! -f "/etc/systemd/system/${SERVICE_NAME}.service" ]]; then
    log_error "Échec de la création du fichier de service"
    exit 1
fi

log_info "Service systemd créé avec succès"

# Activation et démarrage sécurisés du service
log_step "Activation du service pour ${TARGET_USER}"

# Rechargement des configurations systemd
if ! systemctl daemon-reload; then
    log_error "Échec du rechargement des configurations systemd"
    exit 1
fi

# Activation du service
if ! systemctl enable "${SERVICE_NAME}"; then
    log_error "Échec de l'activation du service"
    exit 1
fi

# Test de validation avant démarrage
log_step "Test de validation avant démarrage"
if su - "${TARGET_USER}" -c "python3 ${SCRIPT_DIR}/qbittorrent-monitor.py --health-check" >/dev/null 2>&1; then
    log_info "Test de validation réussi"
else
    log_warn "Test de validation échoué - le service démarrera quand même"
fi

# Démarrage du service
log_step "Démarrage du service"
if systemctl start "${SERVICE_NAME}"; then
    # Attente que le service se stabilise
    sleep 5
    
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        log_info "Service ${SERVICE_NAME} démarré avec succès"
        
        echo ""
        echo "📊 Statut du service:"
        systemctl status "${SERVICE_NAME}" --no-pager -l || true
        
        echo ""
        echo "📋 Derniers logs:"
        journalctl -u "${SERVICE_NAME}" --no-pager -n 5 || true
        
        # Test de health check post-démarrage
        echo ""
        log_step "Contrôle de santé post-démarrage"
        if su - "${TARGET_USER}" -c "python3 ${SCRIPT_DIR}/qbittorrent-monitor.py --health-check"; then
            log_info "Contrôle de santé réussi"
        else
            log_warn "Contrôle de santé échoué - vérifiez la configuration"
        fi
        
    else
        log_error "Service démarré mais pas actif"
        echo "📋 Logs d'erreur:"
        journalctl -u "${SERVICE_NAME}" --no-pager -n 10 || true
        exit 1
    fi
else
    log_error "Échec du démarrage du service ${SERVICE_NAME}"
    echo "📋 Logs d'erreur:"
    journalctl -u "${SERVICE_NAME}" --no-pager -n 10 || true
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Installation terminée avec succès pour ${TARGET_USER}${NC}"
echo ""
echo "📖 Informations utiles:"
echo "   📊 Logs temps réel: tail -f /home/${TARGET_USER}/logs/qbittorrent-error-monitor.log"
echo "   📈 Statistiques: cat /home/${TARGET_USER}/logs/qbittorrent-stats.json"
echo "   🔧 Config service: /etc/systemd/system/${SERVICE_NAME}.service"
echo "   ⚙️  Config app: ${SCRIPT_DIR}/config/config.yaml"
echo ""
echo "⚙️  Commandes de gestion:"
echo "   sudo systemctl status ${SERVICE_NAME}"
echo "   sudo systemctl restart ${SERVICE_NAME}"
echo "   sudo systemctl stop ${SERVICE_NAME}"
echo "   sudo journalctl -u ${SERVICE_NAME} -f"
echo ""
echo "🧪 Commandes de test:"
echo "   sudo -u ${TARGET_USER} python3 ${SCRIPT_DIR}/qbittorrent-monitor.py --test"
echo "   sudo -u ${TARGET_USER} python3 ${SCRIPT_DIR}/qbittorrent-monitor.py --health-check"
echo "   sudo -u ${TARGET_USER} python3 ${SCRIPT_DIR}/qbittorrent-monitor.py --dry-run"
echo ""
echo "🎯 Le service surveille maintenant automatiquement les erreurs qBittorrent"
echo "   avec des fonctionnalités de sécurité avancées et un retry intelligent."
