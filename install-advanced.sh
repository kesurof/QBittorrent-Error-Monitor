#!/bin/bash

# Script d'installation QBittorrent Monitor - Version avancée
set -euo pipefail

echo "🚀 Installation QBittorrent Error Monitor - Mode avancé"

# Vérification des prérequis
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé. Veuillez l'installer avant de continuer."
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker n'est pas démarré. Veuillez démarrer Docker."
    exit 1
fi

# === Configuration du réseau ===
echo ""
echo "🔍 Détection des réseaux Docker disponibles :"
docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"

echo ""
echo "📋 Réseaux couramment utilisés :"
echo "  1. bridge (défaut Docker)"
echo "  2. traefik_proxy (Traefik Proxy)"  
echo "  3. docker_default (Docker Compose)"
echo "  4. Autre (saisie manuelle)"

echo ""
read -p "🌐 Choisir le réseau [1-4] ou nom direct : " NETWORK_CHOICE

case $NETWORK_CHOICE in
    1|"")
        DOCKER_NETWORK="bridge"
        ;;
    2)
        DOCKER_NETWORK="traefik_proxy"
        ;;
    3)
        DOCKER_NETWORK="docker_default"
        ;;
    4)
        read -p "🌐 Entrez le nom du réseau : " DOCKER_NETWORK
        ;;
    *)
        # Traiter comme nom de réseau direct
        DOCKER_NETWORK="$NETWORK_CHOICE"
        ;;
esac

# Vérifier que le réseau existe
if ! docker network inspect "$DOCKER_NETWORK" &> /dev/null; then
    echo "⚠️  Le réseau '$DOCKER_NETWORK' n'existe pas."
    echo "📋 Voulez-vous :"
    echo "  1. Le créer automatiquement"
    echo "  2. Choisir un autre réseau existant"
    read -p "Votre choix [1-2] : " CREATE_CHOICE
    
    if [ "$CREATE_CHOICE" = "1" ]; then
        echo "🔧 Création du réseau '$DOCKER_NETWORK'..."
        docker network create "$DOCKER_NETWORK"
        echo "✅ Réseau '$DOCKER_NETWORK' créé"
    else
        echo "📋 Réseaux disponibles :"
        docker network ls --format "{{.Name}}"
        read -p "🌐 Veuillez entrer un réseau valide : " DOCKER_NETWORK
        
        if ! docker network inspect "$DOCKER_NETWORK" &> /dev/null; then
            echo "❌ Réseau '$DOCKER_NETWORK' toujours introuvable. Arrêt."
            exit 1
        fi
    fi
fi

echo "✅ Réseau sélectionné : $DOCKER_NETWORK"

# === Configuration des chemins ===
echo ""
echo "📁 Configuration des chemins :"
read -p "📂 Répertoire d'installation [${HOME}/qbittorrent-monitor] : " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-"${HOME}/qbittorrent-monitor"}

echo "📁 Création des répertoires dans : $INSTALL_DIR"
mkdir -p "$INSTALL_DIR/config" "$INSTALL_DIR/logs"

# === Configuration des conteneurs cibles ===
echo ""
echo "🎯 Configuration des conteneurs à surveiller :"
echo "📋 Noms de conteneurs par défaut :"
echo "  • Sonarr : sonarr"
echo "  • Radarr : radarr"  
echo "  • qBittorrent : qbittorrent"

read -p "📺 Nom du conteneur Sonarr [sonarr] : " SONARR_CONTAINER
SONARR_CONTAINER=${SONARR_CONTAINER:-sonarr}

read -p "🎬 Nom du conteneur Radarr [radarr] : " RADARR_CONTAINER  
RADARR_CONTAINER=${RADARR_CONTAINER:-radarr}

read -p "📥 Nom du conteneur qBittorrent [qbittorrent] : " QBITTORRENT_CONTAINER
QBITTORRENT_CONTAINER=${QBITTORRENT_CONTAINER:-qbittorrent}

# === Téléchargement et configuration ===
echo ""
echo "📄 Téléchargement de la configuration..."
curl -sSL -o "$INSTALL_DIR/config/config.yaml" \
    "https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/config/config.yaml"

echo "🔧 Personnalisation de la configuration..."

# Mise à jour du réseau
sed -i.bak "s/network: \"bridge\"/network: \"$DOCKER_NETWORK\"/" "$INSTALL_DIR/config/config.yaml"

# Mise à jour des noms de conteneurs
sed -i.bak2 "s/- \"sonarr\"/- \"$SONARR_CONTAINER\"/" "$INSTALL_DIR/config/config.yaml"
sed -i.bak3 "s/- \"radarr\"/- \"$RADARR_CONTAINER\"/" "$INSTALL_DIR/config/config.yaml"

# Nettoyage des fichiers de backup
rm -f "$INSTALL_DIR/config/config.yaml.bak"*

# === Installation ===
echo ""
echo "🧹 Nettoyage de l'ancienne installation..."
docker stop qbittorrent-monitor 2>/dev/null || true
docker rm qbittorrent-monitor 2>/dev/null || true

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

# === Vérification ===
echo "⏳ Attente du démarrage (10 secondes)..."
sleep 10

if docker ps | grep -q qbittorrent-monitor; then
    echo ""
    echo "✅ Installation terminée avec succès !"
    echo ""
    echo "📋 Configuration :"
    echo "   🌐 Réseau Docker : $DOCKER_NETWORK"
    echo "   📂 Répertoire : $INSTALL_DIR"
    echo "   📺 Conteneur Sonarr : $SONARR_CONTAINER"
    echo "   🎬 Conteneur Radarr : $RADARR_CONTAINER"
    echo "   📥 Conteneur qBittorrent : $QBITTORRENT_CONTAINER"
    echo ""
    echo "🔗 Liens utiles :"
    echo "   🌐 Health check : http://localhost:8080"
    echo "   📊 Logs : docker logs -f qbittorrent-monitor"
    echo "   📁 Configuration : $INSTALL_DIR/config/config.yaml"
    echo ""
    echo "🔧 Commandes utiles :"
    echo "   docker restart qbittorrent-monitor"
    echo "   docker stop qbittorrent-monitor"
    echo "   docker logs qbittorrent-monitor"
    
    # Test de connectivité réseau
    echo ""
    echo "🧪 Test de connectivité réseau..."
    if docker exec qbittorrent-monitor nslookup "$SONARR_CONTAINER" 2>/dev/null; then
        echo "✅ $SONARR_CONTAINER accessible"
    else
        echo "⚠️  $SONARR_CONTAINER non accessible (normal s'il n'existe pas)"
    fi
    
    if docker exec qbittorrent-monitor nslookup "$RADARR_CONTAINER" 2>/dev/null; then
        echo "✅ $RADARR_CONTAINER accessible"
    else
        echo "⚠️  $RADARR_CONTAINER non accessible (normal s'il n'existe pas)"
    fi
else
    echo "❌ Erreur lors du démarrage. Vérification des logs :"
    docker logs qbittorrent-monitor 2>/dev/null || echo "Aucun log disponible"
    exit 1
fi
