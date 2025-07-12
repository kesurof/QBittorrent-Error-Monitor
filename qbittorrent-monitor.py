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

USER = 'TEMPLATE_USER'
GROUP = 'TEMPLATE_USER'
HOME_DIR = 'TEMPLATE_HOME'
BASE_DIR = os.path.join(HOME_DIR, 'scripts', 'qbittorrent-monitor')
LOG_DIR = os.path.join(HOME_DIR, 'logs')
CONFIG_BASE_PATH = 'TEMPLATE_CONFIG_PATH'
DOCKER_NETWORK = os.environ.get('DOCKER_NETWORK', 'traefik_proxy')
DOCKER_NETWORK_FALLBACK = 'bridge'

SERVICES_CONFIG = {
    'sonarr': {
        'port': int(os.environ.get('SONARR_PORT', '8989')),
        'api_version': 'v3',
        'container_name': os.environ.get('SONARR_CONTAINER', 'sonarr'),
        'search_command': 'missingEpisodeSearch'
    },
    'radarr': {
        'port': int(os.environ.get('RADARR_PORT', '7878')),
        'api_version': 'v3',
        'container_name': os.environ.get('RADARR_CONTAINER', 'radarr'),
        'search_command': 'MissingMoviesSearch'
    }
}

DOCKER_TIMEOUT = int(os.environ.get('DOCKER_TIMEOUT', '5'))
HTTP_TIMEOUT = int(os.environ.get('HTTP_TIMEOUT', '5'))
ERROR_PATTERNS = [
    "qBittorrent is reporting an error",
    "qBittorrent has returned an error"
]

