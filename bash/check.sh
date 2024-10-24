#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables de configuración
LOG_FILE="/var/log/system-monitor.log"
METRICS_FILE="/var/log/system-metrics.log"
ALERT_CPU_THRESHOLD=80
ALERT_MEM_THRESHOLD=80
ALERT_DISK_THRESHOLD=85
MONITOR_INTERVAL=300  # 5 minutos en segundos

# Mejor manejo de errores
set -euo pipefail
trap 'echo -e "${RED}Error: Comando falló en la línea $LINENO${NC}" | tee -a $LOG_FILE' ERR

# Función de logging mejorada
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${timestamp} [$level] $message" | tee -a $LOG_FILE
}

# Función para verificar si se está ejecutando como root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_message "ERROR" "${RED}Este script necesita privilegios de root para instalar paquetes.${NC}"
        log_message "WARNING" "${YELLOW}Por favor, ejecute con sudo.${NC}"
        exit 1
    fi
}

# Función mejorada para instalar dependencias
install_dependencies() {
    local os_type=""
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        os_type=$ID
    fi
    
    log_message "INFO" "${BLUE}Verificando e instalando dependencias necesarias...${NC}"
    
    case $os_type in
        "ubuntu"|"debian")
            apt-get update -qq
            packages=(sysstat lm-sensors net-tools)
            for package in "${packages[@]}"; do
                if ! dpkg -l | grep -q "^ii.*$package"; then
                    log_message "INFO" "${GREEN}Instalando $package...${NC}"
                    DEBIAN_FRONTEND=noninteractive apt-get install -y $package
                fi
            done
            ;;
        "centos"|"rhel"|"fedora")
            packages=(sysstat lm-sensors net-tools)
            for package in "${packages[@]}"; do
                if ! rpm -q $package &>/dev/null; then
                    log_message "INFO" "${GREEN}Instalando $package...${NC}"
                    dnf install -y $package
                fi
            done
            ;;
        *)
            log_message "ERROR" "${RED}Sistema operativo no soportado para instalación automática.${NC}"
            exit 1
            ;;
    esac
}

# Función para recolectar métricas del sistema
collect_metrics() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local cpu_usage=$(mpstat 1 1 | awk '/Average:/ {printf "%.2f", 100-$NF}')
    local mem_total=$(free -m | awk '/Mem:/ {print $2}')
    local mem_used=$(free -m | awk '/Mem:/ {print $3}')
    local mem_usage=$(awk "BEGIN {printf \"%.2f\", $mem_used/$mem_total*100}")
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    # Guardar métricas en formato CSV
    echo "$timestamp,$cpu_usage,$mem_usage,$disk_usage" >> $METRICS_FILE
    
    # Verificar umbrales y generar alertas
    check_thresholds "$cpu_usage" "$mem_usage" "$disk_usage"
}

# Función para verificar umbrales y generar alertas
check_thresholds() {
    local cpu_usage=$1
    local mem_usage=$2
    local disk_usage=$3
    
    if [ $(echo "$cpu_usage > $ALERT_CPU_THRESHOLD" | bc -l) -eq 1 ]; then
        log_message "ALERT" "${RED}¡Alerta! CPU usage alto: ${cpu_usage}%${NC}"
    fi
    
    if [ $(echo "$mem_usage > $ALERT_MEM_THRESHOLD" | bc -l) -eq 1 ]; then
        log_message "ALERT" "${RED}¡Alerta! Memory usage alto: ${mem_usage}%${NC}"
    fi
    
    if [ $(echo "$disk_usage > $ALERT_DISK_THRESHOLD" | bc -l) -eq 1 ]; then
        log_message "ALERT" "${RED}¡Alerta! Disk usage alto: ${disk_usage}%${NC}"
    fi
}

# Función para crear banners
create_banner() {
    local title="$1"
    local width=80
    local line=$(printf '%*s' "$width" | tr ' ' '*')
    echo -e "\n${BLUE}$line${NC}"
    echo -e "\t\t${YELLOW}$title${NC}"
    echo -e "${BLUE}$line${NC}"
}

