#!/bin/bash

# Script d'installation Arr Monitor (Surveillance Sonarr/Radarr)
set -euo pipefail

echo "🚀 Installation Arr Monitor - Surveillance Sonarr/Radarr"

# Vérification des prérequis
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 n'est pas installé. Veuillez l'installer avant de continuer."
    exit 1
fi

if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 n'est pas installé. Veuillez l'installer avant de continuer."
    exit 1
fi

# Répertoire d'installation
INSTALL_DIR="${HOME}/arr-monitor"
echo "📁 Installation dans : $INSTALL_DIR"

# Création du répertoire d'installation
if [ -d "$INSTALL_DIR" ]; then
    echo "📂 Le répertoire existe déjà. Mise à jour..."
    cd "$INSTALL_DIR"
else
    echo "📥 Création du répertoire d'installation..."
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Copie des fichiers depuis le répertoire source
SOURCE_DIR="$(dirname "$0")"
echo "📋 Copie des fichiers depuis $SOURCE_DIR..."

cp "$SOURCE_DIR/arr-monitor.py" ./
cp "$SOURCE_DIR/requirements.txt" ./
cp -r "$SOURCE_DIR/config" ./

# Création de l'environnement virtuel
echo "🐍 Création de l'environnement virtuel Python..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

# Activation de l'environnement virtuel
echo "⚡ Activation de l'environnement virtuel..."
source venv/bin/activate

# Installation des dépendances
echo "📦 Installation des dépendances Python..."
pip install --upgrade pip
pip install -r requirements.txt

# Création des répertoires
echo "📁 Création des répertoires..."
mkdir -p logs

