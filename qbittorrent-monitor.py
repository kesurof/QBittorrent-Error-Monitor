#!/usr/bin/env python3

import os
import subprocess
import json
import time
import logging
import logging.handlers
import argparse
import yaml
import re
import shlex
import hashlib
from datetime import datetime
from typing import Dict, List, Optional, Union
from pathlib import Path
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import signal
import sys
import threading
from dataclasses import dataclass, field

# Configuration par défaut (peut être surchargée par config.yaml)
@dataclass
class Config:
    # Variables de base (remplacées par setup.sh)
    user: str = 'TEMPLATE_USER'
    group: str = 'TEMPLATE_USER'
    home_dir: str = 'TEMPLATE_HOME'
    config_base_path: str = 'TEMPLATE_CONFIG_PATH'
    
    # Configuration générale
    check_interval: int = 300
    log_level: str = "INFO"
    max_retries: int = 3
    retry_backoff: float = 2.0
    dry_run: bool = False
    
    # Configuration Docker
    docker_network: str = "traefik_proxy"
    docker_network_fallback: str = "bridge"
    docker_timeout: int = 5
    container_timeout: int = 10
    
    # Configuration HTTP
    http_timeout: int = 5
    user_agent: str = "QBittorrent-Monitor/2.0"
    max_connections: int = 10
    
    # Configuration sécurité
    validate_paths: bool = True
    sanitize_inputs: bool = True
    max_path_length: int = 4096
    allowed_user_chars: str = r"^[a-zA-Z0-9._-]+$"
    
    # Patterns d'erreurs
    error_patterns: List[str] = field(default_factory=lambda: [
        "qBittorrent is reporting an error",
        "qBittorrent has returned an error",
        "Connection to qBittorrent failed"
    ])
    
    # Services
    services: Dict[str, Dict] = field(default_factory=lambda: {
        'sonarr': {
            'enabled': True,
            'port': 8989,
            'api_version': 'v3',
            'container_name': 'sonarr',
            'search_command': 'missingEpisodeSearch',
            'max_errors_per_cycle': 10
        },
        'radarr': {
            'enabled': True,
            'port': 7878,
            'api_version': 'v3',
            'container_name': 'radarr',
            'search_command': 'MissingMoviesSearch',
            'max_errors_per_cycle': 10
        }
    })

class SecurityError(Exception):
    """Exception levée pour les problèmes de sécurité"""
    pass

class ConfigurationError(Exception):
    """Exception levée pour les problèmes de configuration"""
    pass

class SecurityValidator:
    """Classe pour valider et sécuriser les entrées"""
    
    @staticmethod
    def validate_user_input(value: str, max_length: int = 256) -> bool:
        """Valide les entrées utilisateur"""
        if not isinstance(value, str):
            return False
        if len(value) > max_length:
            return False
        # Autorise seulement les caractères alphanumériques, points, tirets et underscores
        return bool(re.match(r'^[a-zA-Z0-9._-]+$', value))
    
    @staticmethod
    def validate_path(path: str, max_length: int = 4096) -> bool:
        """Valide les chemins de fichiers"""
        if not isinstance(path, str):
            return False
        if len(path) > max_length:
            return False
        # Vérifie qu'il n'y a pas de tentatives de traversal
        if '..' in path or path.startswith('/'):
            return False
        return True
    
    @staticmethod
    def escape_for_command(value: str) -> str:
        """Échappe une valeur pour l'utilisation en ligne de commande"""
        if not SecurityValidator.validate_user_input(value):
            raise SecurityError(f"Valeur non valide pour échappement: {value}")
        return shlex.quote(value)
    
    @staticmethod
    def sanitize_container_name(name: str) -> str:
        """Assainit un nom de conteneur"""
        if not SecurityValidator.validate_user_input(name):
            raise SecurityError(f"Nom de conteneur non valide: {name}")
        return name

