#!/bin/bash

set -e

DEFAULT_USER=$(whoami)
USER_INPUT="${1:-$DEFAULT_USER}"
REPO_DIR="$HOME/scripts/qbittorrent-monitor"
GITHUB_RAW_URL="https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}✅ $1${NC}"; }
log_step() { echo -e "${BLUE}🔧 $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

show_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    QBittorrent Error Monitor                     ║"
    echo "║               Installation automatique GitHub                    ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

detect_config_paths() {
    log_step "Détection de la configuration existante"
    
    CONFIG_BASE=""
    POSSIBLE_PATHS=(
        "$HOME/seedbox/docker/$USER_INPUT"
        "$HOME/.config"
        "/opt/seedbox/docker/docker/$USER_INPUT"
        "/opt/docker/$USER_INPUT"
    )
    
    for path in "${POSSIBLE_PATHS[@]}"; do
        if [[ -d "$path/sonarr" ]] || [[ -d "$path/radarr" ]]; then
            CONFIG_BASE="$path"
            log_info "Configuration trouvée: $CONFIG_BASE"
            break
        fi
    done
    
    if [[ -z "$CONFIG_BASE" ]]; then
        log_warn "Configuration non détectée automatiquement"
        read -p "Entrez le chemin vers vos configs Sonarr/Radarr: " CONFIG_BASE
    fi
    
    echo "$CONFIG_BASE"
}

install_dependencies() {
    log_step "Vérification des dépendances Python"
    
    if ! python3 -c "import requests" 2>/dev/null; then
        log_step "Installation de requests"
        pip3 install requests --user
    fi
    
    log_info "Dépendances vérifiées"
}

main() {
    show_banner
    
    echo "📍 Utilisateur cible: $USER_INPUT"
    echo "📂 Répertoire d'installation: $REPO_DIR"
    echo ""
    
    read -p "Confirmez-vous l'installation pour l'utilisateur '$USER_INPUT' ? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Installation annulée par l'utilisateur"
        exit 0
    fi
    
    install_dependencies
    
    log_step "Création du répertoire de travail"
    mkdir -p "$REPO_DIR"
    cd "$REPO_DIR"
    
    log_step "Téléchargement du script principal Python"
    if ! curl -s -L "$GITHUB_RAW_URL/qbittorrent-monitor.py" -o qbittorrent-monitor.py; then
        log_error "Échec du téléchargement du script Python"
        exit 1
    fi
    
    log_step "Téléchargement du script d'installation"
    if ! curl -s -L "$GITHUB_RAW_URL/install.sh" -o install.sh; then
        log_error "Échec du téléchargement du script d'installation"
        exit 1
    fi
    
    if [[ ! -s qbittorrent-monitor.py ]] || [[ ! -s install.sh ]]; then
        log_error "Fichiers téléchargés invalides ou vides"
        exit 1
    fi
    
    CONFIG_PATH=$(detect_config_paths)
    
    log_step "Configuration pour l'utilisateur $USER_INPUT"
    sed -i "s/TEMPLATE_USER/$USER_INPUT/g" qbittorrent-monitor.py
    sed -i "s|TEMPLATE_HOME|/home/$USER_INPUT|g" qbittorrent-monitor.py
    sed -i "s|TEMPLATE_CONFIG_PATH|$CONFIG_PATH|g" qbittorrent-monitor.py
    
    sed -i "s/TEMPLATE_USER/$USER_INPUT/g" install.sh
    
    log_step "Application des permissions d'exécution"
    chmod +x qbittorrent-monitor.py install.sh
    
    log_step "Vérification des fichiers configurés"
    echo "📊 Fichiers prêts:"
    ls -la qbittorrent-monitor.py install.sh
    
    log_step "Lancement de l'installation système"
    if sudo ./install.sh; then
        echo ""
        echo -e "${GREEN}🎉 QBittorrent Monitor installé avec succès !${NC}"
        echo ""
        echo "📊 Informations du service:"
        echo "   Status: $(sudo systemctl is-active qbittorrent-monitor 2>/dev/null || echo 'Inactif')"
        echo "   Logs: tail -f ~/logs/qbittorrent-error-monitor.log"
        echo "   Stats: cat ~/logs/qbittorrent-stats.json"
        echo ""
        echo "⚙️  Commandes utiles:"
        echo "   sudo systemctl status qbittorrent-monitor"
        echo "   sudo systemctl restart qbittorrent-monitor"
        echo "   sudo journalctl -u qbittorrent-monitor -f"
        echo ""
        echo "🔗 Documentation: https://github.com/kesurof/QBittorrent-Error-Monitor"
    else
        log_error "Échec de l'installation système"
        echo "📋 Consultez les logs pour diagnostiquer le problème"
        echo "💡 Essayez: sudo journalctl -u qbittorrent-monitor -n 20"
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
