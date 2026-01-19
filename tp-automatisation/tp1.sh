#!/bin/bash
#===============================================================================
# Nom        : system-check.sh
# Description: Script de monitoring système (CPU, RAM, Disque, Services)
# Auteur     : Admin
# Version    : 1.0.0
# Usage      : ./system-check.sh [--verbose]
#===============================================================================

set -euo pipefail  # Mode strict
IFS=$'\n\t'        # Séparateurs sûrs

# === CONFIGURATION ===
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="/var/log/${SCRIPT_NAME%.sh}.log"
readonly LOCK_FILE="/tmp/${SCRIPT_NAME%.sh}.lock"

# Seuils d'alerte (Configurables)
readonly THRESHOLD_CPU=80
readonly THRESHOLD_RAM=90
readonly THRESHOLD_DISK=90 # Alerte si utilisé > 90% (donc < 10% libre)
readonly SERVICES=("nginx")

# Valeurs par défaut
VERBOSE="${VERBOSE:-false}"

# === COULEURS ===
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# === FONCTIONS UTILITAIRES ===

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    # On affiche sur la sortie standard ET dans le fichier de log
    echo -e "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info()    { log "${BLUE}INFO${NC}" "$@"; }
log_warn()    { log "${YELLOW}WARN${NC}" "$@"; }
log_error()   { log "${RED}ERROR${NC}" "$@"; }
log_success() { log "${GREEN}OK${NC}" "$@"; }

die() {
    log_error "$@"
    exit 1
}

cleanup() {
    local exit_code=$?
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Nettoyage des fichiers temporaires..."
    fi
    rm -f "$LOCK_FILE"
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script terminé avec des erreurs (code: $exit_code)"
    else
        if [[ "$VERBOSE" == "true" ]]; then
            log_success "Script terminé proprement."
        fi
    fi
    exit $exit_code
}

usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Vérifie l'état de santé du système (CPU, RAM, Disque, Services).

Options:
    -V, --verbose        Mode verbeux (affiche plus de détails)
    -h, --help           Affiche cette aide

Exemple:
    $SCRIPT_NAME --verbose
EOF
    exit 0
}

# === PARSING DES ARGUMENTS ===
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -V|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                die "Option inconnue: $1"
                ;;
        esac
    done
}

# === VALIDATIONS ===
check_prerequisites() {
    # On vérifie que les outils de base sont là
    local cmds=("top" "free" "df" "systemctl" "awk" "grep")
    for cmd in "${cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            die "Commande requise non trouvée: $cmd"
        fi
    done
}

acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$LOCK_FILE")
        # Vérifie si le processus existe toujours
        if kill -0 "$pid" 2>/dev/null; then
            die "Une instance est déjà en cours (PID: $pid)"
        fi
        log_warn "Fichier lock orphelin trouvé, suppression..."
        rm -f "$LOCK_FILE"
    fi
    echo $$ > "$LOCK_FILE"
}

# === LOGIQUE MÉTIER (MONITORING) ===

check_cpu() {
    # Récupère l'utilisation CPU (Utilisateur + Système) via top
    # Note: top -bn1 lance top une seule fois en mode batch
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' | cut -d. -f1) # Entier seulement
    
    # Gestion du cas où cpu_usage est vide (par sécurité)
    cpu_usage=${cpu_usage:-0}

    if [[ "$cpu_usage" -gt "$THRESHOLD_CPU" ]]; then
        log_error "CPU critique: ${cpu_usage}% (Seuil: ${THRESHOLD_CPU}%)"
    elif [[ "$VERBOSE" == "true" ]]; then
        log_info "CPU normal: ${cpu_usage}%"
    fi
}

check_memory() {
    # free -m affiche en MB. On utilise awk pour calculer le pourcentage utilisé
    local ram_usage
    ram_usage=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')

    if [[ "$ram_usage" -gt "$THRESHOLD_RAM" ]]; then
        log_error "RAM critique: ${ram_usage}% (Seuil: ${THRESHOLD_RAM}%)"
    elif [[ "$VERBOSE" == "true" ]]; then
        log_info "RAM normale: ${ram_usage}%"
    fi
}

check_disk() {
    # Vérifie l'espace utilisé sur la racine /
    local disk_usage
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')

    if [[ "$disk_usage" -gt "$THRESHOLD_DISK" ]]; then
        # > 90% utilisé équivaut à < 10% libre
        log_error "Espace disque critique: ${disk_usage}% utilisé (Seuil: ${THRESHOLD_DISK}%)"
    elif [[ "$VERBOSE" == "true" ]]; then
        log_info "Espace disque normal: ${disk_usage}% utilisé"
    fi
}

check_services() {
    for service in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$service"; then
            if [[ "$VERBOSE" == "true" ]]; then
                log_success "Service $service est actif"
            fi
        else
            # On vérifie si le service existe avant de crier au loup (optionnel mais propre)
            if systemctl list-unit-files | grep -q "^$service"; then
                log_error "Service $service est ARRÊTÉ !"
            else
                log_warn "Service $service non installé ou introuvable."
            fi
        fi
    done
}

# === MAIN ===
main() {
    trap cleanup EXIT
    
    parse_args "$@"
    check_prerequisites
    acquire_lock
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "=== Démarrage du Monitoring ==="
    fi

    check_cpu
    check_memory
    check_disk
    check_services

    if [[ "$VERBOSE" == "true" ]]; then
        log_info "=== Fin du Monitoring ==="
    fi
}

# Exécution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi