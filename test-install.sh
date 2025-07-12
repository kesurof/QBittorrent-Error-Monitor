#!/bin/bash

# Script de test rapide pour QBittorrent Monitor
set -e

echo "🧪 Test rapide QBittorrent Monitor"

# Vérifier que le conteneur fonctionne
if ! docker ps | grep -q qbittorrent-monitor; then
    echo "❌ Conteneur qbittorrent-monitor non trouvé"
    exit 1
fi

echo "✅ Conteneur en cours d'exécution"

# Test du health check
echo "🩺 Test du health check..."
if curl -f http://localhost:8080 2>/dev/null; then
    echo "✅ Health check OK"
else
    echo "⚠️  Health check échoué (normal au démarrage)"
fi

# Vérifier les logs récents
echo "📋 Logs récents (5 dernières lignes) :"
docker logs qbittorrent-monitor --tail 5

# Vérifier la configuration
echo "🔧 Configuration réseau :"
docker exec qbittorrent-monitor grep "network:" /config/config.yaml || echo "Configuration non accessible"

# Test de connectivité réseau
echo "🌐 Test de connectivité réseau..."
NETWORK=$(docker inspect qbittorrent-monitor --format '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}}{{end}}')
echo "   Réseau utilisé : $NETWORK"

# Vérifier les montages
echo "📂 Vérification des montages :"
docker exec qbittorrent-monitor ls -la /config/ 2>/dev/null || echo "Répertoire /config non accessible"
docker exec qbittorrent-monitor ls -la /configs/ 2>/dev/null || echo "Répertoire /configs non monté"

echo ""
echo "🎯 Test terminé !"
echo "📊 Pour voir les logs complets : docker logs -f qbittorrent-monitor"
