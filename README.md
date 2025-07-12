# 🔄 Arr Monitor - Surveillance Sonarr/Radarr

## 📝 Description

Arr Monitor est un outil de surveillance et de gestion automatique des erreurs pour Sonarr et Radarr. Il surveille les files d'attente, détecte les téléchargements en erreur ou bloqués, et peut automatiquement relancer ou supprimer les éléments problématiques.

## ✨ Fonctionnalités

- 📊 **Surveillance des files d'attente** Sonarr et Radarr
- 🔍 **Détection des erreurs** de téléchargement
- ⚡ **Actions automatiques** : relance et suppression
- 🎯 **Détection des téléchargements bloqués**
- 📱 **Notifications** (webhook, email)
- 🐍 **Installation simple** en Python standalone
- 📊 **Logs détaillés** et mode debug

## 🚀 Installation Rapide

```bash
# Cloner le projet
git clone https://github.com/kesurof/Arr-Monitor.git
cd Arr-Monitor

# Lancer l'installation interactive
./install-arr.sh
```

## ⚙️ Configuration

Le fichier de configuration `config/config.yaml.local` est créé automatiquement lors de l'installation. Il contient :

### Applications surveillées
- **Sonarr** : URL, clé API, seuils de surveillance
- **Radarr** : URL, clé API, seuils de surveillance

### Actions automatiques
- **Relance automatique** des téléchargements en erreur
- **Suppression** des téléchargements bloqués trop longtemps
- **Seuils personnalisables** pour chaque action

### Notifications
- **Webhooks** pour intégrations externes
- **Email** pour alertes importantes

## 📋 Utilisation

```bash
# Démarrer la surveillance
python arr-monitor.py --config config/config.yaml.local

# Mode test (une vérification uniquement)
python arr-monitor.py --test --config config/config.yaml.local

# Mode debug (logs détaillés)
python arr-monitor.py --debug --config config/config.yaml.local

# Mode simulation (sans actions)
python arr-monitor.py --dry-run --config config/config.yaml.local
```

## 🔧 Service Système

Pour une surveillance continue, installez comme service :

```bash
# Copier le fichier service
sudo cp arr-monitor.service /etc/systemd/system/

# Éditer les chemins dans le service
sudo nano /etc/systemd/system/arr-monitor.service

# Activer et démarrer
sudo systemctl enable arr-monitor
sudo systemctl start arr-monitor
sudo systemctl status arr-monitor
```

## 📊 Surveillance

### Logs
```bash
# Voir les logs en temps réel
tail -f logs/arr-monitor.log

# Voir les logs du service
sudo journalctl -u arr-monitor -f
```

### Métriques surveillées
- **Files d'attente** : éléments en cours
- **Erreurs** : téléchargements échoués
- **Bloqués** : éléments sans progression
- **Historique** : téléchargements récents

## 🛠️ Dépendances

- Python 3.6+
- requests >= 2.28.0
- PyYAML >= 6.0

## 📁 Structure du Projet

```
arr-monitor/
├── arr-monitor.py          # Script principal
├── config/
│   ├── config.yaml         # Configuration par défaut
│   └── config.yaml.local   # Configuration locale
├── logs/                   # Fichiers de logs
├── install-arr.sh         # Script d'installation
├── arr-monitor.service    # Fichier service systemd
├── requirements.txt       # Dépendances Python
└── README_ARR.md         # Documentation
```

## 🔗 APIs Utilisées

- **Sonarr API v3** : `/api/v3/queue`, `/api/v3/history`, `/api/v3/command`
- **Radarr API v3** : `/api/v3/queue`, `/api/v3/history`, `/api/v3/command`

## 📝 Licence

MIT License - Voir le fichier LICENSE

## 🤝 Contribution

Les contributions sont les bienvenues ! Ouvrez une issue ou une pull request.

---

**Note** : Ce projet était auparavant "QBittorrent Error Monitor" et a été transformé pour se concentrer exclusivement sur la surveillance Sonarr/Radarr.
