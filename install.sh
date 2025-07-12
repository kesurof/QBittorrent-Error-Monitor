#!/bin/bash

# Script d'installation QBittorrent Monitor (Docker simple)
set -euo pipefail

# Vérification des prérequis
if ! command -v docker &> /dev/null; then
    echo "Docker n'est pas installé. Veuillez l'installer avant de continuer."
    exit 1
fi

# Configuration des répertoires
INSTALL_DIR="${HOME}/qbittorrent-monitor"
mkdir -p "$INSTALL_DIR/config" "$INSTALL_DIR/logs"

# Téléchargement de la configuration
curl -sSL -o "$INSTALL_DIR/config/config.yaml" \
    "https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/config/config.yaml"

# Démarrage du conteneur
docker run -d \
    --name qbittorrent-monitor \
    --restart unless-stopped \
    -e PUID=$(id -u) \
    -e PGID=$(id -g) \
    -e TZ=Europe/Paris \
    -v "$INSTALL_DIR/config:/app/config:rw" \
    -v "$INSTALL_DIR/logs:/app/logs:rw" \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -p 8080:8080 \
    ghcr.io/kesurof/qbittorrent-error-monitor/qbittorrent-monitor:latest

echo "Installation terminée avec succès !"
