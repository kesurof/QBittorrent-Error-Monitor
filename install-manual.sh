#!/bin/bash

# Script d'installation QBittorrent Monitor (Docker)
# Usage: curl -sSL https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/install-manual.sh | bash

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
║            QBittorrent Monitor - Installation Docker            ║
║                       Image GHCR                                ║
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
    
    # Vérifier docker-compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "docker-compose n'est pas installé"
        exit 1
    fi
    
    # Variables d'environnement par défaut
    if [[ -z "${USERDIR:-}" ]]; then
        export USERDIR="$HOME/docker"
        log_info "Utilisation du répertoire: $USERDIR"
    fi
    
    if [[ -z "${PUID:-}" ]]; then
        export PUID=$(id -u)
    fi
    
    if [[ -z "${PGID:-}" ]]; then
        export PGID=$(id -g)
    fi
    
    if [[ -z "${TZ:-}" ]]; then
        export TZ="Europe/Paris"
    fi
    
    log_info "Configuration: PUID=$PUID, PGID=$PGID, TZ=$TZ"
    log_info "Prérequis validés"
}

download_files() {
    log_step "Téléchargement des fichiers"
    
    # Créer le répertoire de travail
    local work_dir="$USERDIR/qbittorrent-monitor"
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    # Télécharger docker-compose.yml
    log_step "Téléchargement docker-compose.yml"
    curl -sSL -o docker-compose.yml \
        "https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/docker-compose.yml"
    
    # Créer les répertoires de données
    mkdir -p config logs
    
    # Télécharger la configuration par défaut
    log_step "Téléchargement de la configuration"
    curl -sSL -o config/config.yaml \
        "https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/config/config.yaml"
    
    log_info "Fichiers téléchargés dans $work_dir"
}

deploy_service() {
    log_step "Déploiement du service"
    
    # Arrêter le service existant
    if docker ps -a --format "{{.Names}}" | grep -q "qbittorrent-monitor"; then
        log_step "Arrêt du service existant"
        docker-compose down || true
    fi
    
    # Télécharger l'image
    log_step "Téléchargement de l'image depuis GitHub Container Registry"
    docker pull ghcr.io/kesurof/qbittorrent-error-monitor/qbittorrent-monitor:latest
    
    # Démarrer le service
    log_step "Démarrage du service"
    docker-compose up -d
    
    # Vérifier le démarrage
    sleep 10
    if docker ps --format "{{.Names}}" | grep -q "qbittorrent-monitor"; then
        log_info "Service démarré avec succès"
    else
        log_error "Échec du démarrage"
        docker-compose logs
        exit 1
    fi
}

show_results() {
    echo ""
    log_info "🎉 QBittorrent Monitor installé avec succès !"
    echo ""
    echo "📊 Commandes utiles :"
    echo "   cd $USERDIR/qbittorrent-monitor"
    echo "   docker-compose logs -f qbittorrent-monitor"
    echo "   docker-compose restart qbittorrent-monitor"
    echo "   docker exec qbittorrent-monitor python3 /app/qbittorrent-monitor.py --health-check"
    echo ""
    echo "📁 Fichiers :"
    echo "   Config: $USERDIR/qbittorrent-monitor/config/config.yaml"
    echo "   Logs: $USERDIR/qbittorrent-monitor/logs/"
    echo "   Compose: $USERDIR/qbittorrent-monitor/docker-compose.yml"
    echo ""
    echo "🌐 Health check: http://localhost:8080/health"
    echo ""
}

main() {
    show_banner
    
    check_requirements
    download_files
    deploy_service
    show_results
    
    echo -e "${GREEN}✅ Installation terminée !${NC}"
}

# Gestion d'erreur
trap 'log_error "Erreur durant l'installation" && exit 1' ERR

# Exécuter seulement si appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
