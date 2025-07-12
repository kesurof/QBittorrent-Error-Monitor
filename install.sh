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
echo "  1. bridge (défaut Docker)"
echo "  2. traefik_proxy (Traefik)"
echo "  3. docker_default (Docker Compose)"
echo "  4. Autre (saisie manuelle)"

echo ""
read -p "🌐 Choisir le réseau [1-4] : " NETWORK_CHOICE

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
        echo "❌ Choix invalide, utilisation de 'bridge'"
        DOCKER_NETWORK="bridge"
        ;;
esac

# Vérifier que le réseau existe
if ! docker network inspect "$DOCKER_NETWORK" &> /dev/null; then
    echo "⚠️  Le réseau '$DOCKER_NETWORK' n'existe pas."
    echo "📋 Réseaux disponibles :"
    docker network ls --format "{{.Name}}"
    read -p "🌐 Veuillez entrer un réseau valide : " DOCKER_NETWORK
    
    if ! docker network inspect "$DOCKER_NETWORK" &> /dev/null; then
        echo "❌ Réseau '$DOCKER_NETWORK' toujours introuvable. Utilisation de 'bridge'."
        DOCKER_NETWORK="bridge"
    fi
fi

echo "✅ Réseau sélectionné : $DOCKER_NETWORK"

# Configuration des chemins vers les applications
echo ""
echo "📂 Configuration des chemins vers Sonarr/Radarr :"

# Détecter l'utilisateur actuel
CURRENT_USER=$(whoami)
DEFAULT_SEEDBOX_PATH="/home/$CURRENT_USER/seedbox/docker/$CURRENT_USER"

echo "📋 Chemins suggérés :"
echo "  1. Seedbox standard : $DEFAULT_SEEDBOX_PATH"
echo "  2. Docker Compose local : ./data"
echo "  3. Personnalisé"

echo ""
read -p "📂 Choisir le type de chemin [1-3] : " PATH_CHOICE

case $PATH_CHOICE in
    1|"")
        CONFIGS_PATH="$DEFAULT_SEEDBOX_PATH"
        ;;
    2)
        CONFIGS_PATH="./data"
        ;;
    3)
        read -p "📂 Entrez le chemin personnalisé : " CONFIGS_PATH
        ;;
    *)
        CONFIGS_PATH="$DEFAULT_SEEDBOX_PATH"
        ;;
esac

# Vérifier que le chemin existe
if [ ! -d "$CONFIGS_PATH" ]; then
    echo "⚠️  Le chemin '$CONFIGS_PATH' n'existe pas."
    echo "📋 Voulez-vous :"
    echo "  1. Le créer automatiquement"
    echo "  2. Utiliser un autre chemin"
    read -p "Votre choix [1-2] : " CREATE_PATH_CHOICE
    
    if [ "$CREATE_PATH_CHOICE" = "1" ]; then
        echo "🔧 Création du répertoire '$CONFIGS_PATH'..."
        mkdir -p "$CONFIGS_PATH"
        echo "✅ Répertoire '$CONFIGS_PATH' créé"
    else
        read -p "📂 Entrez un chemin existant : " CONFIGS_PATH
        if [ ! -d "$CONFIGS_PATH" ]; then
            echo "❌ Chemin '$CONFIGS_PATH' toujours introuvable. Utilisation de ./data"
            CONFIGS_PATH="./data"
            mkdir -p "$CONFIGS_PATH"
        fi
    fi
fi

echo "✅ Chemin sélectionné : $CONFIGS_PATH"

# Configuration des répertoires
INSTALL_DIR="${HOME}/qbittorrent-monitor"
echo "📁 Création des répertoires dans : $INSTALL_DIR"

# Créer les répertoires avec les bonnes permissions
if ! mkdir -p "$INSTALL_DIR/config" "$INSTALL_DIR/logs" 2>/dev/null; then
    echo "❌ Impossible de créer les répertoires dans $INSTALL_DIR"
    echo "🔧 Tentative avec sudo..."
    sudo mkdir -p "$INSTALL_DIR/config" "$INSTALL_DIR/logs"
    sudo chown -R $(whoami):$(whoami) "$INSTALL_DIR"
fi

# Vérifier que les répertoires sont accessibles en écriture
if [ ! -w "$INSTALL_DIR/config" ]; then
    echo "🔧 Correction des permissions..."
    sudo chown -R $(whoami):$(whoami) "$INSTALL_DIR"
fi