class ConfigManager:
    """Gestionnaire de configuration centralisé"""
    
    def __init__(self, config_file: Optional[str] = None):
        self.config = Config()
        if config_file and os.path.exists(config_file):
            self.load_config_file(config_file)
        self.load_environment_variables()
    
    def load_config_file(self, config_file: str):
        """Charge la configuration depuis un fichier YAML"""
        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                config_data = yaml.safe_load(f)
            
            if config_data:
                self._update_config_from_dict(config_data)
        except Exception as e:
            logging.warning(f"Impossible de charger le fichier de config {config_file}: {e}")
    
    def load_environment_variables(self):
        """Charge les variables d'environnement"""
        env_mappings = {
            'CHECK_INTERVAL': ('check_interval', int),
            'LOG_LEVEL': ('log_level', str),
            'DOCKER_NETWORK': ('docker_network', str),
            'DOCKER_TIMEOUT': ('docker_timeout', int),
            'HTTP_TIMEOUT': ('http_timeout', int),
            'DRY_RUN': ('dry_run', lambda x: x.lower() in ('true', '1', 'yes')),
        }
        
        for env_var, (attr_name, converter) in env_mappings.items():
            value = os.environ.get(env_var)
            if value is not None:
                try:
                    setattr(self.config, attr_name, converter(value))
                except ValueError as e:
                    logging.warning(f"Variable d'environnement invalide {env_var}={value}: {e}")
    
    def _update_config_from_dict(self, config_dict: dict):
        """Met à jour la configuration depuis un dictionnaire"""
        for section, values in config_dict.items():
            if section == 'general' and isinstance(values, dict):
                for key, value in values.items():
                    if hasattr(self.config, key):
                        setattr(self.config, key, value)
            elif section == 'docker' and isinstance(values, dict):
                for key, value in values.items():
                    attr_name = f"docker_{key}" if key != 'network' else 'docker_network'
                    if hasattr(self.config, attr_name):
                        setattr(self.config, attr_name, value)
            elif section == 'http' and isinstance(values, dict):
                for key, value in values.items():
                    attr_name = f"http_{key}" if key != 'timeout' else 'http_timeout'
                    if hasattr(self.config, attr_name):
                        setattr(self.config, attr_name, value)
            elif section == 'security' and isinstance(values, dict):
                for key, value in values.items():
                    if hasattr(self.config, key):
                        setattr(self.config, key, value)
            elif section == 'error_patterns' and isinstance(values, list):
                self.config.error_patterns = values
            elif section == 'services' and isinstance(values, dict):
                self.config.services = values

class RetryableSession:
    """Session HTTP avec retry automatique et sécurité renforcée"""
    
    def __init__(self, config: Config):
        self.config = config
        self.session = requests.Session()
        
        # Configuration des retries avec backoff exponentiel
        retry_strategy = Retry(
            total=config.max_retries,
            backoff_factor=config.retry_backoff,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["HEAD", "GET", "POST", "PUT", "DELETE"]
        )
        
        adapter = HTTPAdapter(
            max_retries=retry_strategy,
            pool_connections=config.max_connections,
            pool_maxsize=config.max_connections
        )
        
        self.session.mount("http://", adapter)
        self.session.mount("https://", adapter)
        self.session.headers.update({'User-Agent': config.user_agent})
    
    def get(self, url: str, **kwargs) -> requests.Response:
        """GET sécurisé avec timeout"""
        kwargs.setdefault('timeout', self.config.http_timeout)
        return self.session.get(url, **kwargs)
    
    def post(self, url: str, **kwargs) -> requests.Response:
        """POST sécurisé avec timeout"""
        kwargs.setdefault('timeout', self.config.http_timeout)
        return self.session.post(url, **kwargs)
    
    def delete(self, url: str, **kwargs) -> requests.Response:
        """DELETE sécurisé avec timeout"""
        kwargs.setdefault('timeout', self.config.http_timeout)
        return self.session.delete(url, **kwargs)
    
    def close(self):
        """Ferme la session"""
        self.session.close()

