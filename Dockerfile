# syntax=docker/dockerfile:1
FROM alpine:3.17

# Set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="QBittorrent Monitor version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="kesurof"

# Install runtime packages
RUN \
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    bash \
    coreutils \
    python3 \
    py3-pip \
    curl \
    grep \
    shadow \
    su-exec \
    netcat-openbsd && \
  echo "**** install pip packages ****" && \
  pip3 install --no-cache-dir \
    requests \
    pyyaml && \
  echo "**** create user and directories ****" && \
  addgroup -g 1000 abc && \
  adduser -u 1000 -G abc -s /bin/bash -D abc && \
  mkdir -p /config /app /defaults && \
  echo "**** cleanup ****" && \
  rm -rf \
    /tmp/* \
    /root/.cache

# Add application files
COPY qbittorrent-monitor.py /app/
COPY config/config.yaml /defaults/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Set permissions
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chown -R abc:abc /app /defaults

# Ports and volumes
EXPOSE 8080
VOLUME /config

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
    CMD nc -z localhost 8080 || exit 1

# Use simple entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