# Téléchargement de la configuration
echo "📄 Téléchargement de la configuration..."
if ! curl -sSL -o "$INSTALL_DIR/config/config.yaml" \
    "https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/config/config.yaml"; then
    echo "❌ Erreur lors du téléchargement de la configuration"
    echo "🔧 Tentative de création manuelle..."
    
    # Créer une configuration de base si le téléchargement échoue
    cat > "$INSTALL_DIR/config/config.yaml" << 'EOF'
# Configuration QBittorrent Error Monitor
qbittorrent:
  host: "localhost"
  port: 8080
  username: "admin"
  password: "adminadmin"

docker:
  network: "bridge"

applications:
  sonarr:
    enabled: true
    config_path: "/configs/sonarr/config"
    docker_name: "sonarr"
  radarr:
    enabled: true
    config_path: "/configs/radarr/config"
    docker_name: "radarr"

monitoring:
  check_interval: 300
  max_retries: 3
  
logging:
  level: "INFO"
  file: "/config/logs/monitor.log"
EOF
    
    if [ $? -eq 0 ]; then
        echo "✅ Configuration de base créée"
    else
        echo "❌ Impossible de créer la configuration. Vérifiez les permissions."
        exit 1
    fi
fi

# Mise à jour de la configuration avec le réseau et les chemins choisis
echo "🔧 Configuration du réseau et des chemins..."

# Vérifier que le fichier config existe
if [ ! -f "$INSTALL_DIR/config/config.yaml" ]; then
    echo "❌ Fichier de configuration manquant"
    exit 1
fi

# Sauvegarder la configuration originale
cp "$INSTALL_DIR/config/config.yaml" "$INSTALL_DIR/config/config.yaml.backup"

# Mettre à jour la configuration
if sed -i.bak "s|network: \"bridge\"|network: \"$DOCKER_NETWORK\"|" "$INSTALL_DIR/config/config.yaml" && \
   sed -i.bak2 "s|/configs/sonarr/config|$CONFIGS_PATH/sonarr/config|" "$INSTALL_DIR/config/config.yaml" && \
   sed -i.bak3 "s|/configs/radarr/config|$CONFIGS_PATH/radarr/config|" "$INSTALL_DIR/config/config.yaml"; then
    
    echo "✅ Configuration mise à jour"
    rm -f "$INSTALL_DIR/config/config.yaml.bak"*
else
    echo "⚠️  Erreur lors de la mise à jour de la configuration"
    echo "🔧 Restauration de la sauvegarde..."
    mv "$INSTALL_DIR/config/config.yaml.backup" "$INSTALL_DIR/config/config.yaml"
    
    # Mettre à jour manuellement en cas d'échec de sed
    echo "🔧 Mise à jour manuelle de la configuration..."
    python3 -c "
import yaml
import sys

try:
    with open('$INSTALL_DIR/config/config.yaml', 'r') as f:
        config = yaml.safe_load(f)
    
    # Mettre à jour les valeurs
    if 'docker' not in config:
        config['docker'] = {}
    config['docker']['network'] = '$DOCKER_NETWORK'
    
    if 'applications' not in config:
        config['applications'] = {}
    if 'sonarr' not in config['applications']:
        config['applications']['sonarr'] = {}
    if 'radarr' not in config['applications']:
        config['applications']['radarr'] = {}
    
    config['applications']['sonarr']['config_path'] = '$CONFIGS_PATH/sonarr/config'
    config['applications']['radarr']['config_path'] = '$CONFIGS_PATH/radarr/config'
    
    with open('$INSTALL_DIR/config/config.yaml', 'w') as f:
        yaml.dump(config, f, default_flow_style=False)
    
    print('✅ Configuration mise à jour avec Python')
except Exception as e:
    print(f'❌ Erreur Python: {e}')
    sys.exit(1)
" || echo "⚠️  Impossible de mettre à jour la configuration automatiquement"
fi

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
    -v "$CONFIGS_PATH:/configs:ro" \
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
    echo "   📂 Chemins configs : $CONFIGS_PATH"
    echo "   🌐 Health check : http://localhost:8080"
    echo "   📊 Logs : docker logs -f qbittorrent-monitor"
    echo "   📁 Configuration : $INSTALL_DIR/config/config.yaml"
    echo "   📝 Logs applicatifs : $INSTALL_DIR/logs/"
    echo ""
    echo "📂 Structure attendue :"
    echo "   $CONFIGS_PATH/sonarr/config/config.xml"
    echo "   $CONFIGS_PATH/radarr/config/config.xml"
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
