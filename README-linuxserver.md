# LinuxServer.io QBittorrent Error Monitor

[![GitHub Release](https://img.shields.io/github/release/kesurof/qbittorrent-error-monitor.svg?color=26689A&labelColor=555555&logoColor=ffffff&style=for-the-badge&logo=github)](https://github.com/kesurof/qbittorrent-error-monitor/releases)
[![GitHub Package Repository](https://img.shields.io/static/v1.svg?color=26689A&labelColor=555555&logoColor=ffffff&style=for-the-badge&label=ghcr.io&message=Package)](https://github.com/kesurof/qbittorrent-error-monitor/pkgs/container/qbittorrent-error-monitor)

[QBittorrent Error Monitor](https://github.com/kesurof/qbittorrent-error-monitor) est un outil de surveillance pour détecter et gérer automatiquement les erreurs dans QBittorrent, compatible avec l'écosystème ssdv2.

## Application Setup

L'application se lance automatiquement et surveille QBittorrent selon la configuration dans `/config/config.yaml`.

### Configuration

Le fichier de configuration par défaut sera copié dans `/config/config.yaml` au premier démarrage. Vous pouvez le modifier selon vos besoins.

## Usage

### docker-compose (recommandé, compatible ssdv2)

```yaml
---
services:
  qbittorrent-monitor:
    image: ghcr.io/kesurof/qbittorrent-error-monitor:latest
    container_name: qbittorrent-monitor
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Paris
    volumes:
      - /path/to/config:/config
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - 8080:8080
    restart: unless-stopped
```

### docker cli

```bash
docker run -d \
  --name=qbittorrent-monitor \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/Paris \
  -p 8080:8080 \
  -v /path/to/config:/config \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /etc/localtime:/etc/localtime:ro \
  --restart unless-stopped \
  ghcr.io/kesurof/qbittorrent-error-monitor:latest
```

## Parameters

| Parameter | Function |
| :----: | --- |
| `-p 8080` | Port pour health check (optionnel) |
| `-e PUID=1000` | UserID - voir ci-dessous pour explication |
| `-e PGID=1000` | GroupID - voir ci-dessous pour explication |
| `-e TZ=Europe/Paris` | Fuseau horaire |
| `-v /config` | Contient la configuration et les logs |
| `-v /var/run/docker.sock:ro` | Accès Docker en lecture seule |

## Environment variables from files (Docker secrets)

Vous pouvez définir n'importe quelle variable d'environnement à partir d'un fichier en utilisant le préfixe spécial `FILE__`.

Par exemple :

```bash
-e FILE__MYVAR=/run/secrets/mysecretvariable
```

Définira la variable d'environnement `MYVAR` basée sur le contenu du fichier `/run/secrets/mysecretvariable`.

## User / Group Identifiers

Lors de l'utilisation de volumes (`-v`), des problèmes de permissions peuvent survenir entre l'OS hôte et le conteneur. Nous évitons ce problème en permettant de spécifier l'ID utilisateur `PUID` et l'ID groupe `PGID`.

Assurez-vous que tous les répertoires de volume sur l'hôte appartiennent au même utilisateur que vous spécifiez et que les problèmes disparaîtront.

Dans cet exemple, l'ID de `dockeruser` est `1000` et l'ID de `dockergroup` est `1000`. Pour trouver vos IDs, utilisez `id dockeruser` comme ci-dessous :

```bash
$ id dockeruser
uid=1000(dockeruser) gid=1000(dockergroup) groups=1000(dockergroup)
```

## Compatibility

Cette image est compatible avec Docker et Docker Compose. Utilisez les scripts d'installation fournis pour une configuration rapide.

## Support Info

* Shell access : `docker exec -it qbittorrent-monitor /bin/bash`
* Logs en temps réel : `docker logs -f qbittorrent-monitor`
* Version du conteneur : `docker inspect -f '{{ index .Config.Labels "build_version" }}' qbittorrent-monitor`
