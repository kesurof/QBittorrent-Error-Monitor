#!/bin/bash

# Script de déploiement Docker pour QBittorrent Error Monitor v2.0
# Usage: ./docker-deploy.sh [build|start|stop|restart|logs|status]

set -euo pipefail
IFS=$'\n\t'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly IMAGE_NAME="qbittorrent-error-monitor"
readonly CONTAINER_NAME="qbittorrent-error-monitor"
readonly COMPOSE_FILE="docker-compose.yml"

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
║           QBittorrent Monitor - Déploiement Docker              ║
║                    Version 2.0 - Production                     ║
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
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose n'est pas installé"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker n'est pas démarré ou vous n'avez pas les permissions"
        exit 1
    fi
    
    log_info "Prérequis validés"
}

setup_directories() {
    log_step "Création des répertoires nécessaires"
    
    mkdir -p logs config
    
    # Copie de la configuration par défaut si elle n'existe pas
    if [[ ! -f "config/config.yaml" ]] && [[ -f "config/config.yaml.example" ]]; then
        cp config/config.yaml.example config/config.yaml
        log_info "Configuration par défaut copiée"
    fi
    
    # Permissions correctes
    chmod 755 logs config
    
    log_info "Répertoires préparés"
}

build_image() {
    log_step "Construction de l'image Docker"
    
    if docker build -t "$IMAGE_NAME:latest" -t "$IMAGE_NAME:2.0" .; then
        log_info "Image construite avec succès"
    else
        log_error "Échec de la construction de l'image"
        exit 1
    fi
}

start_container() {
    log_step "Démarrage du conteneur"
    
    if docker-compose -f "$COMPOSE_FILE" up -d; then
        log_info "Conteneur démarré avec succès"
        
        # Attendre que le conteneur soit prêt
        log_step "Attente du démarrage complet..."
        sleep 10
        
        # Vérification du statut
        if docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
            log_info "Conteneur opérationnel"
            show_status
        else
            log_error "Problème de démarrage"
            docker-compose -f "$COMPOSE_FILE" logs --tail=20
        fi
    else
        log_error "Échec du démarrage"
        exit 1
    fi
}

stop_container() {
    log_step "Arrêt du conteneur"
    
    if docker-compose -f "$COMPOSE_FILE" down; then
        log_info "Conteneur arrêté"
    else
        log_warn "Problème lors de l'arrêt"
    fi
}

restart_container() {
    log_step "Redémarrage du conteneur"
    
    stop_container
    sleep 2
    start_container
}

show_logs() {
    log_step "Affichage des logs"
    echo ""
    echo "=== Logs du conteneur ==="
    docker-compose -f "$COMPOSE_FILE" logs --tail=50 -f
}

show_status() {
    log_step "Statut du conteneur"
    echo ""
    echo "=== Statut Docker Compose ==="
    docker-compose -f "$COMPOSE_FILE" ps
    
    echo ""
    echo "=== Health Check ==="
    if docker exec "$CONTAINER_NAME" python3 /app/qbittorrent-monitor.py --health-check 2>/dev/null; then
        log_info "Health check: OK"
    else
        log_warn "Health check: ÉCHEC"
    fi
    
    echo ""
    echo "=== Statistiques ==="
    docker stats "$CONTAINER_NAME" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null || log_warn "Conteneur non trouvé"
    
    echo ""
    echo "=== Derniers logs applicatifs ==="
    docker exec "$CONTAINER_NAME" tail -5 /app/logs/qbittorrent-error-monitor.log 2>/dev/null || log_warn "Logs non disponibles"
}

run_test() {
    log_step "Test du conteneur"
    
    if docker exec "$CONTAINER_NAME" python3 /app/qbittorrent-monitor.py --test --dry-run --verbose; then
        log_info "Test réussi"
    else
        log_error "Test échoué"
        return 1
    fi
}

interactive_setup() {
    log_step "Configuration interactive"
    
    echo "Détection de votre configuration..."
    
    # Détection du réseau Docker
    local networks
    networks=$(docker network ls --format "{{.Name}}" | grep -v "bridge\|host\|none")
    
    if [[ -n "$networks" ]]; then
        echo "Réseaux Docker détectés:"
        echo "$networks"
        echo ""
        read -rp "Quel réseau utiliser ? (défaut: traefik_proxy): " network_choice
        network_choice=${network_choice:-traefik_proxy}
    else
        network_choice="bridge"
        log_warn "Aucun réseau personnalisé détecté, utilisation de 'bridge'"
    fi
    
    # Détection des conteneurs Sonarr/Radarr
    local containers
    containers=$(docker ps --format "{{.Names}}" | grep -E "(sonarr|radarr)" || true)
    
    if [[ -n "$containers" ]]; then
        log_info "Conteneurs détectés: $containers"
    else
        log_warn "Aucun conteneur Sonarr/Radarr détecté"
    fi
    
    # Modification du docker-compose.yml avec les valeurs détectées
    if [[ "$network_choice" != "traefik_proxy" ]]; then
        sed -i.backup "s/traefik_proxy/$network_choice/g" docker-compose.yml
        log_info "Réseau mis à jour: $network_choice"
    fi
    
    echo ""
    read -rp "Chemin vers vos configurations Sonarr/Radarr (défaut: /home/$(whoami)/.config): " config_path
    config_path=${config_path:-"/home/$(whoami)/.config"}
    
    if [[ "$config_path" != "/home/kesurof/.config" ]]; then
        sed -i.backup "s|/home/kesurof/.config|$config_path|g" docker-compose.yml
        log_info "Chemin de configuration mis à jour: $config_path"
    fi
}

show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  setup     Configuration interactive et build"
    echo "  build     Construire l'image Docker"
    echo "  start     Démarrer le conteneur"
    echo "  stop      Arrêter le conteneur"
    echo "  restart   Redémarrer le conteneur"
    echo "  logs      Afficher les logs en temps réel"
    echo "  status    Afficher le statut et les métriques"
    echo "  test      Exécuter un test dry-run"
    echo "  shell     Ouvrir un shell dans le conteneur"
    echo "  help      Afficher cette aide"
}

main() {
    cd "$SCRIPT_DIR"
    
    local command="${1:-help}"
    
    case "$command" in
        setup)
            show_banner
            check_requirements
            interactive_setup
            setup_directories
            build_image
            start_container
            log_info "Configuration terminée !"
            ;;
        build)
            show_banner
            check_requirements
            setup_directories
            build_image
            ;;
        start)
            check_requirements
            setup_directories
            start_container
            ;;
        stop)
            stop_container
            ;;
        restart)
            restart_container
            ;;
        logs)
            show_logs
            ;;
        status)
            show_status
            ;;
        test)
            run_test
            ;;
        shell)
            log_info "Ouverture d'un shell dans le conteneur..."
            docker exec -it "$CONTAINER_NAME" /bin/bash
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Commande inconnue: $command"
            show_help
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
