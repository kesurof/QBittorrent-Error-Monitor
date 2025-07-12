#!/bin/bash

# Script d'installation QBittorrent Monitor (Docker Compose)
set -euo pipefail

# Vérification des prérequis
if ! command -v docker &> /dev/null; then
    echo "Docker n'est pas installé. Veuillez l'installer avant de continuer."
    exit 1
fi
if ! command -v docker-compose &> /dev/null; then
    echo "docker-compose n'est pas installé. Veuillez l'installer avant de continuer."
    exit 1
fi

# Configuration des répertoires
INSTALL_DIR="${HOME}/qbittorrent-monitor"
mkdir -p "$INSTALL_DIR/config" "$INSTALL_DIR/logs"

# Téléchargement des fichiers nécessaires
curl -sSL -o "$INSTALL_DIR/docker-compose.yml" \
    "https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/docker-compose.yml"
curl -sSL -o "$INSTALL_DIR/config/config.yaml" \
    "https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/config/config.yaml"

# Démarrage du service
cd "$INSTALL_DIR"
docker-compose up -d

echo "Installation terminée avec succès !"