# Función para mostrar información del sistema
show_system_info() {
    create_banner "SYSTEM INFORMATION"
    log_message "INFO" "Recopilando información del sistema"
    
    echo -e "${GREEN}Host: $(hostname)${NC}"
    echo -e "${GREEN}OS: $(cat /etc/os-release | grep "PRETTY_NAME" | cut -d'"' -f2)${NC}"
    echo -e "${GREEN}Kernel: $(uname -r)${NC}"
    echo -e "${GREEN}Uptime: $(uptime -p)${NC}"
}

# Función para mostrar uso de CPU
show_cpu_info() {
    create_banner "CPU USAGE"
    log_message "INFO" "Recopilando información de CPU"
    
    # Carga promedio con formato mejorado
    local cpu_load=$(uptime | grep -ohe 'load average[s:][: ].*' | awk '{ print "1min: "$2" 5min: "$3" 15min: "$4}')
    echo -e "${GREEN}Promedio de carga de CPU:\n$cpu_load${NC}"
    
    # Utilización actual de CPU con mpstat
    echo -e "\n${GREEN}Utilización actual de CPU:${NC}"
    if command -v mpstat &> /dev/null; then
        mpstat 1 1 | awk '/Average:/ {printf "Usuario: %.2f%%\nSistema: %.2f%%\nIdle: %.2f%%\n", $3, $5, $12}'
    else
        log_message "WARNING" "mpstat no disponible, usando top"
        top -bn1 | grep "Cpu(s)" | awk '{print "Usuario: " $2 "%\nSistema: " $4 "%\nIdle: " $8 "%"}'
    fi
    
    # Top procesos
    echo -e "\n${GREEN}Top 5 procesos por CPU:${NC}"
    ps aux --sort=-%cpu | head -6 | awk '
        BEGIN {printf "%-10s %-10s %-10s %-40s\n", "USER", "%CPU", "%MEM", "COMMAND"}
        NR>1 {printf "%-10s %-10.1f %-10.1f %-40s\n", $1, $3, $4, $11}'
}

# Función para mostrar uso de memoria
show_memory_info() {
    create_banner "MEMORY USAGE"
    log_message "INFO" "Recopilando información de memoria"
    
    # RAM
    free -h | awk '
        /Mem:/ {printf "Total RAM: %s\nUsada: %s\nLibre: %s\nDisponible: %s\n", $2, $3, $4, $7}'
    
    # Top procesos por uso de memoria
    echo -e "\n${GREEN}Top 5 procesos por memoria:${NC}"
    ps aux --sort=-%mem | head -6 | awk '
        BEGIN {printf "%-10s %-10s %-10s %-40s\n", "USER", "%CPU", "%MEM", "COMMAND"}
        NR>1 {printf "%-10s %-10.1f %-10.1f %-40s\n", $1, $3, $4, $11}'
}

# Función para mostrar uso de disco
show_disk_info() {
    create_banner "DISK USAGE"
    log_message "INFO" "Recopilando información de disco"
    
    echo -e "${GREEN}Estado del disco:${NC}"
    df -h | awk '
        BEGIN {printf "%-20s %-10s %-10s %-10s %-10s\n", "Filesystem", "Size", "Used", "Avail", "Use%"}
        NR>1 {printf "%-20s %-10s %-10s %-10s %-10s\n", $1, $2, $3, $4, $5}'
}

# Función para verificar servicios críticos
check_critical_services() {
    local critical_services=("sshd" "systemd" "networkd" "cron")
    local failed_services=()
    
    for service in "${critical_services[@]}"; do
        if ! systemctl is-active --quiet "$service" 2>/dev/null; then
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_message "ALERT" "${RED}Servicios críticos detenidos: ${failed_services[*]}${NC}"
    fi
}

