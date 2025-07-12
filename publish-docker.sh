#!/bin/bash

# Script de publication Docker Hub pour QBittorrent Error Monitor
# Compatible ssdv2

set -euo pipefail

# Configuration
readonly IMAGE_NAME="qbittorrent-error-monitor"
readonly DOCKER_REPO="your-dockerhub-username"  # À remplacer
readonly VERSION="2.0"
readonly PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7"

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
║           QBittorrent Monitor - Publication Docker              ║
║                    Multi-architecture Build                     ║
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
    
    # Vérification de buildx
    if ! docker buildx version &> /dev/null; then
        log_error "Docker buildx n'est pas installé"
        exit 1
    fi
    
    # Vérification de la connexion Docker Hub
    if ! docker info | grep -q "Username"; then
        log_warn "Non connecté à Docker Hub"
        echo "💡 Connectez-vous avec: docker login"
        read -rp "Continuer quand même ? (y/N): " continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    log_info "Prérequis validés"
}

setup_buildx() {
    log_step "Configuration de buildx pour multi-architecture"
    
    # Créer ou utiliser un builder existant
    if ! docker buildx inspect multiarch-builder &> /dev/null; then
        docker buildx create --name multiarch-builder --driver docker-container --use
    else
        docker buildx use multiarch-builder
    fi
    
    # Démarrer le builder
    docker buildx inspect --bootstrap
    
    log_info "Builder multi-architecture configuré"
}

build_and_push() {
    log_step "Construction et publication multi-architecture"
    
    local tags=(
        "${DOCKER_REPO}/${IMAGE_NAME}:latest"
        "${DOCKER_REPO}/${IMAGE_NAME}:${VERSION}"
        "${DOCKER_REPO}/${IMAGE_NAME}:ssdv2"
    )
    
    # Construction des arguments de tags
    local tag_args=""
    for tag in "${tags[@]}"; do
        tag_args="$tag_args -t $tag"
    done
    
    log_step "Construction pour les plateformes : $PLATFORMS"
    
    # Build et push en une commande
    if docker buildx build \
        --platform "$PLATFORMS" \
        $tag_args \
        --push \
        --progress plain \
        .; then
        log_info "Images publiées avec succès"
    else
        log_error "Échec de la publication"
        exit 1
    fi
}

show_results() {
    echo ""
    log_info "🎉 Publication terminée !"
    echo ""
    echo "📦 Images disponibles :"
    echo "   docker pull ${DOCKER_REPO}/${IMAGE_NAME}:latest"
    echo "   docker pull ${DOCKER_REPO}/${IMAGE_NAME}:${VERSION}"
    echo "   docker pull ${DOCKER_REPO}/${IMAGE_NAME}:ssdv2"
    echo ""
    echo "🏗️ Plateformes supportées :"
    echo "   - linux/amd64 (Intel/AMD 64-bit)"
    echo "   - linux/arm64 (ARM 64-bit, Raspberry Pi 4+)"
    echo "   - linux/arm/v7 (ARM 32-bit, Raspberry Pi 3)"
    echo ""
    echo "📄 Pour ssdv2, utilisez dans votre fichier YAML :"
    echo "   image: '${DOCKER_REPO}/${IMAGE_NAME}:ssdv2'"
    echo ""
}

build_local() {
    log_step "Construction locale uniquement"
    
    docker build -t "${IMAGE_NAME}:latest" .
    
    log_info "Image locale construite : ${IMAGE_NAME}:latest"
}

# Menu principal
main() {
    show_banner
    
    case "${1:-build}" in
        "publish"|"push")
            check_requirements
            setup_buildx
            build_and_push
            show_results
            ;;
        "build"|"local")
            build_local
            ;;
        "setup")
            check_requirements
            setup_buildx
            ;;
        *)
            echo "Usage: $0 {build|publish|setup}"
            echo ""
            echo "Commandes :"
            echo "  build    - Construction locale uniquement"
            echo "  publish  - Construction et publication multi-arch"
            echo "  setup    - Configuration buildx seulement"
            echo ""
            echo "💡 Avant la première publication :"
            echo "   1. Modifiez DOCKER_REPO avec votre nom d'utilisateur"
            echo "   2. Connectez-vous : docker login"
            echo "   3. Lancez : $0 publish"
            exit 1
            ;;
    esac
}

# Protection contre l'exécution accidentelle
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
