# QBittorrent Error Monitor v2.0
# Image Docker basée sur Python Alpine pour optimiser la taille et la sécurité

FROM python:3.11-alpine

# Métadonnées
LABEL maintainer="QBittorrent Error Monitor Team"
LABEL version="2.0"
LABEL description="Production-ready QBittorrent Error Monitor with enhanced security"

# Variables d'environnement par défaut
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    USER_UID=1000 \
    USER_GID=1000 \
    APP_USER=qbmonitor

# Installation des dépendances système
RUN apk add --no-cache \
    curl \
    bash \
    tzdata \
    docker-cli \
    && rm -rf /var/cache/apk/*

# Création de l'utilisateur non-root pour la sécurité
RUN addgroup -g ${USER_GID} ${APP_USER} && \
    adduser -u ${USER_UID} -G ${APP_USER} -D -s /bin/bash ${APP_USER}

# Répertoires de travail
WORKDIR /app
RUN mkdir -p /app/config /app/logs && \
    chown -R ${APP_USER}:${APP_USER} /app

# Copie des fichiers de requirements en premier (pour le cache Docker)
COPY requirements.txt .

# Installation des dépendances Python
RUN pip install --no-cache-dir -r requirements.txt

# Copie du code source
COPY qbittorrent-monitor.py .
COPY config/ ./config/

# Application des permissions
RUN chmod +x qbittorrent-monitor.py && \
    chown -R ${APP_USER}:${APP_USER} /app

# Basculement vers l'utilisateur non-root
USER ${APP_USER}

# Volumes pour persistance des données
VOLUME ["/app/logs", "/app/config"]

# Port pour health check (optionnel)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD python3 /app/qbittorrent-monitor.py --health-check || exit 1

# Point d'entrée par défaut
ENTRYPOINT ["python3", "/app/qbittorrent-monitor.py"]
CMD ["--config", "/app/config/config.yaml", "--interval", "300"]
