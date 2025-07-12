#!/bin/bash

# Script de déploiement direct sur serveur ssdv2
# Usage: curl -sSL https://raw.githubusercontent.com/your-repo/QBittorrent-Error-Monitor/main/deploy-server.sh | bash

set -euo pipefail

# Configuration
readonly REPO_URL="https://github.com/your-username/QBittorrent-Error-Monitor.git"
readonly IMAGE_NAME="qbittorrent-error-monitor:latest"
readonly WORK_DIR="/tmp/qbittorrent-monitor-build"

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
║           QBittorrent Monitor - Déploiement Serveur             ║
║                    Build et Installation                        ║
╚══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_requirements() {
    log_step "Vérification des prérequis"
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé"
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        log_error "Git n'est pas installé"
        exit 1
    fi
    
    # Vérifier que Docker fonctionne
    if ! docker info &> /dev/null; then
        log_error "Docker n'est pas démarré ou accessible"
        exit 1
    fi
    
    log_info "Prérequis validés"
}

download_and_build() {
    log_step "Téléchargement et construction"
    
    # Nettoyer le répertoire de travail
    rm -rf "$WORK_DIR"
    
    # Cloner le repository
    log_step "Clonage du repository"
    git clone "$REPO_URL" "$WORK_DIR"
    
    # Aller dans le répertoire
    cd "$WORK_DIR"
    
    # Construire l'image
    log_step "Construction de l'image Docker"
    docker build -t "$IMAGE_NAME" .
    
    log_info "Image construite : $IMAGE_NAME"
}

setup_ssdv2() {
    log_step "Configuration pour ssdv2"
    
    # Vérifier le réseau traefik_proxy
    if ! docker network ls | grep -q "traefik_proxy"; then
        log_warn "Réseau traefik_proxy non trouvé. Votre stack ssdv2 est-elle démarrée ?"
    fi
    
    # Copier le fichier de configuration ssdv2
    local ssdv2_apps_dir="/opt/seedbox/docker/includes/dockerapps/vars"
    if [[ -d "$ssdv2_apps_dir" ]]; then
        log_step "Installation du fichier ssdv2"
        sudo cp "$WORK_DIR/qbittorrent-monitor.yml" "$ssdv2_apps_dir/"
        log_info "Fichier copié dans $ssdv2_apps_dir/qbittorrent-monitor.yml"
    else
        log_warn "Répertoire ssdv2 non trouvé : $ssdv2_apps_dir"
        echo "📋 Copiez manuellement le fichier :"
        echo "   sudo cp $WORK_DIR/qbittorrent-monitor.yml $ssdv2_apps_dir/"
    fi
}

deploy_container() {
    log_step "Déploiement du conteneur"
    
    # Variables ssdv2
    local user="${USER}"
    local storage_path="${SETTINGS_STORAGE:-/opt/seedbox/docker}"
    
    # Arrêter le conteneur existant
    if docker ps -a --format "{{.Names}}" | grep -q "qbittorrent-error-monitor"; then
        log_step "Arrêt du conteneur existant"
        docker stop qbittorrent-error-monitor >/dev/null 2>&1 || true
        docker rm qbittorrent-error-monitor >/dev/null 2>&1 || true
    fi
    
    # Créer les répertoires
    mkdir -p "$storage_path/docker/$user/qbittorrent-monitor/"{config,logs}
    
    # Copier la configuration par défaut
    cp "$WORK_DIR/config/config.yaml" "$storage_path/docker/$user/qbittorrent-monitor/config/"
    
    # Démarrer le nouveau conteneur
    log_step "Lancement du conteneur"
    docker run -d \
        --name qbittorrent-error-monitor \
        --restart unless-stopped \
        --network traefik_proxy \
        --env PUID="${MYUID:-1000}" \
        --env PGID="${MYGID:-1000}" \
        --env TZ=Europe/Paris \
        --env DOCKER_NETWORK=traefik_proxy \
        --volume "$storage_path/docker/$user/qbittorrent-monitor/config:/app/config:rw" \
        --volume "$storage_path/docker/$user/qbittorrent-monitor/logs:/app/logs:rw" \
        --volume "/var/run/docker.sock:/var/run/docker.sock:ro" \
        --volume "$storage_path/docker/$user:/configs:ro" \
        --volume "/etc/localtime:/etc/localtime:ro" \
        --label "com.qbittorrent-monitor.version=2.0" \
        "$IMAGE_NAME"
    
    # Vérifier le démarrage
    sleep 5
    if docker ps --format "{{.Names}}" | grep -q "qbittorrent-error-monitor"; then
        log_info "Conteneur démarré avec succès"
    else
        log_error "Échec du démarrage"
        docker logs qbittorrent-error-monitor
        exit 1
    fi
}

show_results() {
    echo ""
    log_info "🎉 QBittorrent Monitor déployé avec succès !"
    echo ""
    echo "📊 Commandes utiles :"
    echo "   docker logs -f qbittorrent-error-monitor"
    echo "   docker restart qbittorrent-error-monitor"
    echo "   docker exec qbittorrent-error-monitor python3 /app/qbittorrent-monitor.py --health-check"
    echo ""
    echo "📁 Fichiers :"
    echo "   Config: $storage_path/docker/$USER/qbittorrent-monitor/config/config.yaml"
    echo "   Logs: $storage_path/docker/$USER/qbittorrent-monitor/logs/"
    echo ""
}

cleanup() {
    log_step "Nettoyage"
    rm -rf "$WORK_DIR"
}

main() {
    show_banner
    
    check_requirements
    download_and_build
    setup_ssdv2
    deploy_container
    show_results
    cleanup
    
    echo -e "${GREEN}✅ Installation terminée !${NC}"
}

# Gestion d'erreur
trap 'log_error "Erreur durant l'installation" && cleanup && exit 1' ERR

# Exécuter seulement si appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
