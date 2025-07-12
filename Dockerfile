# syntax=docker/dockerfile:1
FROM alpine:3.20

# Install s6-overlay
ARG S6_OVERLAY_VERSION="3.2.0.0"
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz

# Set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="kesurof"

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0" \
    S6_VERBOSITY=1 \
    PUID=911 \
    PGID=911

# Create abc user
RUN addgroup -g 911 abc && \
    adduser -u 911 -G abc -D -s /bin/bash abc

RUN \
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    bash \
    python3 \
    py3-pip \
    py3-yaml \
    curl \
    shadow && \
  echo "**** install pip packages ****" && \
  pip3 install --no-cache-dir --break-system-packages \
    requests \
    pyyaml && \
  echo "**** cleanup ****" && \
  rm -rf \
    /tmp/* \
    /root/.cache

# Copy local files
COPY root/ /

# Add application files
COPY qbittorrent-monitor.py /app/
COPY config/config.yaml /defaults/

# Create directories and set permissions
RUN mkdir -p /config /app && \
    chown -R abc:abc /app /config /defaults

# Ports and volumes
EXPOSE 8080
VOLUME /config

ENTRYPOINT ["/init"]

