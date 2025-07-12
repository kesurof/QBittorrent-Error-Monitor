# QBittorrent Error Monitor

🚀 **Monitor automatique des erreurs qBittorrent avec intégration Sonarr/Radarr**

[![GitHub Actions](https://github.com/kesurof/QBittorrent-Error-Monitor/actions/workflows/docker.yml/badge.svg)](https://github.com/kesurof/QBittorrent-Error-Monitor/actions)
[![GitHub Container Registry](https://ghcr.io/kesurof/qbittorrent-error-monitor/qbittorrent-monitor)](https://github.com/kesurof/QBittorrent-Error-Monitor/pkgs/container/qbittorrent-error-monitor%2Fqbittorrent-monitor)

## 🎯 **Fonctionnalités principales**

### 🔍 **Monitoring intelligent**
- **Détection automatique** des erreurs qBittorrent en temps réel
- **Surveillance continue** des logs et états des torrents
- **Patterns d'erreur configurables** (timeout, DNS, tracker, ratio...)
- **Auto-découverte** des conteneurs qBittorrent, Sonarr, Radarr

### 🛠️ **Actions automatiques**
- **Suppression intelligente** des téléchargements échoués
- **Blacklist automatique** pour éviter les re-téléchargements
- **Déclenchement immédiat** de nouvelles recherches Sonarr/Radarr
- **Notifications** optionnelles (logs détaillés)

### 🐳 **Intégration Docker**
- **Image pré-construite** sur GitHub Container Registry
- **Auto-configuration** complète au démarrage
- **Permissions** PUID/PGID configurables
- **Health check** intégré (port 8080)
- **Multi-architecture** : AMD64, ARM64, ARM v7

### 📊 **Monitoring et debug**
- **Logs structurés** avec niveaux configurables
- **Métriques de performance** 
- **Mode test** et **dry-run** pour validation
- **Interface health check** pour supervision

## 🐳 **Image Docker**

```yaml
> 💡 **Aucune construction locale nécessaire !** L'image est automatiquement disponible sur GitHub Container Registry.

## 📁 **Installation**

### **🚀 Installation rapide (recommandée)**

```bash
# Installation interactive avec choix du réseau
curl -sSL https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/install.sh | bash
```

### **⚙️ Installation avancée (configuration complète)**

```bash
# Installation avec toutes les options (réseau, conteneurs, chemins)
curl -sSL https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/install-advanced.sh | bash
```

### **🔧 Installation Docker Compose**

```bash
# Installation avec Docker Compose et fichier .env
curl -sSL https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/install-manual.sh | bash
```

### **📋 Choix du réseau Docker**

Lors de l'installation, vous pourrez choisir le réseau Docker :

- **bridge** (défaut Docker) - Pour usage basique
- **traefik_proxy** - Pour intégration Traefik 
- **docker_default** - Pour stack Docker Compose
- **Personnalisé** - Votre réseau spécifique

> 💡 **Important** : Choisissez le même réseau que vos conteneurs Sonarr/Radarr/qBittorrent pour qu'ils puissent communiquer.

### **⚙️ Installation manuelle**

```bash
# Créer les répertoires
mkdir -p ~/qbittorrent-monitor/{config,logs}

# Télécharger la configuration
curl -sSL -o ~/qbittorrent-monitor/config/config.yaml \
    https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/config/config.yaml

# Démarrer le conteneur
docker run -d \
  --name qbittorrent-monitor \
  --restart unless-stopped \
  -e PUID=$(id -u) \
  -e PGID=$(id -g) \
  -e TZ=Europe/Paris \
  -v ~/qbittorrent-monitor/config:/app/config:rw \
  -v ~/qbittorrent-monitor/logs:/app/logs:rw \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -p 8080:8080 \
  ghcr.io/kesurof/qbittorrent-error-monitor/qbittorrent-monitor:latest
```

## 🔄 **Flux simplifié**

```mermaid
graph LR
    A[Push Code] --> B[GitHub Actions]
    B --> C[Image GHCR]
    C --> D[Script install.sh]
    D --> E[Conteneur démarré]
```

1. **Push code** → GitHub Actions build l'image
2. **Image disponible** sur GHCR  
3. **Utilisateur** exécute le script d'installation
4. **Conteneur** démarré automatiquement
5. **Application** s'auto-configure au démarrage

## ⚙️ **Configuration**

### **Variables d'environnement**

```bash
# Variables principales
PUID=1000                    # ID utilisateur
PGID=1000                    # ID groupe  
TZ=Europe/Paris              # Fuseau horaire

# Configuration application
CHECK_INTERVAL=300           # Intervalle vérification (sec)
LOG_LEVEL=INFO              # DEBUG|INFO|WARNING|ERROR
DRY_RUN=false               # Mode simulation
HTTP_PORT=8080              # Port health check
```

### **Personnalisation des patterns d'erreur**

```yaml
# Éditez config/config.yaml après le premier démarrage
error_patterns:
  connection_errors:
    - "Connection timed out"
    - "No such host is known"
    - "Name resolution failed"
  
  tracker_errors:
    - "Tracker error"
    - "Announce failed"
    - "Unregistered torrent"
  
  file_errors:
    - "No space left on device"
    - "Permission denied"
    - "Disk full"
```

## 📂 **Structure des fichiers**

```bash
# Structure automatiquement créée
~/qbittorrent-monitor/
├── config/
│   └── config.yaml              # Configuration principal
└── logs/
    └── qbittorrent-monitor.log  # Logs application
```

## 🔧 **Commandes utiles**

### **Monitoring en temps réel**

```bash
# Logs du conteneur
docker logs -f qbittorrent-monitor

# Logs de l'application
tail -f ~/qbittorrent-monitor/logs/qbittorrent-monitor.log

# Status du conteneur
docker ps | grep qbittorrent-monitor
```

### **Tests et debug**

```bash
# Test de configuration
docker exec qbittorrent-monitor python3 /app/qbittorrent-monitor.py --health-check

# Mode test (un cycle seulement)
docker exec qbittorrent-monitor python3 /app/qbittorrent-monitor.py --test

# Mode dry-run (simulation)
docker exec qbittorrent-monitor python3 /app/qbittorrent-monitor.py --dry-run --test
```

### **Gestion du service**

```bash
# Redémarrage
docker restart qbittorrent-monitor

# Arrêt
docker stop qbittorrent-monitor

# Suppression
docker rm qbittorrent-monitor

# Vérification health check
curl -f http://localhost:8080/health || echo "Service KO"
```

## 🔧 **En cas de problèmes**

### **Erreur "exec: '/init': no such file or directory"**

Si vous rencontrez cette erreur, utilisez le script d'installation corrigé :

```bash
# Script d'installation corrigé
curl -sSL https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/install-fixed.sh | bash
```

### **Erreurs "ansible-playbook not found"**

Ces erreurs proviennent d'anciens scripts. Ignorez-les ou nettoyez votre installation :

```bash
# Nettoyer l'ancienne installation
docker stop qbittorrent-monitor 2>/dev/null || true
docker rm qbittorrent-monitor 2>/dev/null || true

# Réinstaller proprement
curl -sSL https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/install-fixed.sh | bash
```

## 📁 **Installation**

### **🚀 Installation rapide (recommandée)**

```bash
# Installation en une commande
curl -sSL https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/install.sh | bash
```

### **🔧 Installation Docker Compose**

```bash
# Installation avec Docker Compose
curl -sSL https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/install-manual.sh | bash
```

### **⚙️ Installation manuelle**

```bash
# Créer les répertoires
mkdir -p ~/qbittorrent-monitor/{config,logs}

# Télécharger la configuration
curl -sSL -o ~/qbittorrent-monitor/config/config.yaml \
    https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/config/config.yaml

# Démarrer le conteneur
docker run -d \
  --name qbittorrent-monitor \
  --restart unless-stopped \
  -e PUID=$(id -u) \
  -e PGID=$(id -g) \
  -e TZ=Europe/Paris \
  -v ~/qbittorrent-monitor/config:/app/config:rw \
  -v ~/qbittorrent-monitor/logs:/app/logs:rw \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -p 8080:8080 \
  ghcr.io/kesurof/qbittorrent-error-monitor/qbittorrent-monitor:latest
```

## 🔄 **Flux simplifié**

```mermaid
graph LR
    A[Push Code] --> B[GitHub Actions]
    B --> C[Image GHCR]
    C --> D[Script install.sh]
    D --> E[Conteneur démarré]
```

1. **Push code** → GitHub Actions build l'image
2. **Image disponible** sur GHCR  
3. **Utilisateur** exécute le script d'installation
4. **Conteneur** démarré automatiquement
5. **Application** s'auto-configure au démarrage

## ⚙️ **Configuration**

### **Variables d'environnement**

```bash
# Variables principales
PUID=1000                    # ID utilisateur
PGID=1000                    # ID groupe  
TZ=Europe/Paris              # Fuseau horaire

# Configuration application
CHECK_INTERVAL=300           # Intervalle vérification (sec)
LOG_LEVEL=INFO              # DEBUG|INFO|WARNING|ERROR
DRY_RUN=false               # Mode simulation
HTTP_PORT=8080              # Port health check
```

### **Personnalisation des patterns d'erreur**

```yaml
# Éditez config/config.yaml après le premier démarrage
error_patterns:
  connection_errors:
    - "Connection timed out"
    - "No such host is known"
    - "Name resolution failed"
  
  tracker_errors:
    - "Tracker error"
    - "Announce failed"
    - "Unregistered torrent"
  
  file_errors:
    - "No space left on device"
    - "Permission denied"
    - "Disk full"
```

## 📂 **Structure des fichiers**

```bash
# Structure automatiquement créée
~/qbittorrent-monitor/
├── config/
│   └── config.yaml              # Configuration principal
└── logs/
    └── qbittorrent-monitor.log  # Logs application
```

## 🔧 **Commandes utiles**

### **Monitoring en temps réel**

```bash
# Logs du conteneur
docker logs -f qbittorrent-monitor

# Logs de l'application
tail -f ~/qbittorrent-monitor/logs/qbittorrent-monitor.log

# Status du conteneur
docker ps | grep qbittorrent-monitor
```

### **Tests et debug**

```bash
# Test de configuration
docker exec qbittorrent-monitor python3 /app/qbittorrent-monitor.py --health-check

# Mode test (un cycle seulement)
docker exec qbittorrent-monitor python3 /app/qbittorrent-monitor.py --test

# Mode dry-run (simulation)
docker exec qbittorrent-monitor python3 /app/qbittorrent-monitor.py --dry-run --test
```

### **Gestion du service**

```bash
# Redémarrage
docker restart qbittorrent-monitor

# Arrêt
docker stop qbittorrent-monitor

# Suppression
docker rm qbittorrent-monitor

# Vérification health check
curl -f http://localhost:8080/health || echo "Service KO"
```

## 🔧 **En cas de problèmes**

### **Erreur "exec: '/init': no such file or directory"**

Si vous rencontrez cette erreur, utilisez le script d'installation corrigé :

```bash
# Script d'installation corrigé
curl -sSL https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/install-fixed.sh | bash
```

### **Erreurs "ansible-playbook not found"**

Ces erreurs proviennent d'anciens scripts. Ignorez-les ou nettoyez votre installation :

```bash
# Nettoyer l'ancienne installation
docker stop qbittorrent-monitor 2>/dev/null || true
docker rm qbittorrent-monitor 2>/dev/null || true

# Réinstaller proprement
curl -sSL https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/install-fixed.sh | bash
```

## 📁 **Installation**

### **🚀 Installation rapide (recommandée)**

```bash
# Installation en une commande
curl -sSL https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/install.sh | bash
```

### **🔧 Installation Docker Compose**

```bash
# Installation avec Docker Compose
curl -sSL https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/install-manual.sh | bash
```

### **⚙️ Installation manuelle**

```bash
# Créer les répertoires
mkdir -p ~/qbittorrent-monitor/{config,logs}

# Télécharger la configuration
curl -sSL -o ~/qbittorrent-monitor/config/config.yaml \
    https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/config/config.yaml

# Démarrer le conteneur
docker run -d \
  --name qbittorrent-monitor \
  --restart unless-stopped \
  -e PUID=$(id -u) \
  -e PGID=$(id -g) \
  -e TZ=Europe/Paris \
  -v ~/qbittorrent-monitor/config:/app/config:rw \
  -v ~/qbittorrent-monitor/logs:/app/logs:rw \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -p 8080:8080 \
  ghcr.io/kesurof/qbittorrent-error-monitor/qbittorrent-monitor:latest
```

## 🔄 **Flux simplifié**

```mermaid
graph LR
    A[Push Code] --> B[GitHub Actions]
    B --> C[Image GHCR]
    C --> D[Script install.sh]
    D --> E[Conteneur démarré]
```

1. **Push code** → GitHub Actions build l'image
2. **Image disponible** sur GHCR  
3. **Utilisateur** exécute le script d'installation
4. **Conteneur** démarré automatiquement
5. **Application** s'auto-configure au démarrage

## ⚙️ **Configuration**

### **Variables d'environnement**

```bash
# Variables principales
PUID=1000                    # ID utilisateur
PGID=1000                    # ID groupe  
TZ=Europe/Paris              # Fuseau horaire

# Configuration application
CHECK_INTERVAL=300           # Intervalle vérification (sec)
LOG_LEVEL=INFO              # DEBUG|INFO|WARNING|ERROR
DRY_RUN=false               # Mode simulation
HTTP_PORT=8080              # Port health check
```

### **Personnalisation des patterns d'erreur**

```yaml
# Éditez config/config.yaml après le premier démarrage
error_patterns:
  connection_errors:
    - "Connection timed out"
    - "No such host is known"
    - "Name resolution failed"
  
  tracker_errors:
    - "Tracker error"
    - "Announce failed"
    - "Unregistered torrent"
  
  file_errors:
    - "No space left on device"
    - "Permission denied"
    - "Disk full"
```

## 📂 **Structure des fichiers**

```bash
# Structure automatiquement créée
~/qbittorrent-monitor/
├── config/
│   └── config.yaml              # Configuration principal
└── logs/
    └── qbittorrent-monitor.log  # Logs application
```

## 🔧 **Commandes utiles**

### **Monitoring en temps réel**

```bash
# Logs du conteneur
docker logs -f qbittorrent-monitor

# Logs de l'application
tail -f ~/qbittorrent-monitor/logs/qbittorrent-monitor.log

# Status du conteneur
docker ps | grep qbittorrent-monitor
```

### **Tests et debug**

```bash
# Test de configuration
docker exec qbittorrent-monitor python3 /app/qbittorrent-monitor.py --health-check

# Mode test (un cycle seulement)
docker exec qbittorrent-monitor python3 /app/qbittorrent-monitor.py --test

# Mode dry-run (simulation)
docker exec qbittorrent-monitor python3 /app/qbittorrent-monitor.py --dry-run --test
```

### **Gestion du service**

```bash
# Redémarrage
docker restart qbittorrent-monitor

# Arrêt
docker stop qbittorrent-monitor

# Suppression
docker rm qbittorrent-monitor

# Vérification health check
curl -f http://localhost:8080/health || echo "Service KO"
```

## 🏗️ **Architecture & Développement**

### **🔄 CI/CD Pipeline**
- **GitHub Actions** : Build automatique multi-architecture à chaque push
- **GitHub Container Registry** : Stockage et distribution des images
- **Multi-arch** : Support AMD64, ARM64, ARM v7
- **Tags** : `latest`, version git SHA

### **🛠️ Scripts et fichiers**

| Fichier | Usage | Description |
|---------|-------|-------------|
| `install.sh` | **✅ RECOMMANDÉ** | Installation rapide avec Docker |
| `install-manual.sh` | **🔧 Docker Compose** | Installation avec docker-compose |
| `docker-compose.yml` | **📄 Compose** | Fichier compose pour installation manuelle |
| `deploy-ghcr.sh` | **🔧 Développement** | Build manuel si GitHub Actions indisponible |
| `.github/workflows/docker.yml` | **🤖 CI/CD** | Pipeline automatique |

> **💡 Principe** : Image Docker pré-construite → Script d'installation → Auto-configuration

## 🔗 **Ressources et liens**

-  [qBittorrent WebUI API](https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API)
- 📡 [Sonarr API Documentation](https://sonarr.tv/docs/api/)
- 🎬 [Radarr API Documentation](https://radarr.video/docs/api/)
- 🐳 [GitHub Container Registry](https://github.com/kesurof/QBittorrent-Error-Monitor/pkgs/container/qbittorrent-error-monitor%2Fqbittorrent-monitor)

## 📄 **Licence**

MIT License - Voir le fichier [LICENSE](LICENSE)

---

**🎯 Solution Docker simple et efficace • 🐳 Image pré-construite • 🤖 CI/CD GitHub Actions**
