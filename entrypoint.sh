#!/bin/bash
set -e

# Configuration des utilisateurs
export PUID=${PUID:-1000}
export PGID=${PGID:-1000}

echo "🚀 QBittorrent Error Monitor - Démarrage"
echo "📋 PUID: $PUID, PGID: $PGID"

# Créer l'utilisateur/groupe si nécessaire
if ! getent group abc > /dev/null 2>&1; then
    addgroup -g "$PGID" abc
fi

if ! getent passwd abc > /dev/null 2>&1; then
    adduser -u "$PUID" -G abc -s /bin/bash -D abc
fi

# Créer les répertoires nécessaires
mkdir -p /config/logs
mkdir -p /app

# Copier la configuration par défaut si elle n'existe pas
if [ ! -f "/config/config.yaml" ]; then
    echo "📄 Création de la configuration par défaut"
    cp /defaults/config.yaml /config/
fi

# Ajuster les permissions
chown -R abc:abc /config /app
chmod -R 755 /config /app

# Démarrage du service de health check en arrière-plan
(
    while true; do
        echo "OK" | nc -l -p 8080 -q 1 2>/dev/null || true
        sleep 1
    done
) &

# Démarrer l'application principale en tant qu'utilisateur abc
echo "🎯 Lancement de l'application..."
exec su-exec abc python3 /app/qbittorrent-monitor.py "$@"
