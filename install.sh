#!/bin/bash

# Script d'installation QBittorrent Monitor (Docker simple)
# Usage: curl -sSL https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/install.sh | bash

set -euo pipefail

# Couleurs
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}✅ $1${NC}"; }
log_step() { echo -e "${BLUE}🔧 $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

show_banner() {
    echo -e "${BLUE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║                QBittorrent Error Monitor                        ║
║                    Installation Docker                          ║
╚══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_requirements() {
    log_step "Vérification des prérequis"
    
    # Vérifier Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker n'est pas démarré"
        exit 1
    fi
    
    log_info "Docker est installé et démarré"
}

setup_directories() {
    log_step "Configuration des répertoires"
    
    # Répertoire de base
    local base_dir="${INSTALL_DIR:-$HOME/qbittorrent-monitor}"
    
    # Créer les répertoires
    mkdir -p "$base_dir"/{config,logs}
    
    # Variables pour le conteneur
    export WORK_DIR="$base_dir"
    export PUID=${PUID:-$(id -u)}
    export PGID=${PGID:-$(id -g)}
    export TZ=${TZ:-"Europe/Paris"}
    
    log_info "Répertoires créés dans: $base_dir"
    log_info "Configuration: PUID=$PUID, PGID=$PGID, TZ=$TZ"
}

download_config() {
    log_step "Téléchargement de la configuration"
    
    # Configuration par défaut
    curl -sSL -o "$WORK_DIR/config/config.yaml" \
        "https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/config/config.yaml" || {
        log_warn "Échec du téléchargement de la configuration, création d'une configuration minimale"
        cat > "$WORK_DIR/config/config.yaml" << EOF
monitor:
  check_interval: 300
  log_level: "INFO"
  dry_run: false

services:
  sonarr:
    enabled: true
    port: 8989
  radarr:
    enabled: true
    port: 7878

error_patterns:
  - "qBittorrent is reporting an error"
  - "qBittorrent has returned an error"
  - "Connection to qBittorrent failed"
EOF
    }
    
    log_info "Configuration téléchargée"
}

deploy_container() {
    log_step "Déploiement du conteneur"
    
    # Arrêter le conteneur existant
    if docker ps -a --format "{{.Names}}" | grep -q "qbittorrent-monitor"; then
        log_step "Arrêt du conteneur existant"
        docker stop qbittorrent-monitor || true
        docker rm qbittorrent-monitor || true
    fi
    
    # Télécharger l'image
    log_step "Téléchargement de l'image"
    docker pull ghcr.io/kesurof/qbittorrent-error-monitor/qbittorrent-monitor:latest
    
    # Démarrer le conteneur
    log_step "Démarrage du conteneur"
    docker run -d \
        --name qbittorrent-monitor \
        --restart unless-stopped \
        -e PUID="$PUID" \
        -e PGID="$PGID" \
        -e TZ="$TZ" \
        -e CHECK_INTERVAL="${CHECK_INTERVAL:-300}" \
        -e LOG_LEVEL="${LOG_LEVEL:-INFO}" \
        -e DRY_RUN="${DRY_RUN:-false}" \
        -v "$WORK_DIR/config:/app/config:rw" \
        -v "$WORK_DIR/logs:/app/logs:rw" \
        -v "/etc/localtime:/etc/localtime:ro" \
        -v "/var/run/docker.sock:/var/run/docker.sock:ro" \
        -v "$WORK_DIR:/configs:ro" \
        -p "${HTTP_PORT:-8080}:8080" \
        --security-opt no-new-privileges:true \
        ghcr.io/kesurof/qbittorrent-error-monitor/qbittorrent-monitor:latest
    
    # Vérifier le démarrage
    sleep 5
    if docker ps --format "{{.Names}}" | grep -q "qbittorrent-monitor"; then
        log_info "Conteneur démarré avec succès"
    else
        log_error "Échec du démarrage"
        docker logs qbittorrent-monitor
        exit 1
    fi
}

show_results() {
    echo ""
    log_info "🎉 QBittorrent Monitor installé avec succès !"
    echo ""
    echo "📊 Commandes utiles :"
    echo "   docker logs -f qbittorrent-monitor"
    echo "   docker restart qbittorrent-monitor"
    echo "   docker exec qbittorrent-monitor python3 /app/qbittorrent-monitor.py --health-check"
    echo ""
    echo "📁 Fichiers :"
    echo "   Config: $WORK_DIR/config/config.yaml"
    echo "   Logs: $WORK_DIR/logs/"
    echo ""
    echo "🌐 Health check: http://localhost:${HTTP_PORT:-8080}/health"
    echo ""
    echo "🛑 Pour arrêter: docker stop qbittorrent-monitor"
    echo "🗑️  Pour supprimer: docker rm qbittorrent-monitor"
    echo ""
}

main() {
    show_banner
    
    check_requirements
    setup_directories
    download_config
    deploy_container
    show_results
    
    echo -e "${GREEN}✅ Installation terminée !${NC}"
}

# Gestion d'erreur
trap 'log_error "Erreur durant l'installation" && exit 1' ERR

# Exécuter seulement si appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
