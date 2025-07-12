# QBittorrent Error Monitor

🚀 **Script Python pour monitor automatique des erreurs qBittorrent avec intégration Sonarr/Radarr**

## 🎯 **Fonctionnalités principales**

### 🔍 **Monitoring intelligent**
- **Détection automatique** des erreurs qBittorrent en temps réel
- **Surveillance continue** des logs et états des torrents
- **Patterns d'erreur configurables** (timeout, DNS, tracker, ratio...)
- **Connexion directe** aux APIs qBittorrent, Sonarr, Radarr

### 🛠️ **Actions automatiques**
- **Suppression intelligente** des téléchargements échoués
- **Blacklist automatique** pour éviter les re-téléchargements
- **Déclenchement immédiat** de nouvelles recherches Sonarr/Radarr
- **Notifications** optionnelles (logs détaillés)

### � **Script Python simple**
- **Aucune dépendance Docker** requise
- **Installation simple** avec pip
- **Configuration YAML** facile
- **Logs structurés** avec rotation automatique

## 📁 **Installation**

### **🚀 Installation rapide**

```bash
# Cloner le repository
git clone https://github.com/kesurof/QBittorrent-Error-Monitor.git
cd QBittorrent-Error-Monitor

# Installer les dépendances
pip install -r requirements.txt

# Copier et éditer la configuration
cp config/config.yaml config/config.yaml.local
nano config/config.yaml.local

# Lancer le script
python qbittorrent-monitor.py --config config/config.yaml.local
```

### **� Installation avec environnement virtuel (recommandé)**

```bash
# Cloner le repository
git clone https://github.com/kesurof/QBittorrent-Error-Monitor.git
cd QBittorrent-Error-Monitor

# Créer un environnement virtuel
python -m venv venv
source venv/bin/activate  # Linux/Mac
# ou
venv\Scripts\activate     # Windows

# Installer les dépendances
pip install -r requirements.txt

# Configurer et lancer
cp config/config.yaml config/config.yaml.local
python qbittorrent-monitor.py --config config/config.yaml.local
```

## ⚙️ **Configuration**

### **Fichier de configuration**

Éditez `config/config.yaml.local` selon vos besoins :

```yaml
# Configuration QBittorrent Error Monitor
qbittorrent:
  host: "localhost"
  port: 8080
  username: "admin"
  password: "adminadmin"
  use_https: false

applications:
  sonarr:
    enabled: true
    url: "http://localhost:8989"
    api_key: "your_sonarr_api_key"
  radarr:
    enabled: true
    url: "http://localhost:7878"
    api_key: "your_radarr_api_key"

monitoring:
  check_interval: 300           # Intervalle en secondes
  max_retries: 3
  
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

logging:
  level: "INFO"                 # DEBUG|INFO|WARNING|ERROR
  file: "logs/monitor.log"
  max_size_mb: 10
  backup_count: 5
```

### **Variables d'environnement**

Vous pouvez aussi utiliser des variables d'environnement :

```bash
export QB_HOST="localhost"
export QB_PORT="8080"
export QB_USERNAME="admin"
export QB_PASSWORD="adminadmin"
export SONARR_URL="http://localhost:8989"
export SONARR_API_KEY="your_key"
export RADARR_URL="http://localhost:7878"
export RADARR_API_KEY="your_key"
export LOG_LEVEL="INFO"
```

## 🔧 **Utilisation**

### **Lancement du script**

```bash
# Lancement normal
python qbittorrent-monitor.py

# Avec configuration personnalisée
python qbittorrent-monitor.py --config /path/to/config.yaml

# Mode test (un seul cycle)
python qbittorrent-monitor.py --test

# Mode dry-run (simulation sans actions)
python qbittorrent-monitor.py --dry-run

# Mode debug
python qbittorrent-monitor.py --debug

# Aide
python qbittorrent-monitor.py --help
```

### **Service système (Linux)**

Créer un service systemd pour lancement automatique :

```bash
# Créer le fichier service
sudo nano /etc/systemd/system/qbittorrent-monitor.service
```

