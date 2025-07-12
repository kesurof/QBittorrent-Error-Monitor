#!/bin/bash

# Script d'installation QBittorrent Monitor (Docker simple)
set -euo pipefail

echo "🚀 Installation QBittorrent Error Monitor"

# Vérification des prérequis
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé. Veuillez l'installer avant de continuer."
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker n'est pas démarré. Veuillez démarrer Docker."
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
echo "  • <nom_projet>_default (projet spécifique)"

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

# Téléchargement de la configuration
echo "📄 Téléchargement de la configuration..."
curl -sSL -o "$INSTALL_DIR/config/config.yaml" \
    "https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/config/config.yaml"

# Mise à jour de la configuration avec le réseau choisi
echo "🔧 Configuration du réseau Docker..."
sed -i.bak "s/network: \"bridge\"/network: \"$DOCKER_NETWORK\"/" "$INSTALL_DIR/config/config.yaml"
rm -f "$INSTALL_DIR/config/config.yaml.bak"

# Arrêter l'ancien conteneur s'il existe
echo "🧹 Nettoyage de l'ancienne installation..."
docker stop qbittorrent-monitor 2>/dev/null || true
docker rm qbittorrent-monitor 2>/dev/null || true

# Démarrage du conteneur
echo "🚀 Démarrage du conteneur..."
docker run -d \
    --name qbittorrent-monitor \
    --restart unless-stopped \
    --network "$DOCKER_NETWORK" \
    -e PUID=$(id -u) \
    -e PGID=$(id -g) \
    -e TZ=Europe/Paris \
    -v "$INSTALL_DIR/config:/config:rw" \
    -v "$INSTALL_DIR/logs:/config/logs:rw" \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -p 8080:8080 \
    ghcr.io/kesurof/qbittorrent-error-monitor/qbittorrent-monitor:latest

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
    echo "   🌐 Health check : http://localhost:8080"
    echo "   📊 Logs : docker logs -f qbittorrent-monitor"
    echo "   📁 Configuration : $INSTALL_DIR/config/config.yaml"
    echo "   📝 Logs applicatifs : $INSTALL_DIR/logs/"
    echo ""
    echo "🔧 Commandes utiles :"
    echo "   docker restart qbittorrent-monitor"
    echo "   docker stop qbittorrent-monitor"
    echo "   docker logs qbittorrent-monitor"
else
    echo "❌ Erreur lors du démarrage. Vérification des logs :"
    docker logs qbittorrent-monitor 2>/dev/null || echo "Aucun log disponible"
    exit 1
fi