os.makedirs(LOG_DIR, exist_ok=True)
logging.basicConfig(
    level=getattr(logging, os.environ.get('LOG_LEVEL', 'INFO').upper()),
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(os.path.join(LOG_DIR, 'qbittorrent-error-monitor.log')),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class QBittorrentErrorMonitor:
    def __init__(self, check_interval: int = 300):
        self.check_interval = check_interval
        self.running = True
        self.shutdown_event = threading.Event()
        self.services_config = SERVICES_CONFIG
        self.session = requests.Session()
        self.session.timeout = HTTP_TIMEOUT
        self._api_cache = {}
        
        self.stats = {
            'cycles': 0, 'errors_detected': 0, 'downloads_removed': 0, 
            'searches_triggered': 0, 'start_time': datetime.now().isoformat(),
            'user': USER, 'config_path': CONFIG_BASE_PATH
        }
        
        signal.signal(signal.SIGTERM, self._shutdown)
        signal.signal(signal.SIGINT, self._shutdown)
        
        logger.info(f"🚀 QBittorrent Monitor démarré (intervalle: {check_interval}s)")
        logger.info(f"👤 Utilisateur: {USER}, Config: {CONFIG_BASE_PATH}")
        logger.info(f"🌐 Réseau Docker: {DOCKER_NETWORK}")
    
    def _shutdown(self, signum, frame):
        logger.info("📡 Arrêt demandé")
        self.running = False
        self.shutdown_event.set()
        try:
            self.session.close()
        except:
            pass
        sys.exit(0)
    
    def get_container_ip(self, service: str) -> Optional[str]:
        container_name = self.services_config[service]['container_name']
        
        try:
            cmd = f"timeout {DOCKER_TIMEOUT} docker inspect {container_name} --format='{{{{.NetworkSettings.Networks.{DOCKER_NETWORK}.IPAddress}}}}'"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=DOCKER_TIMEOUT + 2)
            
            if result.returncode == 0 and result.stdout.strip():
                ip = result.stdout.strip()
                logger.debug(f"{service}: IP trouvée via {DOCKER_NETWORK} - {ip}")
                return ip
            
            cmd = f"timeout {DOCKER_TIMEOUT} docker inspect {container_name} --format='{{{{.NetworkSettings.IPAddress}}}}'"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=DOCKER_TIMEOUT + 2)
            
            if result.returncode == 0 and result.stdout.strip():
                ip = result.stdout.strip()
                logger.debug(f"{service}: IP trouvée via {DOCKER_NETWORK_FALLBACK} - {ip}")
                return ip
                
        except Exception as e:
            logger.debug(f"Erreur récupération IP {service}: {e}")
        
        return None
    
    def get_api_key(self, service: str) -> Optional[str]:
        if service in self._api_cache:
            return self._api_cache[service]
        
        try:
            config_path = os.path.join(CONFIG_BASE_PATH, service, 'config', 'config.xml')
            
            if os.path.exists(config_path):
                cmd = f"timeout {DOCKER_TIMEOUT} sed -n 's/.*<ApiKey>\\(.*\\)<\\/ApiKey>.*/\\1/p' '{config_path}'"
                result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=DOCKER_TIMEOUT + 2)
                
                if result.returncode == 0 and result.stdout.strip():
                    api_key = result.stdout.strip()
                    self._api_cache[service] = api_key
                    logger.debug(f"{service}: API key trouvée via {config_path}")
                    return api_key
        except Exception as e:
            logger.debug(f"Erreur récupération API key {service}: {e}")
        
        return None
    
    def get_queue_items(self, service: str) -> List[Dict]:
        if self.shutdown_event.is_set():
            return []
        
        ip = self.get_container_ip(service)
        api_key = self.get_api_key(service)
        
        if not ip or not api_key:
            logger.debug(f"{service}: IP ou API key manquante")
            return []
        
        try:
            config = self.services_config[service]
            url = f"http://{ip}:{config['port']}/api/{config['api_version']}/queue"
            response = self.session.get(url, headers={"X-Api-Key": api_key}, timeout=HTTP_TIMEOUT)
            response.raise_for_status()
            
            data = response.json()
            items = data.get('records', []) if isinstance(data, dict) else data
            logger.debug(f"{service}: {len(items)} éléments dans la queue")
            return items
        except Exception as e:
            logger.debug(f"Erreur récupération queue {service}: {e}")
            return []
    
    def detect_qbittorrent_errors(self, queue_items: List[Dict]) -> List[Dict]:
        errors = []
        for item in queue_items:
            if self.shutdown_event.is_set():
                break
            
            messages = [item.get('errorMessage', '')]
            for status_msg in item.get('statusMessages', []):
                if isinstance(status_msg, dict):
                    msg_list = status_msg.get('messages', [])
                    messages.extend(msg_list if isinstance(msg_list, list) else [str(msg_list)])
                else:
                    messages.append(str(status_msg))
            
            for message in messages:
                if message:
                    for pattern in ERROR_PATTERNS:
                        if pattern.lower() in message.lower():
                            errors.append({
                                'id': item.get('id'),
                                'title': item.get('title', 'Unknown'),
                                'error_pattern': pattern
                            })
                            break
                    if errors and errors[-1]['id'] == item.get('id'):
                        break
        
        return errors
    
    def remove_and_blocklist(self, service: str, item_id: int, title: str) -> bool:
        if self.shutdown_event.is_set():
            return False
        
        ip = self.get_container_ip(service)
        api_key = self.get_api_key(service)
        
        if not ip or not api_key:
            return False
        
        try:
            config = self.services_config[service]
            url = f"http://{ip}:{config['port']}/api/{config['api_version']}/queue/{item_id}"
            params = {'removeFromClient': 'true', 'blocklist': 'true'}
            response = self.session.delete(url, headers={"X-Api-Key": api_key}, params=params, timeout=HTTP_TIMEOUT)
            response.raise_for_status()
            
            logger.info(f"✅ {service}: Supprimé et blocklist - {title}")
            return True
        except Exception as e:
            logger.debug(f"Erreur suppression {service}: {e}")
            return False
    
    def trigger_search(self, service: str) -> bool:
        if self.shutdown_event.is_set():
            return False
        
        ip = self.get_container_ip(service)
        api_key = self.get_api_key(service)
        
        if not ip or not api_key:
            return False
        
        try:
            config = self.services_config[service]
            url = f"http://{ip}:{config['port']}/api/{config['api_version']}/command"
            data = {"name": config['search_command']}
            response = self.session.post(url, headers={"Content-Type": "application/json", "X-Api-Key": api_key}, json=data, timeout=HTTP_TIMEOUT)
            response.raise_for_status()
            
            logger.info(f"🔍 {service}: Recherche de remplacement lancée")
            return True
        except Exception as e:
            logger.debug(f"Erreur recherche {service}: {e}")
            return False
    
    def process_service(self, service: str):
        if self.shutdown_event.is_set():
            return
        
        queue_items = self.get_queue_items(service)
        if not queue_items:
            return
        
        errors = self.detect_qbittorrent_errors(queue_items)
        if not errors:
            return
        
        logger.warning(f"🚨 {service}: {len(errors)} erreur(s) qBittorrent détectée(s)")
        
        removed_count = 0
        for error in errors:
            if self.shutdown_event.is_set():
                break
            
            logger.warning(f"⚠️ {service}: {error['title']} - {error['error_pattern']}")
            
            if self.remove_and_blocklist(service, error['id'], error['title']):
                removed_count += 1
                self.stats['downloads_removed'] += 1
                self.shutdown_event.wait(1)
        
        if removed_count > 0 and not self.shutdown_event.is_set():
            self.shutdown_event.wait(3)
            if self.trigger_search(service):
                self.stats['searches_triggered'] += 1
        
        self.stats['errors_detected'] += len(errors)
    
    def run_cycle(self):
        if self.shutdown_event.is_set():
            return
        
        logger.info("🔄 Cycle de monitoring qBittorrent")
        
        for service in self.services_config.keys():
            if self.shutdown_event.is_set():
                break
            self.process_service(service)
            self.shutdown_event.wait(1)
        
        self.stats['cycles'] += 1
        self.stats['last_check'] = datetime.now().isoformat()
        
        if self.stats['cycles'] % 10 == 0:
            logger.info(f"📊 Stats: Cycles={self.stats['cycles']}, Erreurs={self.stats['errors_detected']}, Supprimés={self.stats['downloads_removed']}")
    
    def run(self):
        logger.info("🎯 Monitoring automatique des erreurs qBittorrent démarré")
        
        try:
            while self.running and not self.shutdown_event.is_set():
                start = time.time()
                self.run_cycle()
                
                try:
                    stats_file = os.path.join(LOG_DIR, 'qbittorrent-stats.json')
                    with open(stats_file, 'w') as f:
                        json.dump(self.stats, f, indent=2)
                except:
                    pass
                
                elapsed = time.time() - start
                sleep_time = max(0, self.check_interval - elapsed)
                if sleep_time > 0:
                    logger.debug(f"⏳ Attente {sleep_time:.1f}s avant le prochain cycle")
                    self.shutdown_event.wait(sleep_time)
                    
        except Exception as e:
            logger.error(f"❌ Erreur fatale: {e}")
        finally:
            logger.info("🛑 Monitoring arrêté")
            try:
                self.session.close()
            except:
                pass

def main():
    parser = argparse.ArgumentParser(description='QBittorrent Error Monitor - Automatisé')
    parser.add_argument('--interval', '-i', type=int, default=int(os.environ.get('CHECK_INTERVAL', '300')), 
                       help='Intervalle de vérification en secondes')
    parser.add_argument('--verbose', '-v', action='store_true', help='Mode verbose (debug)')
    parser.add_argument('--test', '-t', action='store_true', help='Mode test (un seul cycle)')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    monitor = QBittorrentErrorMonitor(check_interval=args.interval)
    
    if args.test:
        logger.info("🧪 Mode test - un seul cycle")
        monitor.run_cycle()
        try:
            stats_file = os.path.join(LOG_DIR, 'qbittorrent-stats.json')
            with open(stats_file, 'w') as f:
                json.dump(monitor.stats, f, indent=2)
        except:
            pass
    else:
        monitor.run()

if __name__ == "__main__":
    main()