def setup_logging(config: Config) -> logging.Logger:
    """Configure le système de logging avec rotation"""
    base_dir = os.path.join(config.home_dir, 'scripts', 'qbittorrent-monitor')
    log_dir = os.path.join(config.home_dir, 'logs')
    
    # Création des répertoires
    os.makedirs(log_dir, exist_ok=True)
    os.makedirs(base_dir, exist_ok=True)
    
    # Configuration du logger
    logger = logging.getLogger(__name__)
    logger.setLevel(getattr(logging, config.log_level.upper()))
    
    # Handler pour fichier avec rotation
    log_file = os.path.join(log_dir, 'qbittorrent-error-monitor.log')
    file_handler = logging.handlers.RotatingFileHandler(
        log_file, 
        maxBytes=10*1024*1024,  # 10MB
        backupCount=5,
        encoding='utf-8'
    )
    
    # Handler pour console
    console_handler = logging.StreamHandler()
    
    # Formateur
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    file_handler.setFormatter(formatter)
    console_handler.setFormatter(formatter)
    
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    
    return logger

class QBittorrentErrorMonitor:
    """Moniteur d'erreurs qBittorrent sécurisé et robuste"""
    
    def __init__(self, config: Config, logger: logging.Logger):
        self.config = config
        self.logger = logger
        self.running = True
        self.shutdown_event = threading.Event()
        self.session = RetryableSession(config)
        self._api_cache = {}
        self._security = SecurityValidator()
        
        # Statistiques améliorées
        self.stats = {
            'cycles': 0,
            'errors_detected': 0,
            'downloads_removed': 0,
            'searches_triggered': 0,
            'start_time': datetime.now().isoformat(),
            'last_check': None,
            'user': config.user,
            'config_path': config.config_base_path,
            'dry_run_mode': config.dry_run,
            'services_enabled': {name: svc.get('enabled', True) for name, svc in config.services.items()},
            'errors_by_service': {},
            'performance_metrics': {}
        }
        
        # Gestion des signaux
        signal.signal(signal.SIGTERM, self._shutdown)
        signal.signal(signal.SIGINT, self._shutdown)
        
        self.logger.info(f"🚀 QBittorrent Monitor démarré (intervalle: {config.check_interval}s)")
        self.logger.info(f"👤 Utilisateur: {config.user}, Config: {config.config_base_path}")
        self.logger.info(f"🌐 Réseau Docker: {config.docker_network}")
        if config.dry_run:
            self.logger.warning("🧪 MODE DRY-RUN ACTIVÉ - Aucune action ne sera effectuée")
    
    def _shutdown(self, signum, frame):
        """Arrêt propre du service"""
        self.logger.info("📡 Arrêt demandé")
        self.running = False
        self.shutdown_event.set()
        try:
            self.session.close()
        except Exception:
            pass
        sys.exit(0)
    
    def _execute_secure_command(self, cmd_parts: List[str], timeout: int = None) -> Optional[str]:
        """Exécute une commande de manière sécurisée sans shell=True"""
        if timeout is None:
            timeout = self.config.docker_timeout
        
        try:
            result = subprocess.run(
                cmd_parts,
                capture_output=True,
                text=True,
                timeout=timeout + 2,
                check=False
            )
            
            if result.returncode == 0 and result.stdout.strip():
                return result.stdout.strip()
        except subprocess.TimeoutExpired:
            self.logger.debug(f"Timeout lors de l'exécution de: {' '.join(cmd_parts)}")
        except Exception as e:
            self.logger.debug(f"Erreur lors de l'exécution de commande: {e}")
        
        return None
    
    def get_container_ip(self, service: str) -> Optional[str]:
        """Récupère l'IP d'un conteneur de manière sécurisée"""
        if service not in self.config.services:
            return None
        
        container_name = self.config.services[service].get('container_name', service)
        
        # Validation du nom de conteneur
        try:
            container_name = self._security.sanitize_container_name(container_name)
        except SecurityError as e:
            self.logger.error(f"Nom de conteneur non valide pour {service}: {e}")
            return None
        
        # Essai avec le réseau principal
        cmd_parts = [
            'timeout', str(self.config.docker_timeout),
            'docker', 'inspect', container_name,
            '--format={{.NetworkSettings.Networks.' + self.config.docker_network + '.IPAddress}}'
        ]
        
        ip = self._execute_secure_command(cmd_parts)
        if ip:
            self.logger.debug(f"{service}: IP trouvée via {self.config.docker_network} - {ip}")
            return ip
        
        # Essai avec le réseau de fallback
        cmd_parts = [
            'timeout', str(self.config.docker_timeout),
            'docker', 'inspect', container_name,
            '--format={{.NetworkSettings.IPAddress}}'
        ]
        
        ip = self._execute_secure_command(cmd_parts)
        if ip:
            self.logger.debug(f"{service}: IP trouvée via {self.config.docker_network_fallback} - {ip}")
            return ip
        
        return None
    
    def get_api_key(self, service: str) -> Optional[str]:
        """Récupère la clé API de manière sécurisée"""
        if service in self._api_cache:
            return self._api_cache[service]
        
        if service not in self.config.services:
            return None
        
        try:
            config_path = os.path.join(self.config.config_base_path, service, 'config', 'config.xml')
            
            # Validation du chemin
            if not os.path.exists(config_path):
                self.logger.debug(f"Fichier de config non trouvé: {config_path}")
                return None
            
            # Lecture sécurisée du fichier XML
            cmd_parts = [
                'timeout', str(self.config.docker_timeout),
                'sed', '-n', 's/.*<ApiKey>\\(.*\\)<\\/ApiKey>.*/\\1/p', config_path
            ]
            
            api_key = self._execute_secure_command(cmd_parts)
            if api_key:
                # Validation basique de la clé API
                if len(api_key) >= 16 and all(c.isalnum() for c in api_key):
                    self._api_cache[service] = api_key
                    self.logger.debug(f"{service}: API key trouvée via {config_path}")
                    return api_key
        except Exception as e:
            self.logger.debug(f"Erreur récupération API key {service}: {e}")
        
        return None
    
    def get_queue_items(self, service: str) -> List[Dict]:
        """Récupère les éléments en queue de manière sécurisée"""
        if self.shutdown_event.is_set():
            return []
        
        if not self.config.services.get(service, {}).get('enabled', True):
            return []
        
        start_time = time.time()
        
        ip = self.get_container_ip(service)
        api_key = self.get_api_key(service)
        
        if not ip or not api_key:
            self.logger.debug(f"{service}: IP ou API key manquante")
            return []
        
        try:
            service_config = self.config.services[service]
            url = f"http://{ip}:{service_config['port']}/api/{service_config['api_version']}/queue"
            
            headers = {"X-Api-Key": api_key}
            response = self.session.get(url, headers=headers)
            response.raise_for_status()
            
            data = response.json()
            items = data.get('records', []) if isinstance(data, dict) else data
            
            # Métriques de performance
            elapsed = time.time() - start_time
            if service not in self.stats['performance_metrics']:
                self.stats['performance_metrics'][service] = []
            self.stats['performance_metrics'][service].append({
                'operation': 'get_queue',
                'duration': elapsed,
                'timestamp': datetime.now().isoformat()
            })
            
            self.logger.debug(f"{service}: {len(items)} éléments dans la queue ({elapsed:.2f}s)")
            return items if isinstance(items, list) else []
            
        except Exception as e:
            self.logger.debug(f"Erreur récupération queue {service}: {e}")
            return []
    
    def detect_qbittorrent_errors(self, queue_items: List[Dict]) -> List[Dict]:
        """Détecte les erreurs qBittorrent avec patterns configurables"""
        errors = []
        
        for item in queue_items:
            if self.shutdown_event.is_set():
                break
            
            # Collecte tous les messages d'erreur possibles
            messages = []
            
            # Message d'erreur principal
            if 'errorMessage' in item and item['errorMessage']:
                messages.append(str(item['errorMessage']))
            
            # Messages de statut
            if 'statusMessages' in item:
                status_msgs = item['statusMessages']
                if isinstance(status_msgs, list):
                    for msg in status_msgs:
                        if isinstance(msg, dict) and 'messages' in msg:
                            msg_list = msg['messages']
                            if isinstance(msg_list, list):
                                messages.extend([str(m) for m in msg_list])
                            else:
                                messages.append(str(msg_list))
                        else:
                            messages.append(str(msg))
            
            # Recherche des patterns d'erreur
            for message in messages:
                if not message:
                    continue
                
                for pattern in self.config.error_patterns:
                    if pattern.lower() in message.lower():
                        error_info = {
                            'id': item.get('id'),
                            'title': item.get('title', 'Unknown'),
                            'error_pattern': pattern,
                            'full_message': message,
                            'detection_time': datetime.now().isoformat()
                        }
                        errors.append(error_info)
                        # Un seul pattern par item suffit
                        break
                
                # Si on a déjà trouvé une erreur pour cet item, on passe au suivant
                if errors and errors[-1]['id'] == item.get('id'):
                    break
        
        return errors
    
    def remove_and_blocklist(self, service: str, item_id: int, title: str) -> bool:
        """Supprime et ajoute à la blocklist de manière sécurisée"""
        if self.shutdown_event.is_set():
            return False
        
        if self.config.dry_run:
            self.logger.info(f"🧪 DRY-RUN: {service}: Suppression et blocklist simulée - {title}")
            return True
        
        ip = self.get_container_ip(service)
        api_key = self.get_api_key(service)
        
        if not ip or not api_key:
            return False
        
        try:
            service_config = self.config.services[service]
            url = f"http://{ip}:{service_config['port']}/api/{service_config['api_version']}/queue/{item_id}"
            params = {'removeFromClient': 'true', 'blocklist': 'true'}
            headers = {"X-Api-Key": api_key}
            
            response = self.session.delete(url, headers=headers, params=params)
            response.raise_for_status()
            
            self.logger.info(f"✅ {service}: Supprimé et blocklist - {title}")
            return True
            
        except Exception as e:
            self.logger.warning(f"Erreur suppression {service} (ID: {item_id}): {e}")
            return False
    
    def trigger_search(self, service: str) -> bool:
        """Lance une recherche de remplacement de manière sécurisée"""
        if self.shutdown_event.is_set():
            return False
        
        if self.config.dry_run:
            self.logger.info(f"🧪 DRY-RUN: {service}: Recherche de remplacement simulée")
            return True
        
        ip = self.get_container_ip(service)
        api_key = self.get_api_key(service)
        
        if not ip or not api_key:
            return False
        
        try:
            service_config = self.config.services[service]
            url = f"http://{ip}:{service_config['port']}/api/{service_config['api_version']}/command"
            
            data = {"name": service_config['search_command']}
            headers = {
                "Content-Type": "application/json",
                "X-Api-Key": api_key
            }
            
            response = self.session.post(url, headers=headers, json=data)
            response.raise_for_status()
            
            self.logger.info(f"🔍 {service}: Recherche de remplacement lancée")
            return True
            
        except Exception as e:
            self.logger.warning(f"Erreur recherche {service}: {e}")
            return False
    
    def process_service(self, service: str):
        """Traite les erreurs pour un service donné"""
        if self.shutdown_event.is_set():
            return
        
        if service not in self.stats['errors_by_service']:
            self.stats['errors_by_service'][service] = 0
        
        queue_items = self.get_queue_items(service)
        if not queue_items:
            return
        
        errors = self.detect_qbittorrent_errors(queue_items)
        if not errors:
            return
        
        # Limite le nombre d'erreurs traitées par cycle
        max_errors = self.config.services.get(service, {}).get('max_errors_per_cycle', 10)
        errors = errors[:max_errors]
        
        self.logger.warning(f"🚨 {service}: {len(errors)} erreur(s) qBittorrent détectée(s)")
        
        removed_count = 0
        for error in errors:
            if self.shutdown_event.is_set():
                break
            
            self.logger.warning(f"⚠️ {service}: {error['title']} - {error['error_pattern']}")
            
            if self.remove_and_blocklist(service, error['id'], error['title']):
                removed_count += 1
                self.stats['downloads_removed'] += 1
                # Délai entre les suppressions pour éviter la surcharge
                if not self.config.dry_run:
                    self.shutdown_event.wait(1)
        
        # Lance une recherche de remplacement si des éléments ont été supprimés
        if removed_count > 0 and not self.shutdown_event.is_set():
            if not self.config.dry_run:
                self.shutdown_event.wait(3)  # Délai avant la recherche
            
            if self.trigger_search(service):
                self.stats['searches_triggered'] += 1
        
        self.stats['errors_detected'] += len(errors)
        self.stats['errors_by_service'][service] += len(errors)
    
    def run_cycle(self):
        """Exécute un cycle complet de monitoring"""
        if self.shutdown_event.is_set():
            return
        
        cycle_start = time.time()
        self.logger.info("🔄 Cycle de monitoring qBittorrent")
        
        for service in self.config.services.keys():
            if self.shutdown_event.is_set():
                break
            
            if not self.config.services[service].get('enabled', True):
                continue
            
            self.process_service(service)
            # Délai entre les services
            self.shutdown_event.wait(1)
        
        self.stats['cycles'] += 1
        self.stats['last_check'] = datetime.now().isoformat()
        
        cycle_duration = time.time() - cycle_start
        
        # Log des statistiques tous les 10 cycles
        if self.stats['cycles'] % 10 == 0:
            self.logger.info(f"📊 Stats: Cycles={self.stats['cycles']}, "
                           f"Erreurs={self.stats['errors_detected']}, "
                           f"Supprimés={self.stats['downloads_removed']}, "
                           f"Durée cycle={cycle_duration:.2f}s")
    
    def save_stats(self):
        """Sauvegarde les statistiques"""
        try:
            log_dir = os.path.join(self.config.home_dir, 'logs')
            stats_file = os.path.join(log_dir, 'qbittorrent-stats.json')
            
            # Ajout de métadonnées
            stats_to_save = self.stats.copy()
            stats_to_save['version'] = '2.0'
            stats_to_save['saved_at'] = datetime.now().isoformat()
            
            with open(stats_file, 'w', encoding='utf-8') as f:
                json.dump(stats_to_save, f, indent=2, ensure_ascii=False)
        except Exception as e:
            self.logger.debug(f"Erreur sauvegarde stats: {e}")
    
    def health_check(self) -> Dict[str, Union[bool, str, Dict]]:
        """Effectue un contrôle de santé du système"""
        health = {
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'services': {},
            'configuration': {
                'dry_run': self.config.dry_run,
                'check_interval': self.config.check_interval,
                'docker_network': self.config.docker_network
            }
        }
        
        # Vérification de chaque service
        for service, service_config in self.config.services.items():
            if not service_config.get('enabled', True):
                health['services'][service] = {'status': 'disabled'}
                continue
            
            service_health = {'status': 'unknown'}
            
            # Test de connectivité Docker
            ip = self.get_container_ip(service)
            if not ip:
                service_health['status'] = 'docker_unreachable'
                service_health['message'] = 'Container IP not found'
            else:
                service_health['container_ip'] = ip
                
                # Test de l'API
                api_key = self.get_api_key(service)
                if not api_key:
                    service_health['status'] = 'api_key_missing'
                    service_health['message'] = 'API key not found'
                else:
                    # Test de connectivité API
                    try:
                        url = f"http://{ip}:{service_config['port']}/api/{service_config['api_version']}/system/status"
                        response = self.session.get(url, headers={"X-Api-Key": api_key})
                        if response.status_code == 200:
                            service_health['status'] = 'healthy'
                            service_health['api_version'] = service_config['api_version']
                        else:
                            service_health['status'] = 'api_error'
                            service_health['message'] = f'HTTP {response.status_code}'
                    except Exception as e:
                        service_health['status'] = 'api_unreachable'
                        service_health['message'] = str(e)
            
            health['services'][service] = service_health
            
            # Marque l'état global comme dégradé si un service a un problème
            if service_health['status'] not in ['healthy', 'disabled']:
                health['status'] = 'degraded'
        
        return health
    
    def run(self):
        """Boucle principale de monitoring"""
        self.logger.info("🎯 Monitoring automatique des erreurs qBittorrent démarré")
        
        try:
            while self.running and not self.shutdown_event.is_set():
                start = time.time()
                self.run_cycle()
                
                # Sauvegarde des statistiques
                self.save_stats()
                
                elapsed = time.time() - start
                sleep_time = max(0, self.config.check_interval - elapsed)
                
                if sleep_time > 0:
                    self.logger.debug(f"⏳ Attente {sleep_time:.1f}s avant le prochain cycle")
                    self.shutdown_event.wait(sleep_time)
                    
        except Exception as e:
            self.logger.error(f"❌ Erreur fatale: {e}")
            raise
        finally:
            self.logger.info("🛑 Monitoring arrêté")
            try:
                self.session.close()
            except Exception:
                pass