# Función mejorada para mostrar logs del sistema
show_system_logs() {
    create_banner "SYSTEM LOGS"
    log_message "INFO" "Recopilando logs críticos del sistema"
    
    echo -e "${GREEN}Logs críticos y errores (últimas 24 horas):${NC}"
    echo -e "${YELLOW}Formato: TIMESTAMP | SERVICIO | NIVEL | MENSAJE${NC}\n"
    
    # Filtrar logs importantes de las últimas 24 horas
    journalctl --since "24 hours ago" -p err..emerg --no-pager | \
    grep -v "Assuming drive cache\|mode parameter data" | \
    awk '{
        # Extraer y formatear la fecha/hora
        timestamp=$1" "$2" "$3
        # Extraer el servicio
        service=$4
        # Extraer el nivel (si existe)
        level="ERROR"
        if ($0 ~ /critical/i) level="CRITICAL"
        if ($0 ~ /alert/i) level="ALERT"
        if ($0 ~ /emergency/i) level="EMERGENCY"
        if ($0 ~ /warning/i) level="WARNING"
        # Extraer el mensaje (todo lo que sigue)
        $1=$2=$3=$4=""
        message=$0
        # Imprimir con formato
        printf "%-25s | %-15s | %-10s | %s\n", timestamp, service, level, message
    }' | tail -n 10

    echo -e "\n${GREEN}Servicios con errores en las últimas 24 horas:${NC}"
    journalctl --since "24 hours ago" -p err..emerg --no-pager | \
        grep -v "Assuming drive cache\|mode parameter data" | \
        awk '{print $4}' | sort | uniq -c | sort -nr | \
        awk '{printf "%-4s errores en %-30s\n", $1, $2}' | head -n 5

    echo -e "\n${GREEN}Resumen de servicios críticos:${NC}"
    for service in sshd systemd-logind NetworkManager systemd kernel; do
        status=$(systemctl is-active $service 2>/dev/null || echo "inactive")
        echo -e "Service: $service - Status: ${status}"
    done

    echo -e "\n${GREEN}Intentos fallidos de acceso (últimas 24 horas):${NC}"
    journalctl --since "24 hours ago" | grep -i "failed\|authentication failure" | \
        grep -v "timestamp" | tail -n 5 | \
        awk '{
            timestamp=$1" "$2" "$3
            $1=$2=$3=""
            printf "%-25s | %s\n", timestamp, $0
        }'
}

# Función para mostrar estado de red
show_network_info() {
    create_banner "NETWORK STATUS"
    log_message "INFO" "Recopilando información de red"
    
    if ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
        log_message "INFO" "Conexión a Internet disponible"
        echo -e "${GREEN}Estado de Internet: CONECTADO${NC}"
        
        echo -e "\n${GREEN}Interfaces de red:${NC}"
        ip -br addr show | awk '{printf "%-10s %-15s %-20s\n", $1, $2, $3}'
        
        echo -e "\n${GREEN}Conexiones activas:${NC}"
        ss -tuln | awk '
            NR==1 {printf "%-10s %-20s %-20s\n", "Proto", "Local Address", "State"}
            NR>1 {printf "%-10s %-20s %-20s\n", $1, $5, $6}' | head -6
    else
        log_message "WARNING" "Sin conexión a Internet"
        echo -e "${RED}Estado de Internet: SIN CONEXIÓN${NC}"
    fi
}

# Función principal
main() {
    # Inicialización
    check_root
    install_dependencies
    
    # Crear/limpiar archivos de log y métricas
    : > $LOG_FILE
    : > $METRICS_FILE
    echo "timestamp,cpu_usage,mem_usage,disk_usage" > $METRICS_FILE
    
    # Limpiar pantalla
    clear
    
    # Recopilar y mostrar información
    show_system_info
    show_cpu_info
    show_memory_info
    show_disk_info
    show_network_info
    
    # Verificar servicios críticos
    check_critical_services
    
    # Recopilar métricas
    collect_metrics
    
    # Mostrar logs del sistema
    show_system_logs
    
    log_message "INFO" "Monitoreo completado exitosamente"
}

# Ejecutar script
main "$@"
