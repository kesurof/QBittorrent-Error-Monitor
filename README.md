# QBittorrent Error Monitor v2.0 🚀

**Solution Production-Ready pour le monitoring automatique et la correction des erreurs qBittorrent avec Sonarr/Radarr**

[![Version](https://img.shields.io/badge/version-2.0-blue.svg)](https://github.com/kesurof/QBittorrent-Error-Monitor)
[![Python](https://img.shields.io/badge/python-3.7+-green.svg)](https://python.org)
[![Security](https://img.shields.io/badge/security-hardened-red.svg)](#sécurité)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## 🎯 Fonctionnalités Principales

- **🔍 Détection automatique** des erreurs "qBittorrent is reporting an error"
- **🗑️ Suppression automatique** des téléchargements problématiques  
- **🚫 Ajout à la blocklist** pour éviter les re-téléchargements
- **🔍 Lancement automatique** de recherches de remplacement
- **🛡️ Sécurité renforcée** avec validation stricte des entrées
- **🔄 Retry intelligent** avec backoff exponentiel
- **🧪 Modes de test** (dry-run, health-check, verbose)
- **📊 Métriques avancées** et logging rotatif
- **⚙️ Configuration flexible** (YAML, env vars, CLI)

## 🚀 Installation Rapide

### Installation en Une Commande ⭐

```bash
curl -s https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/setup.sh | bash
```

**Cette commande unique :**
- ✅ Télécharge et valide tous les fichiers nécessaires
- 🔍 Détecte automatiquement votre configuration existante
- 🛡️ Configure le script avec validation de sécurité
- 🔧 Installe le service systemd sécurisé
- 🚀 Démarre le monitoring automatiquement
- 🧪 Effectue des tests de validation

### Installation pour un Utilisateur Spécifique

```bash
curl -s https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/setup.sh | bash -s -- nom_utilisateur
```

### Installation Manuelle (Recommandée pour Production)

```bash
# Clonage du repository
git clone https://github.com/kesurof/QBittorrent-Error-Monitor.git
cd QBittorrent-Error-Monitor

# Test de validation complet
chmod +x test-suite.sh
./test-suite.sh

# Installation si les tests passent
chmod +x setup.sh
./setup.sh
```

## 📋 Prérequis

- **Python 3.7+** avec pip
- **Docker** en fonctionnement
- **Sonarr/Radarr** configurés
- **qBittorrent** connecté à Sonarr/Radarr
- **Permissions sudo** pour l'installation du service

## ⚙️ Configuration

### Fichier de Configuration (config/config.yaml)

```yaml
# Configuration générale
general:
  check_interval: 300  # Intervalle en secondes
  log_level: "INFO"    # DEBUG, INFO, WARNING, ERROR
  max_retries: 3
  retry_backoff: 2     # Facteur d'attente exponentielle
  dry_run: false       # Mode test sans actions

# Configuration des services
services:
  sonarr:
    enabled: true
    port: 8989
    container_name: "sonarr"
    max_errors_per_cycle: 10
  
  radarr:
    enabled: true
    port: 7878
    container_name: "radarr"
    max_errors_per_cycle: 10

# Configuration sécurité
security:
  validate_paths: true
  sanitize_inputs: true
  max_path_length: 4096
```

### Variables d'Environnement

```bash
export CHECK_INTERVAL=300        # Intervalle de vérification
export LOG_LEVEL=INFO           # Niveau de logging
export DOCKER_NETWORK=traefik_proxy  # Réseau Docker
export DRY_RUN=false           # Mode simulation
```

## 🧪 Modes de Test et Validation

### Health Check Complet

```bash
# Contrôle de santé du système
python3 ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py --health-check

# Résultat JSON avec détails de connectivité
{
  "status": "healthy",
  "services": {
    "sonarr": {"status": "healthy", "container_ip": "172.18.0.5"},
    "radarr": {"status": "healthy", "container_ip": "172.18.0.6"}
  }
}
```

### Mode Dry-Run (Simulation)

```bash
# Test sans effectuer d'actions réelles
python3 ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py --dry-run --verbose

# Sortie :
# 🧪 DRY-RUN: sonarr: Suppression et blocklist simulée - Movie.Name.2024
# 🧪 DRY-RUN: sonarr: Recherche de remplacement simulée
```

### Test Complet du Système

```bash
# Suite de tests complète
./test-suite.sh

# Résultat :
# ✅ Tests exécutés: 25
# ✅ Tests réussis: 25
# ❌ Tests échoués: 0
# Taux de réussite: 100%
```

### Mode Test (Un Cycle)

```bash
# Exécution d'un seul cycle de monitoring
python3 ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py --test --verbose
```

## 🛡️ Sécurité

### Fonctionnalités de Sécurité Intégrées

- **✅ Validation stricte des entrées** avec regex patterns
- **✅ Échappement sécurisé** pour toutes les commandes shell
- **✅ Pas d'utilisation de `shell=True`** dans subprocess
- **✅ Validation des chemins** contre le directory traversal
- **✅ Limitation des ressources** (CPU, mémoire, timeouts)
- **✅ Variables d'environnement quotées** et échappées
- **✅ Sandbox systemd** avec restrictions d'accès

### Exemple de Validation Sécurisée

```python
# ❌ Avant (vulnérable)
cmd = f"docker inspect {container_name}"
subprocess.run(cmd, shell=True)

# ✅ Après (sécurisé)
container_name = SecurityValidator.sanitize_container_name(container_name)
cmd_parts = ['docker', 'inspect', container_name]
subprocess.run(cmd_parts, check=False)
```

## 📊 Monitoring et Métriques

### Logs Rotatifs

```bash
# Logs en temps réel
tail -f ~/logs/qbittorrent-error-monitor.log

# Rotation automatique (10MB, 5 fichiers)
~/logs/qbittorrent-error-monitor.log.1
~/logs/qbittorrent-error-monitor.log.2
```

### Statistiques JSON

```bash
# Statistiques détaillées
cat ~/logs/qbittorrent-stats.json

{
  "cycles": 150,
  "errors_detected": 5,
  "downloads_removed": 5,
  "searches_triggered": 3,
  "errors_by_service": {
    "sonarr": 3,
    "radarr": 2
  },
  "performance_metrics": {
    "sonarr": [
      {"operation": "get_queue", "duration": 0.45}
    ]
  }
}
```

### Service Systemd Avancé

```bash
# Statut détaillé
sudo systemctl status qbittorrent-monitor

# Logs en temps réel
sudo journalctl -u qbittorrent-monitor -f

# Métriques de ressources
systemd-cgtop -p | grep qbittorrent
```

## 🔧 Gestion du Service

### Commandes de Base

```bash
# Démarrage/Arrêt
sudo systemctl start qbittorrent-monitor
sudo systemctl stop qbittorrent-monitor
sudo systemctl restart qbittorrent-monitor

# Status et logs
sudo systemctl status qbittorrent-monitor
sudo journalctl -u qbittorrent-monitor -n 50

# Activation/Désactivation
sudo systemctl enable qbittorrent-monitor
sudo systemctl disable qbittorrent-monitor
```

### Configuration Avancée du Service

Le service systemd inclut :
- **Restart automatique** avec backoff intelligent
- **Health check** avant démarrage
- **Limites de ressources** (128MB RAM, 25% CPU)
- **Sandbox de sécurité** avec accès restreint
- **Monitoring des ressources** avec IPAccounting

## 🚨 Dépannage

### Problèmes Courants

#### 1. Service qui ne démarre pas

```bash
# Vérification des logs
sudo journalctl -u qbittorrent-monitor -n 20

# Test manuel
sudo -u $USER python3 ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py --test --verbose
```

#### 2. Erreurs de connectivité Docker

```bash
# Vérification des IPs des conteneurs
docker inspect sonarr --format='{{.NetworkSettings.Networks.traefik_proxy.IPAddress}}'
docker inspect radarr --format='{{.NetworkSettings.Networks.traefik_proxy.IPAddress}}'

# Test de connectivité
ping -c 3 <container_ip>
```

#### 3. Clés API manquantes

```bash
# Vérification des fichiers de config
ls -la /home/$USER/.config/sonarr/config/config.xml
ls -la /home/$USER/.config/radarr/config/config.xml

# Extraction manuelle de la clé API
grep -o '<ApiKey>.*</ApiKey>' /home/$USER/.config/sonarr/config/config.xml
```

#### 4. Permissions insuffisantes

```bash
# Correction des permissions
sudo chown -R $USER:$USER ~/scripts/qbittorrent-monitor/
sudo chown -R $USER:$USER ~/logs/
chmod +x ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py
```

### Mode Debug Avancé

```bash
# Logs détaillés avec toutes les informations
python3 ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py \
  --verbose \
  --test \
  --config ~/scripts/qbittorrent-monitor/config/config.yaml

# Health check détaillé
python3 ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py --health-check | jq .
```

## 🔄 Migration depuis v1.0

### Mise à Jour Automatique

```bash
# Sauvegarde de l'ancienne configuration
sudo systemctl stop qbittorrent-monitor
cp -r ~/scripts/qbittorrent-monitor ~/scripts/qbittorrent-monitor.backup

# Installation de la v2.0
curl -s https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/setup.sh | bash

# Vérification du bon fonctionnement
python3 ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py --health-check
```

### Nouvelles Fonctionnalités v2.0

- 🛡️ **Sécurité renforcée** avec validation stricte
- 🔄 **Retry intelligent** avec backoff exponentiel
- 🧪 **Modes de test** complets (dry-run, health-check)
- 📊 **Métriques avancées** et performance tracking
- ⚙️ **Configuration YAML** flexible
- 🚀 **Installation sécurisée** avec validation
- 📝 **Logging rotatif** avec niveaux configurables

## 🤝 Contribution

Contributions bienvenues ! Voir [CONTRIBUTING.md](CONTRIBUTING.md)

1. Fork le projet
2. Créer une branche (`git checkout -b feature/improvement`)
3. Exécuter les tests (`./test-suite.sh`)
4. Commit vos changements (`git commit -am 'Add improvement'`)
5. Push vers la branche (`git push origin feature/improvement`)
6. Créer une Pull Request

## 📝 Changelog

### v2.0.0 (2024)
- 🛡️ Sécurité renforcée avec validation stricte des entrées
- 🔄 Retry automatique avec backoff exponentiel
- 🧪 Modes de test complets (dry-run, health-check, verbose)
- 📊 Métriques avancées et monitoring de performance
- ⚙️ Configuration YAML flexible et hiérarchique
- 🚀 Installation sécurisée avec tests de validation
- 📝 Logging rotatif avec niveaux configurables
- 🔧 Service systemd avec sandbox de sécurité

### v1.0.0 (2024)
- 🔍 Détection automatique des erreurs qBittorrent
- 🗑️ Suppression et blocklist automatiques
- 🔍 Recherches de remplacement automatiques
- 🔧 Service systemd basique

## 📄 License

Ce projet est sous licence MIT. Voir [LICENSE](LICENSE) pour plus de détails.

---

**⭐ Si ce projet vous aide, n'hésitez pas à lui donner une étoile !**