def main():
    """Fonction principale avec gestion d'erreurs améliorée"""
    parser = argparse.ArgumentParser(
        description='QBittorrent Error Monitor - Production Ready v2.0',
        epilog='Configuration via config.yaml, variables d\'environnement ou arguments CLI'
    )
    
    parser.add_argument('--config', '-c', type=str, 
                       help='Chemin vers le fichier de configuration YAML')
    parser.add_argument('--interval', '-i', type=int, 
                       help='Intervalle de vérification en secondes')
    parser.add_argument('--verbose', '-v', action='store_true', 
                       help='Mode verbose (debug)')
    parser.add_argument('--test', '-t', action='store_true', 
                       help='Mode test (un seul cycle)')
    parser.add_argument('--dry-run', action='store_true', 
                       help='Mode simulation (aucune action effectuée)')
    parser.add_argument('--health-check', action='store_true', 
                       help='Effectue un contrôle de santé et sort')
    parser.add_argument('--version', action='version', version='2.0')
    
    args = parser.parse_args()
    
    try:
        # Chargement de la configuration
        config_file = args.config
        if not config_file:
            # Recherche automatique du fichier de config
            possible_configs = [
                'config/config.yaml',
                'config.yaml',
                '/etc/qbittorrent-monitor/config.yaml'
            ]
            for config_path in possible_configs:
                if os.path.exists(config_path):
                    config_file = config_path
                    break
        
        config_manager = ConfigManager(config_file)
        config = config_manager.config
        
        # Surcharge avec les arguments CLI
        if args.interval:
            config.check_interval = args.interval
        if args.dry_run:
            config.dry_run = True
        if args.verbose:
            config.log_level = "DEBUG"
        
        # Configuration du logging
        logger = setup_logging(config)
        
        # Validation de la configuration
        if not os.path.exists(config.config_base_path):
            logger.error(f"Chemin de configuration invalide: {config.config_base_path}")
            sys.exit(1)
        
        # Initialisation du monitor
        monitor = QBittorrentErrorMonitor(config, logger)
        
        # Mode health check
        if args.health_check:
            logger.info("🏥 Contrôle de santé du système")
            health = monitor.health_check()
            print(json.dumps(health, indent=2, ensure_ascii=False))
            
            # Code de sortie basé sur l'état de santé
            if health['status'] == 'healthy':
                logger.info("✅ Système en bonne santé")
                sys.exit(0)
            elif health['status'] == 'degraded':
                logger.warning("⚠️ Système dégradé")
                sys.exit(1)
            else:
                logger.error("❌ Système en erreur")
                sys.exit(2)
        
        # Mode test
        if args.test:
            logger.info("🧪 Mode test - un seul cycle")
            monitor.run_cycle()
            monitor.save_stats()
            
            # Affiche les résultats
            if monitor.stats['errors_detected'] > 0:
                logger.info(f"✅ Test terminé - {monitor.stats['errors_detected']} erreur(s) détectée(s)")
            else:
                logger.info("✅ Test terminé - Aucune erreur détectée")
        else:
            # Mode normal
            monitor.run()
            
    except KeyboardInterrupt:
        logger.info("📡 Arrêt demandé par l'utilisateur")
        sys.exit(0)
    except Exception as e:
        logger.error(f"❌ Erreur fatale lors du démarrage: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
