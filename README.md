# QBittorrent Error Monitor

**Monitoring automatique et correction des erreurs qBittorrent pour Sonarr/Radarr**


- **Détection automatique** des erreurs "qBittorrent is reporting an error"
- **Suppression automatique** des téléchargements problématiques
- **Ajout à la blocklist** pour éviter les re-téléchargements
- **Lancement automatique** de recherches de remplacement
- **Service systemd** optimisé avec restart rapide 


## 🚀 Installation Rapide

### Installation en Une Commande ⭐

```bash
curl -s https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/setup.sh | bash
```

**Cette commande unique :**
- Télécharge automatiquement tous les fichiers nécessaires
- Détecte votre configuration existante (chemins Sonarr/Radarr)
- Configure le script pour votre utilisateur
- Installe le service systemd
- Démarre le monitoring automatiquement

### Installation pour un Utilisateur Spécifique

```bash
curl -s https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/setup.sh | bash -s -- nom_utilisateur
```

### Installation Manuelle (Alternative)

```bash
git clone https://github.com/kesurof/QBittorrent-Error-Monitor.git
cd QBittorrent-Error-Monitor
chmod +x setup.sh
./setup.sh
```


# Vérifier les permissions
```bash
ls -la ~/scripts/qbittorrent-monitor/
ls -la ~/logs/
```

# Corriger les permissions si nécessaire
```bash
sudo chown -R $(whoami):$(whoami) ~/scripts/qbittorrent-monitor
sudo chown -R $(whoami):$(whoami) ~/logs
```

### Tests de Connectivité

```bash
# Récupérer manuellement les IPs des containers
SONARR_IP=$(docker inspect sonarr --format='{{.NetworkSettings.Networks.traefik_proxy.IPAddress}}')
RADARR_IP=$(docker inspect radarr --format='{{.NetworkSettings.Networks.traefik_proxy.IPAddress}}')

echo "Sonarr IP: $SONARR_IP"
echo "Radarr IP: $RADARR_IP"

# Test de connectivité (remplacer API_KEY par votre clé)
curl -H "X-Api-Key: VOTRE_API_KEY" http://$SONARR_IP:8989/api/v3/system/status
curl -H "X-Api-Key: VOTRE_API_KEY" http://$RADARR_IP:7878/api/v3/system/status
```

### Problèmes de Performance

```bash
# Vérifier l'utilisation des ressources
systemd-cgtop -p

# Analyser les temps de réponse
python3 -c "
import time
import requests
start = time.time()
session = requests.Session()
print(f'Temps d\'initialisation: {time.time() - start:.2f}s')
"

# Test de charge réseau
ping -c 4 $(docker inspect sonarr --format='{{.NetworkSettings.IPAddress}}')
```

## 🔧 Mode Debug

### Activation du Mode Verbose

```bash
# Test avec logs détaillés
python3 ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py --verbose --interval 60

# Test d'un seul cycle
python3 ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py --test --verbose
```

### Configuration Debug Permanente

```bash
# Modifier le service pour mode debug
sudo systemctl edit qbittorrent-monitor
```

Ajouter :

```ini
[Service]
Environment=LOG_LEVEL=DEBUG
ExecStart=
ExecStart=/usr/bin/python3 /home/VOTRE_USER/scripts/qbittorrent-monitor/qbittorrent-monitor.py --verbose --interval 300
```

### Diagnostic Avancé

```bash
# Vérifier la structure des données API
curl -H "X-Api-Key: VOTRE_API_KEY" http://IP_SONARR:8989/api/v3/queue | jq '.[0]'

# Rechercher des erreurs spécifiques
curl -H "X-Api-Key: VOTRE_API_KEY" http://IP_SONARR:8989/api/v3/queue | jq '.[] | select(.statusMessages != null)'

# Analyser l'historique
curl -H "X-Api-Key: VOTRE_API_KEY" http://IP_SONARR:8989/api/v3/history | jq '.[] | select(.eventType == "downloadFailed")'
```

## 📈 Performances

- **Temps de démarrage** : < 5 secondes
- **Temps d'arrêt** : < 10 secondes
- **Consommation RAM** : < 64M
- **CPU** : < 5% en moyenne
- **Détection** : ~30 secondes après l'erreur

## 🔐 Sécurité

- **Utilisateur dédié** : Pas d'exécution root
- **Permissions minimales** : Accès limité aux ressources
- **Isolation** : Conteneurisation des données
- **Timeouts** : Protection contre les blocages

## 📝 Structure des Logs

### Fichiers de Logs

| Fichier | Description | Emplacement |
|---------|-------------|-------------|
| `qbittorrent-error-monitor.log` | Logs applicatifs | `~/logs/` |
| `qbittorrent-stats.json` | Statistiques JSON | `~/logs/` |
| Journal systemd | Logs système | `journalctl -u qbittorrent-monitor` |

### Format des Statistiques JSON

```json
{
  "cycles": 150,
  "errors_detected": 5,
  "downloads_removed": 5,
  "searches_triggered": 5,
  "start_time": "2025-07-12T10:00:00",
  "last_check": "2025-07-12T12:00:00"
}
```

## 🔄 Mise à Jour

### Mise à Jour Manuelle

```bash
# Arrêt du service
sudo systemctl stop qbittorrent-monitor

# Sauvegarde
cp ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py.backup

# Téléchargement nouvelle version
cd ~/scripts/qbittorrent-monitor
curl -s https://raw.githubusercontent.com/VOTRE_USERNAME/qbittorrent-monitor/main/qbittorrent-monitor.py -o qbittorrent-monitor.py

# Redémarrage
sudo systemctl start qbittorrent-monitor
```

### Réinstallation Complète

```bash
# Arrêt et suppression
sudo systemctl stop qbittorrent-monitor
sudo systemctl disable qbittorrent-monitor
sudo rm /etc/systemd/system/qbittorrent-monitor.service

# Nouvelle installation
curl -s https://raw.githubusercontent.com/VOTRE_USERNAME/qbittorrent-monitor/main/setup.sh | bash
```

## 🙏 Remerciements

- [Sonarr](https://github.com/Sonarr/Sonarr) - Gestion automatisée des séries TV
- [Radarr](https://github.com/Radarr/Radarr) - Gestion automatisée des films
- [qBittorrent](https://github.com/qbittorrent/qBittorrent) - Client BitTorrent

**Made with ❤️ for the media automation community**