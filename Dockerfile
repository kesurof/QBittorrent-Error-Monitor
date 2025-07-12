# QBittorrent Error Monitor
# Image Docker compatible ssdv2

FROM python:3.11-alpine

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
    && rm -rf /var/cache/apk/*

# Script d'entrée pour gérer les UID/GID dynamiques (compatible ssdv2)
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'groupmod -o -g "$PGID" abc' >> /entrypoint.sh && \
    echo 'usermod -o -u "$PUID" abc' >> /entrypoint.sh && \
    echo 'chown -R abc:abc /app/logs' >> /entrypoint.sh && \
    echo 'exec gosu abc "$@"' >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Installation de gosu pour la gestion des permissions
RUN apk add --no-cache gosu

# Création de l'utilisateur par défaut (sera modifié par l'entrypoint)
RUN addgroup -g 1000 abc && \
    adduser -u 1000 -G abc -D -s /bin/bash abc

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
