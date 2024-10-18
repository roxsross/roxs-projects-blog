#!/bin/bash

# Habilitar modo estricto y debugging
set -euo pipefail
#set -x
IFS=$'\n\t'

TEMP_DIR="tempdir"
PORT=3000
DOCKERFILE_PATH="Dockerfile"
PID_FILE="/tmp/node-server-app.pid"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

# Banner llamativo
print_banner() {
    echo -e "${BLUE}"
    echo "##############################################"
    echo "      🚀 Bienvenido al RoxsApp Deployer! 🚀   "
    echo "        Automatizando todo con estilo...      "
    echo "              MODO:$EXECUTION_MODE            "
    echo "###############################################"
    echo -e "${NC}"
}

# Función para imprimir mensajes coloreados
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Función para convertir cadena a minúsculas
to_lowercase() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Función para verificar si una herramienta está instalada
check_tool() {
    if ! command -v "$1" &>/dev/null; then 
        print_message "$RED" "Error: '$1' no está instalado."
        exit 1
    fi
    print_message "$GREEN" "'$1' está instalado."
}

# Función para verificar todas las herramientas requeridas
check_all_tools() {
    local tools=("node" "npm" "jq" "git")
    for tool in "${tools[@]}"; do
        check_tool "$tool"
    done
    if [ "${EXECUTION_MODE:-}" = "DOCKER" ]; then
        check_tool "docker"
    fi
}

# Función para obtener información de Git
get_git_info() {
    REPO_NAME=$(basename -s .git "$(git config --get remote.origin.url)")
    BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
    DOCKER_IMAGE=$(to_lowercase "$REPO_NAME")
    CONTAINER_NAME=$(to_lowercase "${REPO_NAME}-${BRANCH_NAME}")
    echo ""
    print_message "$YELLOW" "Repo: $REPO_NAME, Branch: $BRANCH_NAME."
}

# Función para leer la versión de la aplicación desde package.json
read_app_version() {
    if [ ! -f "package.json" ]; then
        print_message "$RED" "Error: 'package.json' no encontrado."
        exit 1
    fi
    
    if ! APP_VERSION=$(jq -r '.version' package.json); then
        print_message "$RED" "Error: No se pudo leer la versión."
        exit 1
    fi
    
    if [ -z "$APP_VERSION" ] || [ "$APP_VERSION" = "null" ]; then
        print_message "$RED" "Error: Versión no válida."
        exit 1
    fi
    
    print_message "$YELLOW" "Versión: $APP_VERSION."
}

# Función para crear el Dockerfile
create_dockerfile() {
    print_message "$YELLOW" "Creando Dockerfile..."
    cat <<EOF > "$TEMP_DIR/$DOCKERFILE_PATH"
FROM node:18-alpine
LABEL org.opencontainers.image.authors="RoxsRoss"
RUN apk add --no-cache python3 make g++
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE $PORT
CMD ["npm", "start"]
EOF
}

# Función para construir y ejecutar en Docker
docker_build_and_run() {
    print_message "$YELLOW" "Eliminando contenedores antiguos..."
    docker rm -f "$CONTAINER_NAME" &>/dev/null || true
    docker rmi -f "$DOCKER_IMAGE:$APP_VERSION" &>/dev/null || true

    print_message "$YELLOW" "Construyendo imagen Docker..."
    if ! docker build -t "$DOCKER_IMAGE:$APP_VERSION" "$TEMP_DIR"; then
        print_message "$RED" "Error: Falló la construcción."
        exit 1
    fi

    print_message "$YELLOW" "Iniciando contenedor..."
    if ! docker run -d -p "$PORT:$PORT" --name "$CONTAINER_NAME" "$DOCKER_IMAGE:$APP_VERSION"; then
        print_message "$RED" "Error: No se pudo iniciar el contenedor."
        exit 1
    fi

    print_message "$YELLOW" "Contenedores activos:"
    docker ps -a --filter "name=$CONTAINER_NAME"

    print_message "$YELLOW" "Logs del contenedor:"
    sleep 1
    docker logs "$CONTAINER_NAME"

    print_message "$YELLOW" "IP del contenedor:"
    CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER_NAME")
    print_message "$GREEN" "IP: $CONTAINER_IP."
}

# Función para ejecutar localmente
run_locally() {
    print_message "$YELLOW" "Ejecutando localmente..."
    if ! npm install; then
        print_message "$RED" "Error: Falló la instalación."
        exit 1
    fi
    if lsof -i :"$PORT" > /dev/null; then
        print_message "$RED" "Puerto $PORT en uso. Deteniendo proceso..."
        stop_node_server
    fi
    npm run start &
    local NODE_PID=$!
    echo "$NODE_PID" > "$PID_FILE"
    sleep 5
    if ps -p "$NODE_PID" > /dev/null; then
        print_message "$GREEN" "Corriendo en http://localhost:$PORT"
        print_message "$YELLOW" "PID: $NODE_PID"
        print_message "$YELLOW" "Para detener: $0 STOP"
    else
        print_message "$RED" "Error: No se pudo iniciar. Revise los logs."
        exit 1
    fi
}

