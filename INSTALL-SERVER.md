# Guide d'Installation Serveur - QBittorrent Error Monitor v2.0

## 🚀 Installation Rapide sur Serveur

### Étape 1 : Préparation du Serveur

```bash
# Connexion SSH à votre serveur
ssh votre_utilisateur@votre_serveur

# Mise à jour du système
sudo apt update && sudo apt upgrade -y

# Installation des dépendances
sudo apt install -y python3 python3-pip curl git docker.io
```

### Étape 2 : Vérification de l'Environnement

```bash
# Vérifier que Docker fonctionne
sudo systemctl status docker
docker ps  # Doit montrer vos conteneurs Sonarr/Radarr

# Vérifier Python
python3 --version  # Doit être >= 3.7

# Vérifier les conteneurs Sonarr/Radarr
docker inspect sonarr | grep IPAddress
docker inspect radarr | grep IPAddress
```

### Étape 3 : Installation Automatique

```bash
# Installation en une commande
curl -s https://raw.githubusercontent.com/VOTRE_USERNAME/QBittorrent-Error-Monitor/main/setup.sh | bash

# OU pour un utilisateur spécifique
curl -s https://raw.githubusercontent.com/VOTRE_USERNAME/QBittorrent-Error-Monitor/main/setup.sh | bash -s -- votre_utilisateur
```

### Étape 4 : Installation Manuelle (Recommandée)

```bash
# Clonage du repository
git clone https://github.com/VOTRE_USERNAME/QBittorrent-Error-Monitor.git
cd QBittorrent-Error-Monitor

# Rendre les scripts exécutables
chmod +x setup.sh install.sh test-suite.sh

# Lancer l'installation
./setup.sh
```

### Étape 5 : Vérification Post-Installation

```bash
# Vérifier le statut du service
sudo systemctl status qbittorrent-monitor

# Vérifier les logs
tail -f ~/logs/qbittorrent-error-monitor.log

# Test de santé
python3 ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py --health-check

# Test dry-run
python3 ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py --test --dry-run --verbose
```

## 🔧 Configuration Personnalisée

### Modifier la Configuration

```bash
# Éditer le fichier de configuration
nano ~/scripts/qbittorrent-monitor/config/config.yaml

# Redémarrer le service après modification
sudo systemctl restart qbittorrent-monitor
```

### Exemple de Configuration Personnalisée

```yaml
general:
  check_interval: 180  # Vérification toutes les 3 minutes
  log_level: "DEBUG"   # Logs détaillés
  dry_run: false      # Actions réelles

services:
  sonarr:
    enabled: true
    port: 8989
    container_name: "sonarr"  # Nom de votre conteneur
    
  radarr:
    enabled: true
    port: 7878
    container_name: "radarr"  # Nom de votre conteneur

docker:
  network: "traefik_proxy"  # Votre réseau Docker
  timeout: 10               # Timeout pour Docker
```

## 🚨 Dépannage Rapide

### Problème : Service ne démarre pas

```bash
# Vérifier les logs d'erreur
sudo journalctl -u qbittorrent-monitor -f

# Test manuel
sudo -u $USER python3 ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py --test --verbose
```

### Problème : Containers non détectés

```bash
# Lister tous les conteneurs
docker ps -a

# Vérifier les réseaux Docker
docker network ls
docker network inspect traefik_proxy  # ou votre réseau

# Tester la connectivité
docker exec sonarr ping -c 3 radarr
```

### Problème : Clés API manquantes

```bash
# Localiser les fichiers de config
find /home -name "config.xml" 2>/dev/null | grep -E "(sonarr|radarr)"

# Extraire les clés API
grep -o '<ApiKey>.*</ApiKey>' /chemin/vers/sonarr/config.xml
```

## 📊 Surveillance

### Commandes Utiles

```bash
# Statut en temps réel
watch 'sudo systemctl status qbittorrent-monitor --no-pager'

# Statistiques JSON
watch 'cat ~/logs/qbittorrent-stats.json | jq .'

# Logs avec couleurs
sudo journalctl -u qbittorrent-monitor -f --output=cat

# Utilisation des ressources
systemd-cgtop -p | grep qbittorrent
```

### Dashboard Simple

```bash
# Créer un script de monitoring simple
cat > ~/monitor-dashboard.sh << 'EOF'
#!/bin/bash
clear
echo "=== QBittorrent Monitor Dashboard ==="
echo "Status: $(sudo systemctl is-active qbittorrent-monitor)"
echo "Uptime: $(sudo systemctl show qbittorrent-monitor --property=ActiveEnterTimestamp --value)"
echo ""
echo "=== Dernières Statistiques ==="
cat ~/logs/qbittorrent-stats.json | jq . 2>/dev/null || echo "Pas de stats disponibles"
echo ""
echo "=== Derniers Logs ==="
tail -5 ~/logs/qbittorrent-error-monitor.log
EOF

chmod +x ~/monitor-dashboard.sh
```

## 🎯 Tests de Fonctionnement

### Test Complet

```bash
# Test de tous les composants
~/QBittorrent-Error-Monitor/test-suite.sh

# Test avec simulation d'erreur
python3 ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py --test --dry-run --verbose
```

### Validation de Production

```bash
# 1. Health check
python3 ~/scripts/qbittorrent-monitor/qbittorrent-monitor.py --health-check | jq .

# 2. Test de connectivité API
curl -H "X-Api-Key: VOTRE_CLE_API" http://IP_SONARR:8989/api/v3/system/status

# 3. Vérification du service
sudo systemctl is-enabled qbittorrent-monitor
sudo systemctl is-active qbittorrent-monitor
```

---

**🎉 Votre QBittorrent Error Monitor v2.0 est maintenant installé et sécurisé !**

Pour toute question ou problème, consultez les logs détaillés et n'hésitez pas à utiliser le mode debug.
