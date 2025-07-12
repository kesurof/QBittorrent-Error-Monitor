# QBittorrent Error Monitor - Guide Docker 🐳

## 🚀 Installation Rapide Docker

### Option 1 : Installation Automatique (Recommandée)

```bash
# Cloner le repository
git clone https://github.com/kesurof/QBittorrent-Error-Monitor.git
cd QBittorrent-Error-Monitor

# Installation interactive avec détection automatique
chmod +x docker-deploy.sh
./docker-deploy.sh setup
```

### Option 2 : Installation Manuelle

```bash
# 1. Cloner et préparer
git clone https://github.com/kesurof/QBittorrent-Error-Monitor.git
cd QBittorrent-Error-Monitor

# 2. Personnaliser docker-compose.yml selon votre environnement
nano docker-compose.yml

# 3. Construire et démarrer
docker-compose up -d

# 4. Vérifier le fonctionnement
docker-compose logs -f
```

## ⚙️ Configuration

### Variables d'Environnement

| Variable | Défaut | Description |
|----------|--------|-------------|
| `CHECK_INTERVAL` | 300 | Intervalle de vérification (secondes) |
| `LOG_LEVEL` | INFO | Niveau de logs (DEBUG, INFO, WARNING, ERROR) |
| `DOCKER_NETWORK` | traefik_proxy | Réseau Docker des conteneurs |
| `DRY_RUN` | false | Mode simulation (true/false) |
| `TZ` | Europe/Paris | Timezone |

### Volumes Requis

```yaml
volumes:
  # Logs persistants
  - ./logs:/app/logs
  
  # Configuration (lecture seule)
  - ./config:/app/config:ro
  
  # Socket Docker pour accès aux conteneurs
  - /var/run/docker.sock:/var/run/docker.sock:ro
  
  # Configurations Sonarr/Radarr (à adapter)
  - /home/user/.config:/configs:ro
```

### Réseau Docker

Le conteneur doit être sur le même réseau que Sonarr/Radarr :

```yaml
networks:
  - votre_reseau_docker  # traefik_proxy, bridge, etc.
```

## 🔧 Commandes Utiles

### Script docker-deploy.sh

```bash
# Configuration interactive
./docker-deploy.sh setup

# Construction de l'image
./docker-deploy.sh build

# Démarrage
./docker-deploy.sh start

# Arrêt
./docker-deploy.sh stop

# Redémarrage
./docker-deploy.sh restart

# Logs en temps réel
./docker-deploy.sh logs

# Statut et métriques
./docker-deploy.sh status

# Test de fonctionnement
./docker-deploy.sh test

# Shell dans le conteneur
./docker-deploy.sh shell
```

### Commandes Docker Classiques

```bash
# Logs du conteneur
docker-compose logs -f qbittorrent-monitor

# Health check
docker exec qbittorrent-error-monitor python3 /app/qbittorrent-monitor.py --health-check

# Test dry-run
docker exec qbittorrent-error-monitor python3 /app/qbittorrent-monitor.py --test --dry-run

# Statistiques de ressources
docker stats qbittorrent-error-monitor

# Shell interactif
docker exec -it qbittorrent-error-monitor /bin/bash
```

## 🚨 Dépannage Docker

### Problème : Conteneur ne démarre pas

```bash
# Vérifier les logs de démarrage
docker-compose logs qbittorrent-monitor

# Vérifier l'image
docker images | grep qbittorrent

# Reconstruire l'image
docker-compose build --no-cache
```

### Problème : Accès aux configurations

```bash
# Vérifier les volumes montés
docker inspect qbittorrent-error-monitor | grep -A 10 "Mounts"

# Tester l'accès aux fichiers
docker exec qbittorrent-error-monitor ls -la /configs

# Vérifier les permissions
docker exec qbittorrent-error-monitor find /configs -name "config.xml"
```

### Problème : Réseau Docker

```bash
# Lister les réseaux
docker network ls

# Inspecter le réseau
docker network inspect traefik_proxy

# Vérifier la connectivité
docker exec qbittorrent-error-monitor ping sonarr
docker exec qbittorrent-error-monitor ping radarr
```

### Problème : Socket Docker

```bash
# Vérifier l'accès au socket Docker
docker exec qbittorrent-error-monitor docker ps

# Permissions du socket (sur l'hôte)
ls -la /var/run/docker.sock
sudo chmod 666 /var/run/docker.sock  # Si nécessaire
```

## 📊 Monitoring

### Health Check

Le conteneur inclut un health check automatique :

```bash
# Statut health check
docker inspect qbittorrent-error-monitor | grep -A 5 "Health"

# Health check manuel
docker exec qbittorrent-error-monitor python3 /app/qbittorrent-monitor.py --health-check
```

### Métriques

```bash
# Utilisation des ressources
docker stats qbittorrent-error-monitor --no-stream

# Logs applicatifs
docker exec qbittorrent-error-monitor tail -f /app/logs/qbittorrent-error-monitor.log

# Statistiques JSON
docker exec qbittorrent-error-monitor cat /app/logs/qbittorrent-stats.json | jq .
```

## 🔄 Mise à Jour

```bash
# Arrêter le conteneur
docker-compose down

# Mettre à jour le code
git pull origin main

# Reconstruire et redémarrer
docker-compose up -d --build

# Vérifier la nouvelle version
docker exec qbittorrent-error-monitor python3 /app/qbittorrent-monitor.py --version
```

## 🔧 Configuration Personnalisée

### Modifier config.yaml

```bash
# Éditer la configuration
nano config/config.yaml

# Redémarrer pour appliquer
docker-compose restart
```

### Variables d'environnement personnalisées

```bash
# Modifier docker-compose.yml
nano docker-compose.yml

# Ou créer un fichier .env
cat > .env << EOF
CHECK_INTERVAL=180
LOG_LEVEL=DEBUG
DRY_RUN=false
TZ=Europe/Paris
EOF
```

## 🚀 Avantages de l'Installation Docker

✅ **Isolation complète** - Pas d'impact sur votre système  
✅ **Gestion des dépendances** - Tout est inclus dans l'image  
✅ **Portabilité** - Fonctionne sur tout système avec Docker  
✅ **Mise à jour facile** - Rebuild et redémarrage simple  
✅ **Monitoring intégré** - Health checks automatiques  
✅ **Sécurité** - Utilisateur non-root, sandbox complet  
✅ **Ressources limitées** - Protection contre la surcharge  

---

**🎉 Votre QBittorrent Error Monitor v2.0 Docker est prêt !**
