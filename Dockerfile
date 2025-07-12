# syntax=docker/dockerfile:1
FROM ghcr.io/linuxserver/baseimage-alpine:3.22

# Set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="kesurof"

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN \
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    python3 \
    py3-pip \
    py3-yaml \
    curl && \
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

# Ports and volumes
EXPOSE 8080
VOLUME /config