# Función para detener el servidor Node.js local
stop_node_server() {
    local PIDS
    PIDS=$(lsof -t -i:"$PORT")
    if [ -n "$PIDS" ]; then
        print_message "$YELLOW" "Deteniendo procesos en puerto $PORT..."
        echo "$PIDS" | xargs kill -9
        print_message "$GREEN" "Procesos detenidos."
    else
        print_message "$YELLOW" "No hay procesos en puerto $PORT."
    fi
    [ -f "$PID_FILE" ] && rm "$PID_FILE"
}

# Función para detener el contenedor Docker
stop_docker_container() {
    if [ -z "${CONTAINER_NAME:-}" ]; then
        get_git_info
    fi
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        print_message "$YELLOW" "Deteniendo contenedor Docker..."
        docker stop "$CONTAINER_NAME"
        docker rm "$CONTAINER_NAME"
        print_message "$GREEN" "Contenedor detenido."
    else
        print_message "$YELLOW" "No hay contenedor con nombre $CONTAINER_NAME."
    fi
}

# Función para limpiar recursos
cleanup() {
    print_message "$YELLOW" "Limpiando recursos..."
    rm -rf "$TEMP_DIR"
    print_message "$GREEN" "Limpieza completada."
}

# Función para mostrar procesos en ejecución
show_running_processes() {
    ps aux | grep -E "node|npm|docker" | grep -v grep > /dev/null
}

# Configurar trap para manejar señales de terminación
trap 'cleanup; show_running_processes; exit 0' EXIT

# Función para mostrar la estructura de directorios de $TEMP_DIR
show_temp_dir_structure() {
    local temp_dir="${1}"  # Directorio temporal (pasa $TEMP_DIR aquí)
    
    if [ -d "$temp_dir" ]; then
        print_message "$YELLOW" "Estructura de $temp_dir:"
        find "$temp_dir" -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g'
    else
        print_message "$RED" "Error: Directorio $temp_dir no existe."
    fi
}

# Función para mostrar el uso del script
show_usage() {
    echo "Uso: $0 <comando>"
    echo "Comandos:"
    echo "  LOCAL   - Ejecutar localmente"
    echo "  DOCKER  - Ejecutar en Docker"
    echo "  STOP    - Detener ejecución"
    exit 1
}

# Función principal
main() {
    if [ $# -eq 0 ]; then
        show_usage
    fi

    EXECUTION_MODE=$1

    case "$EXECUTION_MODE" in
        LOCAL|DOCKER)
            print_banner
            check_all_tools
            get_git_info
            read_app_version

            if [ "$EXECUTION_MODE" = "DOCKER" ]; then
                print_message "$YELLOW" "Creando directorio temporal..."
                mkdir -p "$TEMP_DIR"/{public,src}
                cp -r src/* "$TEMP_DIR/src/"
                cp -r public/* "$TEMP_DIR/public/"
                cp package*.json server.js "$TEMP_DIR/"
                create_dockerfile
                show_temp_dir_structure "$TEMP_DIR"
                docker_build_and_run
            elif [ "$EXECUTION_MODE" = "LOCAL" ]; then
                run_locally
            fi

            print_message "$YELLOW" "Probando aplicación..."
            RETRIES=5
            for i in $(seq 1 $RETRIES); do
                if curl -s "http://localhost:$PORT" > /dev/null; then
                    print_message "$GREEN" "Corriendo en http://localhost:$PORT"
                    break
                else
                    if [ $i -eq $RETRIES ]; then
                        print_message "$RED" "Error: No está corriendo. Revise los logs."
                        exit 1
                    fi
                    print_message "$YELLOW" "Reintentando en 5 segundos... ($i/$RETRIES)"
                    sleep 5
                fi
            done
            ;;
        STOP)
            if docker ps -q -f name="$(to_lowercase "${REPO_NAME:-}-${BRANCH_NAME:-}")" | grep -q .; then
                get_git_info
                stop_docker_container
            else
                stop_node_server
            fi
            print_message "$GREEN" "Aplicación detenida."
            ;;
        *)
            print_message "$RED" "Error: Comando no válido: $EXECUTION_MODE"
            show_usage
            ;;
    esac
}

# Ejecutar la función principal con todos los argumentos pasados al script
main "$@"