# Configuration
if [ ! -f "config/config.yaml.local" ]; then
    echo "⚙️  Création de la configuration locale..."
    cp config/config.yaml config/config.yaml.local
    
    echo ""
    echo "📋 Configuration des applications :"
    
    # Configuration Sonarr
    echo ""
    read -p "📺 Activer Sonarr ? [Y/n] : " ENABLE_SONARR
    ENABLE_SONARR=${ENABLE_SONARR:-Y}
    
    if [[ $ENABLE_SONARR =~ ^[Yy]$ ]]; then
        read -p "📺 URL Sonarr [http://localhost:8989] : " SONARR_URL
        SONARR_URL=${SONARR_URL:-http://localhost:8989}
        
        read -p "📺 Clé API Sonarr : " SONARR_API
        
        # Test de connexion Sonarr
        if [ -n "$SONARR_API" ]; then
            echo "🧪 Test de connexion Sonarr..."
            if curl -s -H "X-Api-Key: $SONARR_API" "$SONARR_URL/api/v3/system/status" > /dev/null; then
                echo "✅ Sonarr connecté avec succès"
            else
                echo "⚠️  Impossible de se connecter à Sonarr (vérifiez l'URL et la clé API)"
            fi
        fi
    fi
    
    # Configuration Radarr
    echo ""
    read -p "🎬 Activer Radarr ? [Y/n] : " ENABLE_RADARR
    ENABLE_RADARR=${ENABLE_RADARR:-Y}
    
    if [[ $ENABLE_RADARR =~ ^[Yy]$ ]]; then
        read -p "🎬 URL Radarr [http://localhost:7878] : " RADARR_URL
        RADARR_URL=${RADARR_URL:-http://localhost:7878}
        
        read -p "🎬 Clé API Radarr : " RADARR_API
        
        # Test de connexion Radarr
        if [ -n "$RADARR_API" ]; then
            echo "🧪 Test de connexion Radarr..."
            if curl -s -H "X-Api-Key: $RADARR_API" "$RADARR_URL/api/v3/system/status" > /dev/null; then
                echo "✅ Radarr connecté avec succès"
            else
                echo "⚠️  Impossible de se connecter à Radarr (vérifiez l'URL et la clé API)"
            fi
        fi
    fi
    
    # Configuration des actions automatiques
    echo ""
    read -p "🔄 Activer les actions automatiques (relance/suppression) ? [Y/n] : " AUTO_ACTIONS
    AUTO_ACTIONS=${AUTO_ACTIONS:-Y}
    
    # Mise à jour du fichier de configuration
    echo "📝 Mise à jour de la configuration..."
    
    if [[ $ENABLE_SONARR =~ ^[Yy]$ ]]; then
        sed -i.bak "s|url: \"http://localhost:8989\"|url: \"$SONARR_URL\"|" config/config.yaml.local
        sed -i.bak2 "s|api_key: \"your_sonarr_api_key\"|api_key: \"$SONARR_API\"|" config/config.yaml.local
    else
        sed -i.bak "s|enabled: true|enabled: false|" config/config.yaml.local
    fi
    
    if [[ $ENABLE_RADARR =~ ^[Yy]$ ]]; then
        sed -i.bak3 "s|url: \"http://localhost:7878\"|url: \"$RADARR_URL\"|" config/config.yaml.local
        sed -i.bak4 "s|api_key: \"your_radarr_api_key\"|api_key: \"$RADARR_API\"|" config/config.yaml.local
    else
        sed -i.bak3 "/radarr:/,/check_stuck:/ s|enabled: true|enabled: false|" config/config.yaml.local
    fi
    
    if [[ $AUTO_ACTIONS =~ ^[Nn]$ ]]; then
        sed -i.bak5 "s|auto_retry: true|auto_retry: false|" config/config.yaml.local
    fi
    
    rm -f config/config.yaml.local.bak*
    
    echo "✅ Configuration créée dans config/config.yaml.local"
else
    echo "✅ Configuration locale existante trouvée"
fi

# Test de l'installation
echo ""
echo "🧪 Test de l'installation..."
if python arr-monitor.py --test --config config/config.yaml.local; then
    echo "✅ Test réussi !"
else
    echo "⚠️  Test échoué, mais l'installation est terminée"
    echo "💡 Vérifiez la configuration dans config/config.yaml.local"
fi

echo ""
echo "✅ Installation terminée avec succès !"
echo ""
echo "📋 Utilisation :"
echo "   cd $INSTALL_DIR"
echo "   source venv/bin/activate"
echo "   python arr-monitor.py --config config/config.yaml.local"
echo ""
echo "📋 Commandes utiles :"
echo "   # Test unique"
echo "   python arr-monitor.py --test --config config/config.yaml.local"
echo ""
echo "   # Mode debug"
echo "   python arr-monitor.py --debug --config config/config.yaml.local"
echo ""
echo "   # Simulation sans actions"
echo "   python arr-monitor.py --dry-run --config config/config.yaml.local"
echo ""
echo "   # Voir les logs"
echo "   tail -f logs/arr-monitor.log"
echo ""
echo "📁 Configuration : $INSTALL_DIR/config/config.yaml.local"
echo "📝 Logs : $INSTALL_DIR/logs/arr-monitor.log"
echo ""
echo "🔧 Pour créer un service système (optionnel) :"
echo "   # Créer le fichier service"
echo "   sudo tee /etc/systemd/system/arr-monitor.service > /dev/null <<EOF"
echo "[Unit]"
echo "Description=Arr Monitor - Surveillance Sonarr/Radarr"
echo "After=network.target"
echo ""
echo "[Service]"
echo "Type=simple"
echo "User=$USER"
echo "WorkingDirectory=$INSTALL_DIR"
echo "ExecStart=$INSTALL_DIR/venv/bin/python $INSTALL_DIR/arr-monitor.py --config $INSTALL_DIR/config/config.yaml.local"
echo "Restart=always"
echo "RestartSec=30"
echo ""
echo "[Install]"
echo "WantedBy=multi-user.target"
echo "EOF"
echo ""
echo "   # Activer et démarrer le service"
echo "   sudo systemctl enable arr-monitor"
echo "   sudo systemctl start arr-monitor"
echo "   sudo systemctl status arr-monitor"
