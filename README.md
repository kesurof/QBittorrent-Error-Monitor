# QBittorrent Error Monitor pour ssdv2

🚀 **Monitor automatique des erreurs qBittorrent avec intégration Sonarr/Radarr pour environnements ssdv2**

## � **Fonctionnalités**

- 🔍 **Détection automatique** des erreurs qBittorrent
- 🗑️ **Suppression intelligente** des téléchargements échoués
- 🚫 **Blacklist automatique** pour éviter les re-téléchargements
- 🔄 **Déclenchement de nouvelles recherches** Sonarr/Radarr
- 🐳 **Compatible ssdv2** avec Docker
- 📊 **Logs détaillés** et monitoring

## 🐳 **Image Docker**

```yaml
image: 'ghcr.io/kesurof/qbittorrent-error-monitor/qbittorrent-monitor:ssdv2'
```

## 📁 **Installation ssdv2**

### 2. Construction de l'image

```bash
# Cloner le repository
git clone https://github.com/your-repo/QBittorrent-Error-Monitor.git
cd QBittorrent-Error-Monitor

# Construire l'image Docker
docker build -t qbittorrent-error-monitor:latest .
```

### 3. Installation dans ssdv2

Copiez le fichier `qbittorrent-monitor.yml` dans votre répertoire ssdv2 :

```bash
# Exemple de chemin (à adapter selon votre installation)
cp qbittorrent-monitor.yml /opt/seedbox/docker/includes/dockerapps/vars/
```

### 4. Déploiement

Utilisez la commande ssdv2 standard :

```bash
# Via l'interface ssdv2
ansible-playbook /opt/seedbox/includes/dockerapps/qbittorrent-monitor.yml

# Ou directement avec docker-compose si vous avez le docker-compose.yml généré
docker-compose up -d qbittorrent-monitor
```

## 📁 Structure des fichiers

```
/settings/storage/docker/USER/qbittorrent-monitor/
├── config/
│   └── config.yaml     # Configuration auto-générée
└── logs/
    └── qbittorrent-monitor.log
```

## ⚙️ Configuration

Le monitor s'auto-configure au démarrage :
- Détecte automatiquement les conteneurs qBittorrent, Sonarr, Radarr
- Récupère les clés API depuis les fichiers de configuration
- Configure les chemins selon les variables ssdv2

## 🔧 Variables d'environnement

Toutes les variables ssdv2 sont respectées :
- `PUID` / `PGID` : Gestion des permissions
- `TZ` : Timezone
- `CHECK_INTERVAL` : Intervalle de vérification (défaut: 300s)
- `LOG_LEVEL` : Niveau de log (défaut: INFO)

## 📊 Monitoring

```bash
# Logs du conteneur
docker logs qbittorrent-monitor

# Logs de l'application
tail -f /settings/storage/docker/USER/qbittorrent-monitor/logs/qbittorrent-monitor.log

# Status
docker ps | grep qbittorrent-monitor
```

## 🛠️ Personnalisation

Modifiez le fichier `config/config.yaml` dans le volume pour personnaliser :
- Conteneurs surveillés
- Patterns d'erreurs
- Actions automatiques
- Notifications

## 🔒 Sécurité

- Conteneur en mode non-privilégié
- Socket Docker en lecture seule
- Ressources limitées (128MB RAM, 0.25 CPU)
- Aucun port exposé par défaut (optionnel: 8080 pour health check)

## 🆘 Dépannage

### Le conteneur ne démarre pas
```bash
# Vérifier les logs
docker logs qbittorrent-monitor

# Vérifier le réseau
docker network ls | grep traefik_proxy

# Vérifier les permissions
ls -la /settings/storage/docker/USER/qbittorrent-monitor/
```

### Pas de détection des services
```bash
# Vérifier que les conteneurs sont dans le bon réseau
docker inspect sonarr | grep NetworkMode
docker inspect radarr | grep NetworkMode
docker inspect qbittorrent | grep NetworkMode
```

### Erreurs de permissions
```bash
# Vérifier les variables PUID/PGID
docker exec qbittorrent-monitor id

# Si nécessaire, recréer le conteneur
docker-compose restart qbittorrent-monitor
```
