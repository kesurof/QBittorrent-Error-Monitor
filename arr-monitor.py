#!/usr/bin/env python3
"""
Arr Monitor - Surveillance automatique des erreurs Sonarr/Radarr
Détecte et corrige automatiquement les téléchargements échoués ou bloqués
"""

import argparse
import logging
import time
import sys
import os
from pathlib import Path
import yaml
import requests
from datetime import datetime, timedelta
import json

class ArrMonitor:
    def __init__(self, config_path="config/config.yaml"):
        self.config = self.load_config(config_path)
        self.setup_logging()
        self.session = requests.Session()
        
    def load_config(self, config_path):
        """Charge la configuration depuis le fichier YAML"""
        try:
            with open(config_path, 'r', encoding='utf-8') as f:
                config = yaml.safe_load(f)
            return config
        except FileNotFoundError:
            print(f"❌ Fichier de configuration non trouvé : {config_path}")
            sys.exit(1)
        except yaml.YAMLError as e:
            print(f"❌ Erreur dans la configuration YAML : {e}")
            sys.exit(1)
    
    def setup_logging(self):
        """Configure le système de logs"""
        log_config = self.config.get('logging', {})
        log_level = getattr(logging, log_config.get('level', 'INFO'))
        log_file = log_config.get('file', 'logs/arr-monitor.log')
        
        # Créer le répertoire des logs s'il n'existe pas
        Path(log_file).parent.mkdir(exist_ok=True)
        
        # Configuration du logging avec rotation
        logging.basicConfig(
            level=log_level,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file, encoding='utf-8'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
        
    def test_connection(self, app_name, url, api_key):
        """Test la connexion à l'API d'une application"""
        try:
            headers = {'X-Api-Key': api_key}
            response = self.session.get(f"{url}/api/v3/system/status", headers=headers, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                version = data.get('version', 'Unknown')
                self.logger.info(f"✅ {app_name} connecté (v{version})")
                return True
            else:
                self.logger.error(f"❌ {app_name} erreur HTTP {response.status_code}")
                return False
                
        except requests.exceptions.RequestException as e:
            self.logger.error(f"❌ {app_name} connexion échouée : {e}")
            return False
    
    def get_queue(self, app_name, url, api_key):
        """Récupère la queue des téléchargements"""
        try:
            headers = {'X-Api-Key': api_key}
            response = self.session.get(f"{url}/api/v3/queue", headers=headers, timeout=10)
            
            if response.status_code == 200:
                return response.json()
            else:
                self.logger.error(f"❌ {app_name} erreur récupération queue : {response.status_code}")
                return []
                
        except requests.exceptions.RequestException as e:
            self.logger.error(f"❌ {app_name} erreur queue : {e}")
            return []
    
    def get_history(self, app_name, url, api_key, since_hours=24):
        """Récupère l'historique des téléchargements"""
        try:
            headers = {'X-Api-Key': api_key}
            since_date = datetime.now() - timedelta(hours=since_hours)
            params = {
                'since': since_date.isoformat(),
                'pageSize': 100
            }
            response = self.session.get(f"{url}/api/v3/history", headers=headers, params=params, timeout=10)
            
            if response.status_code == 200:
                return response.json().get('records', [])
            else:
                self.logger.error(f"❌ {app_name} erreur récupération historique : {response.status_code}")
                return []
                
        except requests.exceptions.RequestException as e:
            self.logger.error(f"❌ {app_name} erreur historique : {e}")
            return []
    
    def retry_download(self, app_name, url, api_key, download_id):
        """Relance un téléchargement échoué"""
        try:
            headers = {'X-Api-Key': api_key}
            response = self.session.post(f"{url}/api/v3/queue/{download_id}/retry", headers=headers, timeout=10)
            
            if response.status_code in [200, 201]:
                self.logger.info(f"🔄 {app_name} téléchargement {download_id} relancé")
                return True
            else:
                self.logger.error(f"❌ {app_name} erreur relance {download_id} : {response.status_code}")
                return False
                
        except requests.exceptions.RequestException as e:
            self.logger.error(f"❌ {app_name} erreur relance {download_id} : {e}")
            return False
    
    def remove_download(self, app_name, url, api_key, download_id):
        """Supprime un téléchargement de la queue"""
        try:
            headers = {'X-Api-Key': api_key}
            response = self.session.delete(f"{url}/api/v3/queue/{download_id}", headers=headers, timeout=10)
            
            if response.status_code in [200, 204]:
                self.logger.info(f"🗑️  {app_name} téléchargement {download_id} supprimé")
                return True
            else:
                self.logger.error(f"❌ {app_name} erreur suppression {download_id} : {response.status_code}")
                return False
                
        except requests.exceptions.RequestException as e:
            self.logger.error(f"❌ {app_name} erreur suppression {download_id} : {e}")
            return False
    
    def search_missing(self, app_name, url, api_key):
        """Lance une recherche des éléments manquants"""
        try:
            headers = {'X-Api-Key': api_key}
            command = "MissingMoviesSearch" if app_name.lower() == "radarr" else "MissingEpisodeSearch"
            
            data = {"name": command}
            response = self.session.post(f"{url}/api/v3/command", headers=headers, json=data, timeout=10)
            
            if response.status_code in [200, 201]:
                self.logger.info(f"🔍 {app_name} recherche manquants lancée")
                return True
            else:
                self.logger.error(f"❌ {app_name} erreur recherche : {response.status_code}")
                return False
                
        except requests.exceptions.RequestException as e:
            self.logger.error(f"❌ {app_name} erreur recherche : {e}")
            return False
    
    def is_download_stuck(self, item):
        """Vérifie si un téléchargement est bloqué"""
        status = item.get('status', '').lower()
        stuck_patterns = self.config.get('error_patterns', {}).get('stuck_patterns', [])
        
        # Vérifie les patterns de blocage
        for pattern in stuck_patterns:
            if pattern.lower() in status:
                # Vérifie depuis combien de temps
                added_time = item.get('added')
                if added_time:
                    try:
                        added_dt = datetime.fromisoformat(added_time.replace('Z', '+00:00'))
                        stuck_threshold = self.config.get('monitoring', {}).get('stuck_threshold', 3600)
                        if (datetime.now().timestamp() - added_dt.timestamp()) > stuck_threshold:
                            return True
                    except (ValueError, TypeError):
                        pass
        return False
    
    def is_download_failed(self, item):
        """Vérifie si un téléchargement a échoué"""
        status = item.get('status', '').lower()
        error_message = item.get('errorMessage', '').lower()
        
        error_patterns = self.config.get('error_patterns', {}).get('download_errors', [])
        
        # Vérifie les patterns d'erreur
        for pattern in error_patterns:
            if pattern.lower() in status or pattern.lower() in error_message:
                return True
        return False
    
    def process_application(self, app_name, app_config):
        """Traite une application (Sonarr ou Radarr)"""
        if not app_config.get('enabled', False):
            self.logger.debug(f"⏭️  {app_name} désactivé")
            return
        
        url = app_config.get('url')
        api_key = app_config.get('api_key')
        
        if not url or not api_key or api_key == f"your_{app_name.lower()}_api_key":
            self.logger.warning(f"⚠️  {app_name} configuration incomplète")
            return
        
        self.logger.info(f"🔍 Analyse de {app_name}...")
        
        # Test de connexion
        if not self.test_connection(app_name, url, api_key):
            return
        
        # Récupération de la queue
        queue = self.get_queue(app_name, url, api_key)
        if not queue:
            self.logger.info(f"📭 {app_name} queue vide")
            return
        
        self.logger.info(f"📋 {app_name} {len(queue)} éléments en queue")
        
        actions_config = self.config.get('actions', {})
        processed_items = 0
        
        for item in queue:
            item_id = item.get('id')
            title = item.get('title', 'Unknown')
            
            # Vérification des téléchargements échoués
            if app_config.get('check_failed', True) and self.is_download_failed(item):
                self.logger.warning(f"❌ {app_name} échec détecté : {title}")
                
                if actions_config.get('auto_retry', True):
                    if self.retry_download(app_name, url, api_key, item_id):
                        processed_items += 1
                        time.sleep(1)  # Délai entre actions
                
            # Vérification des téléchargements bloqués
            elif app_config.get('check_stuck', True) and self.is_download_stuck(item):
                self.logger.warning(f"⏸️  {app_name} téléchargement bloqué : {title}")
                
                if actions_config.get('auto_retry', True):
                    # Supprime et relance une recherche
                    if self.remove_download(app_name, url, api_key, item_id):
                        time.sleep(2)
                        self.search_missing(app_name, url, api_key)
                        processed_items += 1
        
        if processed_items > 0:
            self.logger.info(f"✅ {app_name} {processed_items} éléments traités")
        else:
            self.logger.info(f"✅ {app_name} aucun problème détecté")
    
    def run_cycle(self):
        """Exécute un cycle complet de surveillance"""
        self.logger.info("🚀 Début du cycle de surveillance")
        
        applications = self.config.get('applications', {})
        
        for app_name, app_config in applications.items():
            try:
                self.process_application(app_name, app_config)
            except Exception as e:
                self.logger.error(f"❌ Erreur traitement {app_name} : {e}")
        
        self.logger.info("✅ Cycle terminé")
    
    def run_continuous(self):
        """Exécute la surveillance en continu"""
        check_interval = self.config.get('monitoring', {}).get('check_interval', 300)
        
        self.logger.info(f"🔄 Démarrage surveillance continue (intervalle: {check_interval}s)")
        
        try:
            while True:
                self.run_cycle()
                self.logger.info(f"⏰ Attente {check_interval} secondes...")
                time.sleep(check_interval)
                
        except KeyboardInterrupt:
            self.logger.info("🛑 Arrêt demandé par l'utilisateur")
        except Exception as e:
            self.logger.error(f"❌ Erreur fatale : {e}")
            sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Arr Monitor - Surveillance Sonarr/Radarr")
    parser.add_argument('--config', '-c', default='config/config.yaml', 
                       help='Chemin du fichier de configuration')
    parser.add_argument('--test', '-t', action='store_true', 
                       help='Exécuter un seul cycle de test')
    parser.add_argument('--debug', '-d', action='store_true', 
                       help='Mode debug (logs verbeux)')
    parser.add_argument('--dry-run', '-n', action='store_true', 
                       help='Mode simulation (aucune action)')
    
    args = parser.parse_args()
    
    # Mode debug
    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)
    
    try:
        monitor = ArrMonitor(args.config)
        
        if args.dry_run:
            monitor.logger.info("🧪 Mode simulation activé - aucune action ne sera effectuée")
            # TODO: Implémenter le mode dry-run
        
        if args.test:
            monitor.run_cycle()
        else:
            monitor.run_continuous()
            
    except Exception as e:
        print(f"❌ Erreur fatale : {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
