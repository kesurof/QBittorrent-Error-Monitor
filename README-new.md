# QBittorrent Error Monitor pour ssdv2

🚀 **Monitor automatique des erreurs qBittorrent avec intégration Sonarr/Radarr pour environnements ssdv2**

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

### 🐳 **Intégration ssdv2**
- **Compatible natif** avec l'environnement ssdv2
- **Auto-configuration** complète au démarrage
- **Respect des permissions** PUID/PGID
- **Réseau traefik_proxy** intégré
- **Health check** intégré (port 8080)

### 📊 **Monitoring et debug**
- **Logs structurés** avec niveaux configurables
- **Métriques de performance** 
- **Mode test** et **dry-run** pour validation
- **Interface health check** pour supervision

## 🐳 **Image Docker**

```yaml
# Image multi-architecture (AMD64, ARM64, ARM v7)
image: 'ghcr.io/kesurof/qbittorrent-error-monitor/qbittorrent-monitor:ssdv2'
```

## 📁 **Installation ssdv2**

### **Étape 1 : Téléchargement du fichier de configuration**

```bash
# Télécharger le fichier ssdv2
wget -O qbittorrent-monitor.yml https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/qbittorrent-monitor.yml

# Ou cloner le repository complet
git clone https://github.com/kesurof/QBittorrent-Error-Monitor.git
```

### **Étape 2 : Integration dans ssdv2**

```bash
# Copier dans le répertoire ssdv2 (adapter le chemin)
cp qbittorrent-monitor.yml /opt/seedbox/docker/includes/dockerapps/vars/

# Ou pour Saltbox
cp qbittorrent-monitor.yml ~/ssdv2/roles/ansible/
```

### **Étape 3 : Déploiement**

```bash
# Via ssdv2/Saltbox
cd ~/ssdv2
sudo ansible-playbook -i inventory.yml playbook.yml --tags qbittorrent-monitor

# Ou via interface ssdv2 web si disponible
```

## ⚙️ **Configuration avancée**

### **Variables d'environnement**

```yaml
pg_env:
  # Permissions système
  PUID: "{{ lookup('env','MYUID') }}"        # ID utilisateur
  PGID: "{{ lookup('env','MYGID') }}"        # ID groupe
  TZ: 'Europe/Paris'                         # Fuseau horaire
  
  # Configuration monitoring
  CHECK_INTERVAL: '300'                      # Intervalle vérification (sec)
  LOG_LEVEL: 'INFO'                          # DEBUG|INFO|WARNING|ERROR
  DRY_RUN: 'false'                          # Mode simulation
  
  # Réseau Docker
  DOCKER_NETWORK: 'traefik_proxy'           # Réseau Docker
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
/settings/storage/docker/USER/qbittorrent-monitor/
├── config/
│   ├── config.yaml              # Configuration principal
│   └── discovered_services.json # Services auto-découverts
└── logs/
    ├── qbittorrent-monitor.log  # Logs application
    └── health.log               # Logs health check
```

## 🔧 **Commandes utiles**

### **Monitoring en temps réel**

```bash
# Logs du conteneur
docker logs -f qbittorrent-monitor

# Logs de l'application
tail -f /settings/storage/docker/USER/qbittorrent-monitor/logs/qbittorrent-monitor.log

# Status détaillé
docker inspect qbittorrent-monitor | grep -A 10 "Health"
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

# Reconfiguration
docker exec qbittorrent-monitor python3 /app/qbittorrent-monitor.py --config /app/config/config.yaml

# Vérification health check
curl -f http://localhost:8080/health || echo "Service KO"
```

## 🛠️ **Patterns d'erreur détectés**

| Catégorie | Patterns détectés | Action |
|-----------|------------------|---------|
| **Réseau** | Connection timeout, DNS failed, No route to host | Suppression + Blacklist + Recherche |
| **Tracker** | Unregistered, Announce failed, Tracker error | Blacklist + Recherche |
| **Fichier** | No space left, Permission denied, Disk full | Suppression + Alerte |
| **Ratio** | Ratio limit reached, Upload limit | Suppression + Recherche |
| **Autorisation** | Unauthorized, Invalid passkey | Blacklist |