```ini
[Unit]
Description=QBittorrent Error Monitor
After=network.target

[Service]
Type=simple
User=your_user
WorkingDirectory=/path/to/QBittorrent-Error-Monitor
ExecStart=/path/to/venv/bin/python qbittorrent-monitor.py --config config/config.yaml.local
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
# Activer et démarrer le service
sudo systemctl enable qbittorrent-monitor
sudo systemctl start qbittorrent-monitor

# Vérifier le statut
sudo systemctl status qbittorrent-monitor

# Voir les logs
sudo journalctl -f -u qbittorrent-monitor
```

### **Tâche cron**

Pour exécuter périodiquement :

```bash
# Éditer crontab
crontab -e

# Ajouter ligne pour exécution toutes les 5 minutes
*/5 * * * * cd /path/to/QBittorrent-Error-Monitor && /path/to/venv/bin/python qbittorrent-monitor.py --test
```

## 📊 **Logs et monitoring**

### **Structure des logs**

```bash
logs/
├── monitor.log              # Log principal
├── monitor.log.1            # Rotation automatique
├── monitor.log.2
└── ...
```

### **Commandes utiles**

```bash
# Voir les logs en temps réel
tail -f logs/monitor.log

# Chercher les erreurs
grep "ERROR" logs/monitor.log

# Statistiques
grep "Torrent supprimé" logs/monitor.log | wc -l
grep "Recherche déclenchée" logs/monitor.log | wc -l

# Nettoyer les anciens logs
find logs/ -name "*.log.*" -mtime +30 -delete
```

## 🔧 **Dépannage**

### **Problèmes courants**

#### **1. Erreur de connexion qBittorrent**
```bash
# Vérifier la connexion
curl -u admin:adminadmin http://localhost:8080/api/v2/app/version

# Tester avec le script
python qbittorrent-monitor.py --test --debug
```

#### **2. APIs Sonarr/Radarr non accessibles**
```bash
# Vérifier les URLs et clés API
curl -H "X-Api-Key: YOUR_KEY" http://localhost:8989/api/v3/system/status
curl -H "X-Api-Key: YOUR_KEY" http://localhost:7878/api/v3/system/status
```

#### **3. Permissions de fichiers**
```bash
# Corriger les permissions
chmod +x qbittorrent-monitor.py
chmod 644 config/config.yaml.local
mkdir -p logs && chmod 755 logs
```

#### **4. Dépendances manquantes**
```bash
# Réinstaller les dépendances
pip install --force-reinstall -r requirements.txt

# Vérifier l'installation
python -c "import requests, yaml; print('OK')"
```

## 🛠️ **Développement**

### **Structure du projet**

```
QBittorrent-Error-Monitor/
├── qbittorrent-monitor.py   # Script principal
├── config/
│   └── config.yaml          # Configuration par défaut
├── logs/                    # Logs (créé automatiquement)
├── requirements.txt         # Dépendances Python
└── README.md               # Documentation
```

### **Dépendances Python**

```python
requests>=2.28.0
PyYAML>=6.0
```

### **Contribution**

```bash
# Fork le repository
git clone https://github.com/YOUR_USERNAME/QBittorrent-Error-Monitor.git

# Créer une branche
git checkout -b feature/nouvelle-fonctionnalite

# Faire vos modifications
# ...

# Tester
python qbittorrent-monitor.py --test --dry-run

# Commit et push
git add .
git commit -m "Ajout nouvelle fonctionnalité"
git push origin feature/nouvelle-fonctionnalite
```

## 🔗 **Ressources et liens**

- 🔧 [qBittorrent WebUI API](https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API)
- 📡 [Sonarr API Documentation](https://sonarr.tv/docs/api/)
- 🎬 [Radarr API Documentation](https://radarr.video/docs/api/)
- � [Python Requests](https://docs.python-requests.org/)
- � [PyYAML Documentation](https://pyyaml.org/)

## 📄 **Licence**

MIT License - Voir le fichier [LICENSE](LICENSE)

---

**🎯 Script Python simple et efficace • � Aucune dépendance Docker • 🔧 Configuration flexible**
