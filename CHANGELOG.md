# Changelog - Arr Monitor

## [2.0.0] - 2025-07-12

### 🔄 TRANSFORMATION MAJEURE
- **BREAKING CHANGE** : Projet complètement transformé de "QBittorrent Error Monitor" vers "Arr Monitor"
- **SUPPRESSION** : Surveillance qBittorrent complètement supprimée
- **FOCUS** : Concentration exclusive sur Sonarr et Radarr

### ✨ Nouvelles fonctionnalités
- Script Python standalone `arr-monitor.py`
- Surveillance des APIs Sonarr v3 et Radarr v3
- Détection automatique des téléchargements en erreur
- Actions automatiques de relance et suppression
- Configuration simplifiée via YAML
- Installation interactive avec `install-arr.sh`
- Support service systemd

### 🗑️ Suppressions
- Suppression complète de Docker et containers
- Suppression de qBittorrent API
- Suppression des fichiers CI/CD GitHub Actions
- Suppression du support multi-architecture
- Suppression de LinuxServer.io base

### 🛠️ Technique
- Migration vers Python standalone
- Dépendances réduites : requests + PyYAML uniquement
- Structure de projet simplifiée
- Configuration locale séparée

### 📖 Documentation
- Nouveau README complet
- Guide d'installation simplifié
- Exemples de configuration Sonarr/Radarr
- Instructions service systemd

---

## Historique pré-transformation (QBittorrent Error Monitor)

### [1.x.x] - Versions antérieures
- Surveillance qBittorrent + Sonarr/Radarr
- Base Docker Alpine avec s6-overlay
- Support multi-architecture
- CI/CD GitHub Container Registry
- **Variables d'environnement** avec valeurs par défaut
- **Volumes** simplifiés
- **Suppression** du réseau traefik_proxy

#### **✅ Documentation complètement refaite (`README.md`)**
- **Focus** sur l'approche Docker simple
- **Instructions** claires et directes
- **Trois méthodes** d'installation (rapide, compose, manuelle)
- **Suppression** de toutes les références ssdv2

#### **🗑️ Fichiers supprimés**
- `install-ssdv2.sh` → Obsolète
- `qbittorrent-monitor.yml` → Configuration ssdv2 supprimée
- `MIGRATION.md` → Guide de migration inutile
- `README-new.md` → Ancien README

### **Résultat final**

Le projet est maintenant **simple et direct** :
- **Une image Docker** : `ghcr.io/kesurof/qbittorrent-error-monitor/qbittorrent-monitor:latest`
- **Un script d'installation** : `install.sh` (recommandé)
- **Alternative Docker Compose** : `install-manual.sh`
- **Configuration automatique** sans complexité

### **Usage recommandé**

```bash
# Installation en une commande
curl -sSL https://raw.githubusercontent.com/kesurof/QBittorrent-Error-Monitor/main/install.sh | bash
```

L'application **détecte automatiquement** les conteneurs qBittorrent, Sonarr, Radarr et **s'auto-configure**.
