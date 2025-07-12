#!/bin/bash

# Configuration stricte pour la sécurité
set -euo pipefail
IFS=$'\n\t'

# Variables par défaut
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DEFAULT_USER=$(whoami)
readonly USER_INPUT="${1:-$DEFAULT_USER}"
readonly REPO_DIR="$HOME/scripts/qbittorrent-monitor"
readonly GITHUB_RAW_URL="https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main"

# Couleurs pour l'affichage
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Fonctions de logging sécurisées
log_info() { echo -e "${GREEN}✅ $1${NC}"; }
log_step() { echo -e "${BLUE}🔧 $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Fonction de validation sécurisée
validate_input() {
    local input="$1"
    local max_length="${2:-256}"
    
    # Vérification de la longueur
    if [[ ${#input} -gt $max_length ]]; then
        log_error "Entrée trop longue (max: $max_length caractères)"
        return 1
    fi
    
    # Vérification des caractères autorisés (alphanumériques, points, tirets, underscores)
    if [[ ! "$input" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        log_error "Caractères non autorisés dans: $input"
        return 1
    fi
    
    return 0
}

# Échappement sécurisé pour sed
escape_for_sed() {
    printf '%s\n' "$1" | sed 's/[[\.*^$()+?{|]/\\&/g'
}

# Validation sécurisée des chemins
validate_path() {
    local path="$1"
    
    # Vérification des tentatives de traversal
    if [[ "$path" == *".."* ]] || [[ "$path" == *"~"* ]]; then
        log_error "Chemin non sécurisé détecté: $path"
        return 1
    fi
    
    # Vérification de la longueur maximale
    if [[ ${#path} -gt 4096 ]]; then
        log_error "Chemin trop long: $path"
        return 1
    fi
    
    return 0
}

show_banner() {
    echo -e "${BLUE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║                    QBittorrent Error Monitor                     ║
║             Installation Sécurisée GitHub v2.0                  ║
║                     Production Ready                             ║
╚══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

detect_config_paths() {
    log_step "Détection sécurisée de la configuration existante"
    
    local config_base=""
    local -a possible_paths=(
        # Environnement ssdv2 (priorité)
        "$HOME/seedbox/docker/$USER_INPUT"
        "/home/$USER_INPUT/seedbox/docker/$USER_INPUT"
        # Autres environnements
        "$HOME/.config"
        "/opt/seedbox/docker/docker/$USER_INPUT"
        "/opt/docker/$USER_INPUT"
        "$HOME/docker/$USER_INPUT"
    )
    
    # Détection spéciale pour ssdv2
    if [[ -d "/home/$USER_INPUT/seedbox/docker/$USER_INPUT" ]]; then
        local ssdv2_path="/home/$USER_INPUT/seedbox/docker/$USER_INPUT"
        if [[ -d "$ssdv2_path/sonarr" ]] || [[ -d "$ssdv2_path/radarr" ]]; then
            config_base="$ssdv2_path"
            log_info "Environnement ssdv2 détecté: $config_base"
            echo "$config_base"
            return 0
        fi
    fi
    
    for path in "${possible_paths[@]}"; do
        # Validation du chemin avant vérification
        if validate_path "$path"; then
            if [[ -d "$path/sonarr" ]] || [[ -d "$path/radarr" ]]; then
                config_base="$path"
                log_info "Configuration trouvée: $config_base"
                break
            fi
        fi
    done
    
    if [[ -z "$config_base" ]]; then
        log_warn "Configuration non détectée automatiquement"
        
        # Suggestions spécifiques pour ssdv2
        echo ""
        echo "💡 Pour un environnement ssdv2, essayez :"
        echo "   /home/$USER_INPUT/seedbox/docker/$USER_INPUT"
        echo "   $HOME/seedbox/docker/$USER_INPUT"
        echo ""
        
        while true; do
            read -rp "Entrez le chemin vers vos configs Sonarr/Radarr: " config_base
            
            if validate_path "$config_base" && [[ -d "$config_base" ]]; then
                break
            else
                log_error "Chemin invalide ou inexistant. Veuillez réessayer."
            fi
        done
    fi
    
    echo "$config_base"
}

install_dependencies() {
    log_step "Installation sécurisée des dépendances Python"
    
    # Vérification de Python 3
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 non trouvé. Veuillez l'installer."
        exit 1
    fi
    
    # Installation depuis requirements.txt si disponible
    if [[ -f "requirements.txt" ]]; then
        log_step "Installation depuis requirements.txt"
        if ! python3 -m pip install --user -r requirements.txt; then
            log_error "Échec de l'installation des dépendances"
            exit 1
        fi
    else
        # Installation des paquets individuels
        local -a packages=("requests>=2.28.0" "PyYAML>=6.0" "urllib3>=1.26.0")
        
        for package in "${packages[@]}"; do
            if ! python3 -c "import ${package%%[><=]*}" 2>/dev/null; then
                log_step "Installation de $package"
                if ! python3 -m pip install --user "$package"; then
                    log_error "Échec de l'installation de $package"
                    exit 1
                fi
            fi
        done
    fi
    
    log_info "Dépendances vérifiées et installées"
}

secure_file_replacement() {
    local file="$1"
    local template="$2"
    local replacement="$3"
    
    if [[ ! -f "$file" ]]; then
        log_error "Fichier non trouvé: $file"
        return 1
    fi
    
    # Validation des entrées
    if ! validate_input "$replacement"; then
        log_error "Valeur de remplacement non valide: $replacement"
        return 1
    fi
    
    # Échappement sécurisé
    local escaped_replacement
    escaped_replacement=$(escape_for_sed "$replacement")
    
    # Remplacement sécurisé avec validation
    if ! sed -i.backup "s/$template/$escaped_replacement/g" "$file"; then
        log_error "Échec du remplacement dans $file"
        return 1
    fi
    
    # Vérification que le remplacement a eu lieu
    if ! grep -q "$replacement" "$file"; then
        log_error "Le remplacement n'a pas eu lieu dans $file"
        return 1
    fi
    
    return 0
}

download_file_secure() {
    local url="$1"
    local output="$2"
    local max_size="${3:-10485760}"  # 10MB par défaut
    
    log_step "Téléchargement sécurisé: $(basename "$output")"
    
    # Téléchargement avec limitations de sécurité
    if ! curl -fsSL \
        --max-filesize "$max_size" \
        --max-time 30 \
        --retry 3 \
        --retry-delay 2 \
        "$url" -o "$output"; then
        log_error "Échec du téléchargement de $url"
        return 1
    fi
    
    # Vérification que le fichier n'est pas vide
    if [[ ! -s "$output" ]]; then
        log_error "Fichier téléchargé vide: $output"
        return 1
    fi
    
    # Vérification basique du contenu pour les scripts Python
    if [[ "$output" == *.py ]]; then
        if ! head -1 "$output" | grep -q "#!/usr/bin/env python3"; then
            log_error "Fichier Python invalide: $output"
            return 1
        fi
    fi
    
    return 0
}

main() {
    show_banner
    
    # Validation de l'utilisateur cible
    if ! validate_input "$USER_INPUT"; then
        log_error "Nom d'utilisateur non valide: $USER_INPUT"
        exit 1
    fi
    
    echo "📍 Utilisateur cible: $USER_INPUT"
    echo "📂 Répertoire d'installation: $REPO_DIR"
    echo ""
    
    read -rp "Confirmez-vous l'installation pour l'utilisateur '$USER_INPUT' ? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Installation annulée par l'utilisateur"
        exit 0
    fi
    
    # Validation du répertoire de destination
    if ! validate_path "$REPO_DIR"; then
        log_error "Répertoire de destination non valide: $REPO_DIR"
        exit 1
    fi
    
    install_dependencies
    
    log_step "Création sécurisée du répertoire de travail"
    if ! mkdir -p "$REPO_DIR"; then
        log_error "Impossible de créer le répertoire: $REPO_DIR"
        exit 1
    fi
    
    # Changement de répertoire sécurisé
    if ! cd "$REPO_DIR"; then
        log_error "Impossible d'accéder au répertoire: $REPO_DIR"
        exit 1
    fi
    
    # Téléchargement sécurisé des fichiers
    local -a files_to_download=(
        "qbittorrent-monitor.py"
        "install.sh"
        "requirements.txt"
    )
    
    for file in "${files_to_download[@]}"; do
        if ! download_file_secure "$GITHUB_RAW_URL/$file" "$file"; then
            log_error "Échec du téléchargement critique: $file"
            exit 1
        fi
    done
    
    # Téléchargement du fichier de configuration exemple
    mkdir -p config
    if ! download_file_secure "$GITHUB_RAW_URL/config/config.yaml" "config/config.yaml"; then
        log_warn "Fichier de configuration exemple non disponible"
    fi
    
    # Détection sécurisée des chemins de configuration
    local config_path
    config_path=$(detect_config_paths)
    
    if [[ -z "$config_path" ]] || ! validate_path "$config_path"; then
        log_error "Chemin de configuration invalide"
        exit 1
    fi
    
    log_step "Configuration sécurisée pour l'utilisateur $USER_INPUT"
    
    # Remplacement sécurisé des templates
    if ! secure_file_replacement "qbittorrent-monitor.py" "TEMPLATE_USER" "$USER_INPUT"; then
        exit 1
    fi
    
    if ! secure_file_replacement "qbittorrent-monitor.py" "TEMPLATE_HOME" "/home/$USER_INPUT"; then
        exit 1
    fi
    
    if ! secure_file_replacement "qbittorrent-monitor.py" "TEMPLATE_CONFIG_PATH" "$config_path"; then
        exit 1
    fi
    
    if ! secure_file_replacement "install.sh" "TEMPLATE_USER" "$USER_INPUT"; then
        exit 1
    fi
    
    log_step "Application des permissions d'exécution"
    if ! chmod +x qbittorrent-monitor.py install.sh; then
        log_error "Échec de l'application des permissions"
        exit 1
    fi
    
    log_step "Validation des fichiers configurés"
    echo "📊 Fichiers prêts:"
    ls -la qbittorrent-monitor.py install.sh config/ 2>/dev/null || true
    
    # Test de syntaxe Python
    log_step "Validation de la syntaxe Python"
    if ! python3 -m py_compile qbittorrent-monitor.py; then
        log_error "Erreur de syntaxe dans qbittorrent-monitor.py"
        exit 1
    fi
    
    # Test de dry-run
    log_step "Test de fonctionnement (dry-run)"
    if python3 qbittorrent-monitor.py --test --dry-run --verbose; then
        log_info "Test dry-run réussi"
    else
        log_warn "Test dry-run échoué - vérifiez la configuration"
    fi
    
    log_step "Lancement de l'installation système"
    
    # Détection de l'environnement
    local deployment_mode="systemd"
    
    # Vérification si c'est un environnement ssdv2/Docker
    if command -v docker &> /dev/null && docker network ls | grep -q "traefik_proxy"; then
        echo ""
        log_info "Environnement Docker/ssdv2 détecté !"
        echo ""
        echo "🐳 Deux modes de déploiement disponibles :"
        echo "   1) Service systemd (classique)"
        echo "   2) Conteneur Docker (recommandé pour ssdv2)"
        echo ""
        
        while true; do
            read -rp "Choisissez le mode de déploiement (1/2): " choice
            case $choice in
                1)
                    deployment_mode="systemd"
                    break
                    ;;
                2)
                    deployment_mode="docker"
                    break
                    ;;
                *)
                    echo "Veuillez choisir 1 ou 2"
                    ;;
            esac
        done
    fi
    
    case $deployment_mode in
        "docker")
            log_step "Déploiement Docker ssdv2"
            
            # Copie du script de déploiement Docker
            if [[ -f "$SCRIPT_DIR/deploy-ssdv2.sh" ]]; then
                cp "$SCRIPT_DIR/deploy-ssdv2.sh" ./
                chmod +x deploy-ssdv2.sh
            fi
            
            echo ""
            echo -e "${GREEN}🐳 Configuration Docker prête !${NC}"
            echo ""
            echo "📋 Étapes suivantes :"
            echo "   1. Vérifiez la configuration : cat config/config.yaml"
            echo "   2. Lancez le déploiement : ./deploy-ssdv2.sh start"
            echo ""
            echo "🔧 Commandes Docker disponibles :"
            echo "   ./deploy-ssdv2.sh start    # Déployer le monitor"
            echo "   ./deploy-ssdv2.sh status   # Vérifier le status"
            echo "   ./deploy-ssdv2.sh logs     # Voir les logs"
            echo "   ./deploy-ssdv2.sh restart  # Redémarrer"
            echo ""
            echo "🌐 Intégration ssdv2 :"
            echo "   - Réseau : traefik_proxy"
            echo "   - Configs : $config_path"
            echo "   - Variables : MYUID/MYGID automatiques"
            echo ""
            ;;
        "systemd")
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
                echo "🧪 Tests disponibles:"
                echo "   python3 ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py --test"
                echo "   python3 ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py --health-check"
                echo "   python3 ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py --dry-run"
                echo ""
                echo "🔗 Documentation: https://github.com/kesurof/QBittorrent-Error-Monitor"
            else
                log_error "Échec de l'installation système"
                echo "📋 Consultez les logs pour diagnostiquer le problème"
                echo "💡 Essayez: sudo journalctl -u qbittorrent-monitor -n 20"
                exit 1
            fi
            ;;
    esac
}

# Protection contre l'exécution accidentelle
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
