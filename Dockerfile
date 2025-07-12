# QBittorrent Error Monitor
# Image Docker compatible ssdv2

FROM python:3.13-alpine

# Métadonnées
LABEL maintainer="QBittorrent Error Monitor"
LABEL version="2.0"
LABEL description="QBittorrent Error Monitor for ssdv2 environment"

# Variables d'environnement
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PUID=1000 \
    PGID=1000

# Installation des dépendances système
RUN apk add --no-cache \
    curl \
    bash \
    tzdata \
    shadow \
    gosu \
    && rm -rf /var/cache/apk/*

# Création de l'utilisateur par défaut
RUN addgroup -g 1000 abc && \
    adduser -u 1000 -G abc -D -s /bin/bash abc

# Script d'entrée simplifié
COPY --chmod=755 <<EOF /entrypoint.sh
#!/bin/bash
set -e

# Ajustement dynamique des UID/GID pour compatibilité ssdv2
if [ "\$PUID" != "1000" ] || [ "\$PGID" != "1000" ]; then
    echo "Adjusting UID/GID to \$PUID:\$PGID"
    groupmod -o -g "\$PGID" abc 2>/dev/null || true
    usermod -o -u "\$PUID" abc 2>/dev/null || true
fi

# Assurer les permissions sur les répertoires
chown -R abc:abc /app/logs /app/config 2>/dev/null || true

# Exécuter en tant qu'utilisateur abc
exec gosu abc "\$@"
EOF

# Répertoires de travail
WORKDIR /app
RUN mkdir -p /app/config /app/logs

# Copie des fichiers de requirements
COPY requirements.txt .

# Installation des dépendances Python
RUN pip install --no-cache-dir -r requirements.txt

# Copie du code source
COPY qbittorrent-monitor.py .
COPY config/ ./config/

# Permissions par défaut
RUN chmod +x qbittorrent-monitor.py

# Volumes pour les données
VOLUME ["/app/logs", "/app/config"]

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD python3 /app/qbittorrent-monitor.py --health-check || exit 1

# Utilisation de l'entrypoint pour la gestion des permissions
ENTRYPOINT ["/entrypoint.sh"]

# Commande par défaut
CMD ["python3", "/app/qbittorrent-monitor.py", "--config", "/app/config/config.yaml", "--interval", "300"]