## 🔒 **Sécurité et performances**

### **Sécurité**
- ✅ Conteneur **non-privilégié**
- ✅ Socket Docker en **lecture seule**
- ✅ Pas de ports exposés (8080 optionnel pour health check)
- ✅ Utilisateur non-root à l'exécution
- ✅ Isolation réseau complète

### **Performances**
- 🚀 **Ressources limitées** : 128MB RAM, 0.25 CPU
- 🚀 **Efficacité** : Vérification toutes les 5 minutes par défaut
- 🚀 **Cache intelligent** : Évite les requêtes redondantes
- 🚀 **Multi-architecture** : AMD64, ARM64, ARM v7

## 🆘 **Guide de dépannage**

### **❌ Le conteneur ne démarre pas**

```bash
# 1. Vérifier les logs de démarrage
docker logs qbittorrent-monitor

# 2. Vérifier le réseau traefik_proxy
docker network ls | grep traefik_proxy

# 3. Vérifier les permissions du volume
ls -la /settings/storage/docker/USER/qbittorrent-monitor/

# 4. Recréer le conteneur
docker-compose down qbittorrent-monitor
docker-compose up -d qbittorrent-monitor
```

### **❌ Services non détectés**

```bash
# 1. Vérifier que tous les conteneurs sont dans traefik_proxy
docker inspect sonarr radarr qbittorrent | grep NetworkMode

# 2. Tester la connectivité réseau
docker exec qbittorrent-monitor ping sonarr
docker exec qbittorrent-monitor ping radarr
docker exec qbittorrent-monitor ping qbittorrent

# 3. Vérifier les fichiers de configuration
docker exec qbittorrent-monitor ls -la /configs/*/config.xml
```

### **❌ Pas d'actions automatiques**

```bash
# 1. Vérifier le mode dry-run
docker exec qbittorrent-monitor env | grep DRY_RUN

# 2. Tester en mode verbose
docker exec qbittorrent-monitor python3 /app/qbittorrent-monitor.py --verbose --test

# 3. Vérifier les API keys
docker exec qbittorrent-monitor python3 /app/qbittorrent-monitor.py --health-check
```

### **❌ Erreurs de permissions**

```bash
# 1. Vérifier PUID/PGID
docker exec qbittorrent-monitor id

# 2. Comparer avec l'utilisateur propriétaire des fichiers
ls -la /settings/storage/docker/USER/

# 3. Corriger les permissions si nécessaire
sudo chown -R $MYUID:$MYGID /settings/storage/docker/USER/qbittorrent-monitor/
```

## 📈 **Métriques et monitoring**

### **Health check**
```bash
# Test de santé via HTTP
curl http://localhost:8080/health

# Réponse attendue
{"status": "healthy", "services": {"qbittorrent": true, "sonarr": true, "radarr": true}}
```

### **Métriques de performance**
- **Temps de réponse** des APIs surveillées
- **Nombre d'erreurs** détectées par heure
- **Actions automatiques** effectuées
- **Utilisation ressources** du conteneur

## 🔗 **Ressources et liens**

- 📚 [Documentation ssdv2](https://github.com/saltyorg/Saltbox)
- 🔧 [qBittorrent WebUI API](https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API)
- 📡 [Sonarr API Documentation](https://sonarr.tv/docs/api/)
- 🎬 [Radarr API Documentation](https://radarr.video/docs/api/)
- 🐳 [GitHub Container Registry](https://github.com/kesurof/QBittorrent-Error-Monitor/pkgs/container/qbittorrent-error-monitor%2Fqbittorrent-monitor)

## 📄 **Licence**

MIT License - Voir le fichier [LICENSE](LICENSE)

---

**🎯 Spécialement optimisé pour ssdv2 • 🐳 Docker natif • 🤖 CI/CD GitHub Actions**
