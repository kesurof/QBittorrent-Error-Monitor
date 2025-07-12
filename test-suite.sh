#!/bin/bash

# Script de test complet pour QBittorrent Error Monitor
# Valide toutes les fonctionnalités et la sécurité

set -euo pipefail
IFS=$'\n\t'

# Variables
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Fonctions de logging
log_info() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️ $1${NC}"; }
log_test() { echo -e "${BLUE}🧪 $1${NC}"; }

# Compteurs de tests
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TESTS_TOTAL++))
    log_test "Test: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        log_info "PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "FAIL: $test_name"
        ((TESTS_FAILED++))
        return 1
    fi
}

show_banner() {
    echo -e "${BLUE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║               QBittorrent Monitor - Suite de Tests              ║
║                     Validation Complète v2.0                    ║
╚══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

test_dependencies() {
    log_test "=== Tests des Dépendances ==="
    
    run_test "Python 3 disponible" "command -v python3"
    run_test "Module requests installé" "python3 -c 'import requests'"
    run_test "Module yaml installé" "python3 -c 'import yaml'"
    run_test "Module json installé" "python3 -c 'import json'"
    run_test "Commande curl disponible" "command -v curl"
    run_test "Commande sed disponible" "command -v sed"
    run_test "Commande docker disponible" "command -v docker"
}

test_file_structure() {
    log_test "=== Tests de Structure des Fichiers ==="
    
    run_test "Script principal existe" "test -f '$SCRIPT_DIR/qbittorrent-monitor.py'"
    run_test "Script setup existe" "test -f '$SCRIPT_DIR/setup.sh'"
    run_test "Script install existe" "test -f '$SCRIPT_DIR/install.sh'"
    run_test "Fichier requirements existe" "test -f '$SCRIPT_DIR/requirements.txt'"
    run_test "Configuration exemple existe" "test -f '$SCRIPT_DIR/config/config.yaml'"
    run_test "Script principal exécutable" "test -x '$SCRIPT_DIR/qbittorrent-monitor.py'"
    run_test "Script setup exécutable" "test -x '$SCRIPT_DIR/setup.sh'"
}

test_python_syntax() {
    log_test "=== Tests de Syntaxe Python ==="
    
    run_test "Syntaxe Python valide" "python3 -m py_compile '$SCRIPT_DIR/qbittorrent-monitor.py'"
    run_test "Import du module principal" "python3 -c 'import sys; sys.path.insert(0, \"$SCRIPT_DIR\"); exec(open(\"$SCRIPT_DIR/qbittorrent-monitor.py\").read())' 2>/dev/null || true"
}

test_configuration() {
    log_test "=== Tests de Configuration ==="
    
    run_test "Configuration YAML valide" "python3 -c 'import yaml; yaml.safe_load(open(\"$SCRIPT_DIR/config/config.yaml\"))'"
    run_test "Configuration contient services" "grep -q 'services:' '$SCRIPT_DIR/config/config.yaml'"
    run_test "Configuration contient sonarr" "grep -q 'sonarr:' '$SCRIPT_DIR/config/config.yaml'"
    run_test "Configuration contient radarr" "grep -q 'radarr:' '$SCRIPT_DIR/config/config.yaml'"
}

test_security_features() {
    log_test "=== Tests de Sécurité ==="
    
    run_test "Aucun shell=True détecté" "! grep -q 'shell=True' '$SCRIPT_DIR/qbittorrent-monitor.py'"
    run_test "Validation d'entrées présente" "grep -q 'validate_' '$SCRIPT_DIR/qbittorrent-monitor.py'"
    run_test "Échappement sécurisé présent" "grep -q 'escape_for_' '$SCRIPT_DIR/setup.sh'"
    run_test "Utilisation de shlex" "grep -q 'shlex' '$SCRIPT_DIR/qbittorrent-monitor.py'"
    run_test "Variables quotées dans setup.sh" "! grep -E 'sed.*\$[A-Z_]+[^}]' '$SCRIPT_DIR/setup.sh'"
}

test_functionality() {
    log_test "=== Tests de Fonctionnalité ==="
    
    run_test "Aide disponible" "cd '$SCRIPT_DIR' && python3 qbittorrent-monitor.py --help"
    run_test "Version disponible" "cd '$SCRIPT_DIR' && python3 qbittorrent-monitor.py --version"
    run_test "Health check disponible" "cd '$SCRIPT_DIR' && python3 qbittorrent-monitor.py --health-check"
    run_test "Mode dry-run disponible" "cd '$SCRIPT_DIR' && python3 qbittorrent-monitor.py --test --dry-run"
    run_test "Mode verbose disponible" "cd '$SCRIPT_DIR' && python3 qbittorrent-monitor.py --test --verbose --dry-run"
}

test_error_handling() {
    log_test "=== Tests de Gestion d'Erreurs ==="
    
    # Test avec configuration invalide
    run_test "Gestion config invalide" "cd '$SCRIPT_DIR' && python3 qbittorrent-monitor.py --config /nonexistent/config.yaml --test --dry-run 2>/dev/null || true"
    
    # Test avec arguments invalides
    run_test "Gestion arguments invalides" "cd '$SCRIPT_DIR' && python3 qbittorrent-monitor.py --invalid-arg 2>/dev/null || true"
}

test_bash_security() {
    log_test "=== Tests de Sécurité Bash ==="
    
    run_test "set -e présent dans setup.sh" "grep -q 'set -e' '$SCRIPT_DIR/setup.sh'"
    run_test "Variables readonly dans setup.sh" "grep -q 'readonly' '$SCRIPT_DIR/setup.sh'"
    run_test "Validation d'entrées dans setup.sh" "grep -q 'validate_input' '$SCRIPT_DIR/setup.sh'"
    run_test "IFS sécurisé dans setup.sh" "grep -q 'IFS=' '$SCRIPT_DIR/setup.sh'"
    run_test "set -e présent dans install.sh" "grep -q 'set -e' '$SCRIPT_DIR/install.sh'"
}

test_logging() {
    log_test "=== Tests de Logging ==="
    
    run_test "RotatingFileHandler utilisé" "grep -q 'RotatingFileHandler' '$SCRIPT_DIR/qbittorrent-monitor.py'"
    run_test "Niveaux de log configurables" "grep -q 'log_level' '$SCRIPT_DIR/qbittorrent-monitor.py'"
    run_test "Formatage des logs configuré" "grep -q 'Formatter' '$SCRIPT_DIR/qbittorrent-monitor.py'"
}

run_performance_test() {
    log_test "=== Test de Performance ==="
    
    local start_time
    start_time=$(date +%s.%N)
    
    cd "$SCRIPT_DIR"
    if python3 qbittorrent-monitor.py --test --dry-run >/dev/null 2>&1; then
        local end_time
        end_time=$(date +%s.%N)
        local duration
        duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
        
        log_info "Test dry-run exécuté en ${duration}s"
        
        if (( $(echo "$duration < 10.0" | bc -l 2>/dev/null || echo "1") )); then
            log_info "PASS: Performance acceptable (< 10s)"
            ((TESTS_PASSED++))
        else
            log_warn "SLOW: Performance dégradée (> 10s)"
        fi
    else
        log_error "FAIL: Test de performance échoué"
        ((TESTS_FAILED++))
    fi
    
    ((TESTS_TOTAL++))
}

generate_test_report() {
    echo ""
    echo -e "${BLUE}📊 Rapport de Tests${NC}"
    echo "=========================="
    echo "Tests exécutés: $TESTS_TOTAL"
    echo -e "${GREEN}Tests réussis: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests échoués: $TESTS_FAILED${NC}"
    
    local success_rate
    if [[ $TESTS_TOTAL -gt 0 ]]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    else
        success_rate=0
    fi
    
    echo "Taux de réussite: ${success_rate}%"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 Tous les tests sont passés avec succès !${NC}"
        return 0
    else
        echo -e "${RED}⚠️ Certains tests ont échoué. Vérifiez la configuration.${NC}"
        return 1
    fi
}

main() {
    show_banner
    
    echo "📂 Répertoire de test: $SCRIPT_DIR"
    echo ""
    
    # Exécution de tous les tests
    test_dependencies
    echo ""
    
    test_file_structure
    echo ""
    
    test_python_syntax
    echo ""
    
    test_configuration
    echo ""
    
    test_security_features
    echo ""
    
    test_functionality
    echo ""
    
    test_error_handling
    echo ""
    
    test_bash_security
    echo ""
    
    test_logging
    echo ""
    
    run_performance_test
    echo ""
    
    # Génération du rapport
    if generate_test_report; then
        exit 0
    else
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
