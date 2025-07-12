#!/bin/bash

# Script de construction et déploiement MANUEL pour GitHub Container Registry
# ⚠️  ATTENTION : Ce script n'est nécessaire QUE si GitHub Actions ne fonctionne pas
# 🚀 RECOMMANDÉ : Utilisez GitHub Actions pour un déploiement automatique
#
# Usage normal : Push vers GitHub → GitHub Actions s'occupe de tout
# Usage de secours : ./deploy-ghcr.sh (si GitHub Actions indisponible)

set -e

echo "🚀 Déploiement QBittorrent Error Monitor avec GitHub Container Registry"

# Configuration
REPO_OWNER="kesurof"  # Votre nom d'utilisateur GitHub
IMAGE_NAME="ghcr.io/${REPO_OWNER}/qbittorrent-error-monitor/qbittorrent-monitor"
TAG="ssdv2"

# Vérifications
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker n'est pas démarré"
    exit 1
fi

# Nettoyage
echo "🧹 Nettoyage des anciennes images..."
docker system prune -f || true

# Construction de l'image
echo "🔨 Construction de l'image Docker..."
docker build -t "${IMAGE_NAME}:${TAG}" .
docker tag "${IMAGE_NAME}:${TAG}" "${IMAGE_NAME}:latest"

# Connexion à GitHub Container Registry
echo "🔐 Connexion à GitHub Container Registry..."
echo "Entrez votre Personal Access Token GitHub (avec permissions packages:write):"
read -s GITHUB_TOKEN
echo $GITHUB_TOKEN | docker login ghcr.io -u "${REPO_OWNER}" --password-stdin

# Publication
echo "📤 Publication vers GitHub Container Registry..."
docker push "${IMAGE_NAME}:${TAG}"
docker push "${IMAGE_NAME}:latest"

echo "✅ Image publiée avec succès !"
echo "📦 Image: ${IMAGE_NAME}:${TAG}"
echo ""
echo "🔄 Pour utiliser avec ssdv2, remplacez dans qbittorrent-monitor.yml :"
echo "image: '${IMAGE_NAME}:${TAG}'"
