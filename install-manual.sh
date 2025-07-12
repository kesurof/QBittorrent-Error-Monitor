#!/bin/bash

# Script d'installation QBittorrent Monitor (Docker Compose)
set -euo pipefail

echo "🚀 Installation QBittorrent Error Monitor avec Docker Compose"

# Vérification des prérequis
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé. Veuillez l'installer avant de continuer."
    exit 1
fi
if ! command -v docker-compose &> /dev/null; then
    echo "❌ docker-compose n'est pas installé. Veuillez l'installer avant de continuer."
    exit 1
fi

# Détection des réseaux Docker disponibles
echo ""
echo "🔍 Détection des réseaux Docker disponibles :"
docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"

echo ""
echo "📋 Réseaux couramment utilisés :"
echo "  • bridge (défaut Docker)"
echo "  • traefik_proxy (Traefik)"
echo "  • docker_default (Docker Compose)"

echo ""
read -p "🌐 Quel réseau Docker utiliser ? [bridge] : " DOCKER_NETWORK
DOCKER_NETWORK=${DOCKER_NETWORK:-bridge}

# Vérifier que le réseau existe
if ! docker network inspect "$DOCKER_NETWORK" &> /dev/null; then
    echo "⚠️  Le réseau '$DOCKER_NETWORK' n'existe pas."
    echo "📋 Réseaux disponibles :"
    docker network ls --format "{{.Name}}"
    read -p "🌐 Veuillez entrer un réseau valide : " DOCKER_NETWORK
    
    if ! docker network inspect "$DOCKER_NETWORK" &> /dev/null; then
        echo "❌ Réseau '$DOCKER_NETWORK' toujours introuvable. Arrêt."
        exit 1
    fi
fi

echo "✅ Réseau sélectionné : $DOCKER_NETWORK"

# Configuration des répertoires
INSTALL_DIR="${HOME}/qbittorrent-monitor"
echo "📁 Création des répertoires dans : $INSTALL_DIR"
mkdir -p "$INSTALL_DIR/config" "$INSTALL_DIR/logs"

# Téléchargement des fichiers nécessaires
echo "📄 Téléchargement des fichiers..."
curl -sSL -o "$INSTALL_DIR/docker-compose.yml" \
    "https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/docker-compose.yml"
curl -sSL -o "$INSTALL_DIR/config/config.yaml" \
    "https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/config/config.yaml"

# Création du fichier .env
echo "🔧 Configuration de l'environnement..."
cat > "$INSTALL_DIR/.env" << EOF
# Configuration QBittorrent Error Monitor
PUID=$(id -u)
PGID=$(id -g)
TZ=Europe/Paris
USERDIR=$INSTALL_DIR
DOCKER_NETWORK=$DOCKER_NETWORK
HTTP_PORT=8080
CHECK_INTERVAL=300
LOG_LEVEL=INFO
DRY_RUN=false
EOF

# Mise à jour de la configuration avec le réseau choisi
echo "🔧 Configuration du réseau Docker..."
sed -i.bak "s/network: \"bridge\"/network: \"$DOCKER_NETWORK\"/" "$INSTALL_DIR/config/config.yaml"
rm -f "$INSTALL_DIR/config/config.yaml.bak"

# Démarrage du service
echo "🚀 Démarrage du service..."
cd "$INSTALL_DIR"
docker-compose down 2>/dev/null || true
docker-compose up -d

# Attendre un peu pour le démarrage
echo "⏳ Attente du démarrage (10 secondes)..."
sleep 10

# Vérifier le statut
if docker ps | grep -q qbittorrent-monitor; then
    echo ""
    echo "✅ Installation terminée avec succès !"
    echo ""
    echo "📋 Configuration :"
    echo "   🌐 Réseau Docker : $DOCKER_NETWORK"
    echo "   📂 Répertoire : $INSTALL_DIR"
    echo "   🌐 Health check : http://localhost:8080"
    echo "   📊 Logs : docker-compose logs -f"
    echo "   📁 Fichiers : $INSTALL_DIR/"
    echo ""
    echo "🔧 Commandes utiles (depuis $INSTALL_DIR) :"
    echo "   docker-compose restart"
    echo "   docker-compose stop"
    echo "   docker-compose logs -f qbittorrent-monitor"
    echo "   docker-compose down  # Arrêter et supprimer"
else
    echo "❌ Erreur lors du démarrage. Vérification des logs :"
    cd "$INSTALL_DIR" && docker-compose logs qbittorrent-monitor 2>/dev/null || echo "Aucun log disponible"
    exit 1
fi
