#!/usr/bin/env python3

import os
import subprocess
import json
import time
import logging
import argparse
from datetime import datetime
from typing import Dict, List, Optional
import requests
import signal
import sys
import threading
import yaml
from pathlib import Path

class QBittorrentErrorMonitor:
    def __init__(self, config_file='/config/config.yaml'):
        self.config_file = config_file
        self.config = self.load_config()
        self.running = True
        self.shutdown_event = threading.Event()
        
        # Configuration des logs
        self.setup_logging()
        
        # Session HTTP avec retry
        self.session = requests.Session()
        retry_strategy = requests.adapters.Retry(
            total=3,
            backoff_factor=1,
            status_forcelist=[429, 500, 502, 503, 504]
        )
        adapter = requests.adapters.HTTPAdapter(max_retries=retry_strategy)
        self.session.mount("http://", adapter)
        self.session.mount("https://", adapter)
        
        # Cache pour les API keys et IPs
        self._api_cache = {}
        self._ip_cache = {}
        
        # Statistiques
        self.stats = {
            'cycles': 0,
            'errors_detected': 0,
            'downloads_removed': 0,
            'searches_triggered': 0,
            'start_time': datetime.now().isoformat(),
            'last_check': None
        }
        
        # Gestion des signaux
        signal.signal(signal.SIGTERM, self._shutdown)
        signal.signal(signal.SIGINT, self._shutdown)
        
        self.logger.info("🚀 QBittorrent Error Monitor démarré")
        self.logger.info(f"📋 Services configurés: {list(self.config.get('services', {}).keys())}")

    def load_config(self):
        """Charge la configuration depuis le fichier YAML ou utilise les valeurs par défaut"""
        default_config = {
            'monitor': {
                'check_interval': int(os.environ.get('CHECK_INTERVAL', '300')),
                'log_level': os.environ.get('LOG_LEVEL', 'INFO'),
                'dry_run': os.environ.get('DRY_RUN', 'false').lower() == 'true',
                'timezone': os.environ.get('TZ', 'Europe/Paris')
            },
            'docker': {
                'network': os.environ.get('DOCKER_NETWORK', 'traefik_proxy'),
                'socket_path': '/var/run/docker.sock'
            },
            'services': {
                'sonarr': {
                    'enabled': True,
                    'port': 8989,
                    'api_version': 'v3',
                    'container_names': ['sonarr'],
                    'config_paths': ['/configs/sonarr/config'],
                    'search_command': 'missingEpisodeSearch'
                },
                'radarr': {
                    'enabled': True,
                    'port': 7878,
                    'api_version': 'v3',
                    'container_names': ['radarr'],
                    'config_paths': ['/configs/radarr/config'],
                    'search_command': 'MissingMoviesSearch'
                }
            },
            'error_patterns': [
                "qBittorrent is reporting an error",
                "qBittorrent has returned an error",
                "Connection to qBittorrent failed",
                "qbittorrent error",
                "torrent client error"
            ],
            'logging': {
                'file_path': '/config/logs/qbittorrent-monitor.log',
                'max_size_mb': 50,
                'backup_count': 5
            }
        }
        
        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, 'r') as f:
                    file_config = yaml.safe_load(f)
                    # Merge configurations
                    return self._merge_config(default_config, file_config)
            except Exception as e:
                print(f"Erreur lecture config {self.config_file}: {e}")
        
        return default_config

    def _merge_config(self, default, override):
        """Fusionne récursivement les configurations"""
        for key, value in override.items():
            if key in default and isinstance(default[key], dict) and isinstance(value, dict):
                default[key] = self._merge_config(default[key], value)
            else:
                default[key] = value
        return default

    def setup_logging(self):
        """Configure le système de logging"""
        log_config = self.config.get('logging', {})
        log_level = self.config.get('monitor', {}).get('log_level', 'INFO')
        
        # Créer le répertoire de logs
        log_file = log_config.get('file_path', '/config/logs/qbittorrent-monitor.log')
        os.makedirs(os.path.dirname(log_file), exist_ok=True)
        
        # Configuration du logger
        logging.basicConfig(
            level=getattr(logging, log_level.upper()),
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)

    def _shutdown(self, signum, frame):
        """Gestion propre de l'arrêt"""
        self.logger.info("📡 Arrêt demandé")
        self.running = False
        self.shutdown_event.set()
        self.session.close()
        sys.exit(0)

    def get_container_ip(self, service_name: str) -> Optional[str]:
        """Récupère l'IP d'un conteneur via Docker"""
        if service_name in self._ip_cache:
            return self._ip_cache[service_name]
        
        service_config = self.config.get('services', {}).get(service_name, {})
        container_names = service_config.get('container_names', [service_name])
        network = self.config.get('docker', {}).get('network', 'traefik_proxy')
        
        for container_name in container_names:
            try:
                # Essayer d'abord le réseau principal
                cmd = [
                    'docker', 'inspect', container_name,
                    '--format', f'{{{{.NetworkSettings.Networks.{network}.IPAddress}}}}'
                ]
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
                
                if result.returncode == 0 and result.stdout.strip():
                    ip = result.stdout.strip()
                    self._ip_cache[service_name] = ip
                    self.logger.debug(f"{service_name}: IP trouvée {ip} (réseau {network})")
                    return ip
                
                # Fallback sur l'IP par défaut
                cmd = [
                    'docker', 'inspect', container_name,
                    '--format', '{{.NetworkSettings.IPAddress}}'
                ]
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
                
                if result.returncode == 0 and result.stdout.strip():
                    ip = result.stdout.strip()
                    self._ip_cache[service_name] = ip
                    self.logger.debug(f"{service_name}: IP trouvée {ip} (réseau par défaut)")
                    return ip
                    
            except Exception as e:
                self.logger.debug(f"Erreur IP pour {container_name}: {e}")
                continue
        
        self.logger.warning(f"{service_name}: Conteneur non trouvé")
        return None

    def get_api_key(self, service_name: str) -> Optional[str]:
        """Récupère la clé API depuis le fichier de configuration"""
        if service_name in self._api_cache:
            return self._api_cache[service_name]
        
        service_config = self.config.get('services', {}).get(service_name, {})
        config_paths = service_config.get('config_paths', [])
        
        for config_path in config_paths:
            config_file = os.path.join(config_path, 'config.xml')
            if os.path.exists(config_file):
                try:
                    cmd = ['grep', '-oP', '<ApiKey>\\K[^<]+', config_file]
                    result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
                    
                    if result.returncode == 0 and result.stdout.strip():
                        api_key = result.stdout.strip()
                        self._api_cache[service_name] = api_key
                        self.logger.debug(f"{service_name}: API key trouvée")
                        return api_key
                        
                except Exception as e:
                    self.logger.debug(f"Erreur API key {config_file}: {e}")
                    continue
        
        self.logger.warning(f"{service_name}: API key non trouvée")
        return None

    def get_queue_items(self, service_name: str) -> List[Dict]:
        """Récupère les éléments de la queue"""
        if self.shutdown_event.is_set():
            return []
        
        ip = self.get_container_ip(service_name)
        api_key = self.get_api_key(service_name)
        
        if not ip or not api_key:
            return []
        
        service_config = self.config.get('services', {}).get(service_name, {})
        port = service_config.get('port', 8989)
        api_version = service_config.get('api_version', 'v3')
        
        try:
            url = f"http://{ip}:{port}/api/{api_version}/queue"
            headers = {"X-Api-Key": api_key}
            
            response = self.session.get(url, headers=headers, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            items = data.get('records', []) if isinstance(data, dict) else data
            
            self.logger.debug(f"{service_name}: {len(items)} éléments dans la queue")
            return items
            
        except Exception as e:
            self.logger.debug(f"Erreur queue {service_name}: {e}")
            return []

    def detect_qbittorrent_errors(self, queue_items: List[Dict]) -> List[Dict]:
        """Détecte les erreurs qBittorrent dans la queue"""
        errors = []
        error_patterns = self.config.get('error_patterns', [])
        
        for item in queue_items:
            if self.shutdown_event.is_set():
                break
            
            # Collecter tous les messages d'erreur
            messages = []
            
            # Message d'erreur principal
            if item.get('errorMessage'):
                messages.append(item.get('errorMessage'))
            
            # Messages de statut
            for status_msg in item.get('statusMessages', []):
                if isinstance(status_msg, dict):
                    msg_list = status_msg.get('messages', [])
                    if isinstance(msg_list, list):
                        messages.extend(msg_list)
                    else:
                        messages.append(str(msg_list))
                else:
                    messages.append(str(status_msg))
            
            # Vérifier les patterns d'erreur
            for message in messages:
                if message:
                    for pattern in error_patterns:
                        if pattern.lower() in message.lower():
                            errors.append({
                                'id': item.get('id'),
                                'title': item.get('title', 'Unknown'),
                                'error_message': message,
                                'error_pattern': pattern
                            })
                            break
                    if errors and errors[-1]['id'] == item.get('id'):
                        break
        
        return errors

    def remove_and_blocklist(self, service_name: str, item_id: int, title: str) -> bool:
        """Supprime un téléchargement et l'ajoute à la blocklist"""
        if self.shutdown_event.is_set() or self.config.get('monitor', {}).get('dry_run', False):
            self.logger.info(f"🔄 [DRY RUN] {service_name}: Suppression simulée - {title}")
            return True
        
        ip = self.get_container_ip(service_name)
        api_key = self.get_api_key(service_name)
        
        if not ip or not api_key:
            return False
        
        service_config = self.config.get('services', {}).get(service_name, {})
        port = service_config.get('port', 8989)
        api_version = service_config.get('api_version', 'v3')
        
        try:
            url = f"http://{ip}:{port}/api/{api_version}/queue/{item_id}"
            headers = {"X-Api-Key": api_key}
            params = {'removeFromClient': 'true', 'blocklist': 'true'}
            
            response = self.session.delete(url, headers=headers, params=params, timeout=10)
            response.raise_for_status()
            
            self.logger.info(f"✅ {service_name}: Supprimé et blacklisté - {title}")
            return True
            
        except Exception as e:
            self.logger.error(f"❌ Erreur suppression {service_name}: {e}")
            return False

    def trigger_search(self, service_name: str) -> bool:
        """Lance une recherche de remplacement"""
        if self.shutdown_event.is_set() or self.config.get('monitor', {}).get('dry_run', False):
            self.logger.info(f"🔄 [DRY RUN] {service_name}: Recherche simulée")
            return True
        
        ip = self.get_container_ip(service_name)
        api_key = self.get_api_key(service_name)
        
        if not ip or not api_key:
            return False
        
        service_config = self.config.get('services', {}).get(service_name, {})
        port = service_config.get('port', 8989)
        api_version = service_config.get('api_version', 'v3')
        search_command = service_config.get('search_command', 'missingEpisodeSearch')
        
        try:
            url = f"http://{ip}:{port}/api/{api_version}/command"
            headers = {"Content-Type": "application/json", "X-Api-Key": api_key}
            data = {"name": search_command}
            
            response = self.session.post(url, headers=headers, json=data, timeout=10)
            response.raise_for_status()
            
            self.logger.info(f"🔍 {service_name}: Recherche de remplacement lancée")
            return True
            
        except Exception as e:
            self.logger.error(f"❌ Erreur recherche {service_name}: {e}")
            return False

    def process_service(self, service_name: str):
        """Traite un service (Sonarr/Radarr)"""
        if self.shutdown_event.is_set():
            return
        
        service_config = self.config.get('services', {}).get(service_name, {})
        if not service_config.get('enabled', True):
            return
        
        # Récupérer la queue
        queue_items = self.get_queue_items(service_name)
        if not queue_items:
            return
        
        # Détecter les erreurs
        errors = self.detect_qbittorrent_errors(queue_items)
        if not errors:
            return
        
        self.logger.warning(f"🚨 {service_name}: {len(errors)} erreur(s) qBittorrent détectée(s)")
        
        # Traiter chaque erreur
        removed_count = 0
        for error in errors:
            if self.shutdown_event.is_set():
                break
            
            self.logger.warning(f"⚠️ {service_name}: {error['title']} - {error['error_pattern']}")
            
            # Supprimer et blacklister
            if self.remove_and_blocklist(service_name, error['id'], error['title']):
                removed_count += 1
                self.stats['downloads_removed'] += 1
                # Petite pause entre les suppressions
                self.shutdown_event.wait(1)
        
        # Lancer une recherche si des éléments ont été supprimés
        if removed_count > 0 and not self.shutdown_event.is_set():
            self.shutdown_event.wait(3)  # Attendre un peu
            if self.trigger_search(service_name):
                self.stats['searches_triggered'] += 1
        
        self.stats['errors_detected'] += len(errors)

    def run_cycle(self):
        """Exécute un cycle de monitoring"""
        if self.shutdown_event.is_set():
            return
        
        self.logger.info("🔄 Cycle de monitoring qBittorrent")
        
        services = self.config.get('services', {})
        for service_name in services.keys():
            if self.shutdown_event.is_set():
                break
            self.process_service(service_name)
            # Petite pause entre les services
            self.shutdown_event.wait(1)
        
        # Mettre à jour les statistiques
        self.stats['cycles'] += 1
        self.stats['last_check'] = datetime.now().isoformat()
        
        # Log périodique des stats
        if self.stats['cycles'] % 10 == 0:
            self.logger.info(
                f"📊 Stats: Cycles={self.stats['cycles']}, "
                f"Erreurs={self.stats['errors_detected']}, "
                f"Supprimés={self.stats['downloads_removed']}, "
                f"Recherches={self.stats['searches_triggered']}"
            )

    def run(self):
        """Boucle principale du monitoring"""
        check_interval = self.config.get('monitor', {}).get('check_interval', 300)
        
        self.logger.info("🎯 Monitoring automatique des erreurs qBittorrent démarré")
        self.logger.info(f"⏱️ Intervalle: {check_interval}s")
        
        try:
            while self.running and not self.shutdown_event.is_set():
                start_time = time.time()
                
                self.run_cycle()
                
                # Sauvegarder les stats
                try:
                    stats_file = '/config/logs/qbittorrent-stats.json'
                    with open(stats_file, 'w') as f:
                        json.dump(self.stats, f, indent=2)
                except Exception as e:
                    self.logger.debug(f"Erreur sauvegarde stats: {e}")
                
                # Calculer le temps d'attente
                elapsed = time.time() - start_time
                sleep_time = max(0, check_interval - elapsed)
                
                if sleep_time > 0:
                    self.logger.debug(f"⏳ Attente {sleep_time:.1f}s avant le prochain cycle")
                    self.shutdown_event.wait(sleep_time)
                    
        except Exception as e:
            self.logger.error(f"❌ Erreur fatale: {e}")
        finally:
            self.logger.info("🛑 Monitoring arrêté")
            self.session.close()

def main():
    parser = argparse.ArgumentParser(description='QBittorrent Error Monitor pour ssdv2')
    parser.add_argument('--config', '-c', default='/config/config.yaml',
                       help='Fichier de configuration YAML')
    parser.add_argument('--interval', '-i', type=int,
                       help='Intervalle de vérification en secondes')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Mode verbose (debug)')
    parser.add_argument('--test', '-t', action='store_true',
                       help='Mode test (un seul cycle)')
    parser.add_argument('--dry-run', '-d', action='store_true',
                       help='Mode simulation (pas d\'actions réelles)')
    parser.add_argument('--health-check', action='store_true',
                       help='Test de santé du service')
    
    args = parser.parse_args()
    
    # Test de santé simple
    if args.health_check:
        try:
            # Vérifier que les répertoires existent
            if not os.path.exists('/config/logs'):
                print("❌ Répertoire logs manquant")
                sys.exit(1)
            if not os.path.exists('/config'):
                print("❌ Répertoire config manquant")
                sys.exit(1)
            print("✅ Health check OK")
            sys.exit(0)
        except Exception as e:
            print(f"❌ Health check failed: {e}")
            sys.exit(1)
    
    # Créer le monitor
    monitor = QBittorrentErrorMonitor(config_file=args.config)
    
    # Overrides depuis les arguments
    if args.interval:
        monitor.config['monitor']['check_interval'] = args.interval
    if args.dry_run:
        monitor.config['monitor']['dry_run'] = True
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
        monitor.logger.setLevel(logging.DEBUG)
    
    # Mode test ou run continu
    if args.test:
        monitor.logger.info("🧪 Mode test - un seul cycle")
        monitor.run_cycle()
        # Sauvegarder les stats
        try:
            stats_file = '/config/logs/qbittorrent-stats.json'
            with open(stats_file, 'w') as f:
                json.dump(monitor.stats, f, indent=2)
            monitor.logger.info(f"📊 Statistiques sauvegardées: {stats_file}")
        except Exception as e:
            monitor.logger.error(f"Erreur sauvegarde: {e}")
    else:
        monitor.run()

if __name__ == "__main__":
    main()
