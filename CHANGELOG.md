## Simplification complète du projet

### **Objectif**
Retour à une approche **Docker simple** sans la complexité ssdv2, en gardant seulement l'image Docker de base.

### **Changements majeurs**

#### **✅ Nouveau script d'installation simple (`install.sh`)**
- **Installation en une commande** avec `docker run`
- **Configuration automatique** des répertoires
- **Variables d'environnement** simples
- **Pas de dépendance** docker-compose

#### **✅ Script Docker Compose simplifié (`install-manual.sh`)**
- **Suppression** de toutes les références ssdv2
- **Configuration** simplifiée
- **Image** `latest` au lieu de `ssdv2`

#### **✅ Docker Compose mis à jour**
- **Image** `ghcr.io/.../qbittorrent-monitor:latest`
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
