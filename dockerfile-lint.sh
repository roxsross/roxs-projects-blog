#!/usr/bin/env bash

# -------------------------------------------------------------------------------- #                                                                               #
#                       DOCKERFILE LINTER BY @ROXSROSS                              #                                                                                  #
# -------------------------------------------------------------------------------- #
# -------------------------------------------------------------------------------- #
# Configuración del shell                                                           #
# -------------------------------------------------------------------------------- #

set -Eeuo pipefail

# -------------------------------------------------------------------------------- #
# Banner Function                                                                   #
# -------------------------------------------------------------------------------- #

function show_banner() {
    cat << "EOF"
    ____             ____               
   / __ \____  _  __/ __ \____  __________
  / /_/ / __ \| |/_/ /_/ / __ \/ ___/ ___/
 / _, _/ /_/ />  </ _, _/ /_/ (__  |__  ) 
/_/ |_|\____/_/|_/_/ |_|\____/____/____/  
                                          
        Created by @RoxsRoss
      Version: ${VERSION:-1.0.0}
EOF
}

# -------------------------------------------------------------------------------- #
# Variables Globales                                                                #
# -------------------------------------------------------------------------------- #

USE_DOCKER=true
DOCKER_IMAGE='hadolint/hadolint'
DOCKER_IMAGE_SHORT='hadolint'
TOOL_NAME="${DOCKER_IMAGE_SHORT}"
FILE_TYPE_PATTERN='No Magic Text'
FILE_NAME_PATTERN='Dockerfile$'
SEARCH_ROOT='.'

# Arrays para archivos
include_files=()
exclude_files=()

# Comandos Docker
DOCKER_PULL_COMMAND=('docker' 'pull' '--quiet' "${DOCKER_IMAGE}")
DOCKER_RUN_COMMAND=('docker' 'run' '--rm' '-i' "${DOCKER_IMAGE}")

# Contadores
file_count=0
ok_count=0
fail_count=0
skip_count=0

SHOW_ERRORS=${SHOW_ERRORS:-true}

# -------------------------------------------------------------------------------- #
# Funciones de Utilidad                                                             #
# -------------------------------------------------------------------------------- #

function run_command() {
    local -a command=("$@")
    local output

    if ! output=$("${command[@]}" 2>&1); then
        echo "${output}"
        return 1
    fi
    echo "${output}"
    return 0
}

function align_right() {
    local message=${1:-}
    local width=${screen_width:-140}
    local clean
    
    clean=$(strip_colours "${message}")
    local textsize=${#clean}
    local total_dashes=$((width - textsize - 2))
    local left_width=$((total_dashes / 2))
    local right_width=$((total_dashes - left_width))

    printf '%*s %s %*s\n' "${left_width}" '' "${message}" "${right_width}" '' | tr ' ' '-'
}

function strip_colours() {
    local orig=${1:-}
    local on=false

    if ! shopt -q extglob; then
        shopt -s extglob
        on=true
    fi
    local clean="${orig//$'\e'[\[(]*([0-9;])[@-n]/}"
    [[ "${on}" == true ]] && shopt -u extglob
    
    echo "${clean}"
}

# -------------------------------------------------------------------------------- #
# Funciones de Estado                                                               #
# -------------------------------------------------------------------------------- #

function stage() {
    local message=${1:-}
    CURRENT_STAGE=$((CURRENT_STAGE + 1))
    align_right "${bold_text}${cyan_text}Check ${CURRENT_STAGE}: ${message}${reset}"
}

function success() {
    local message=${1:-}
    echo " [ ${bold_text}${green_text}OK${reset} ] ${message}"
}

function fail() {
    local message=${1:-}
    local errors=${2:-}
    local override=${3:-false}

    echo " [ ${bold_text}${red_text}FAIL${reset} ] ${message}"

    if [[ "${SHOW_ERRORS}" == true || "${override}" == true ]] && [[ -n "${errors}" ]]; then
        echo
        echo "${errors}" | while IFS= read -r err; do
            echo "          ${err}"
        done
        echo
    fi

    EXIT_VALUE=1
}

function skip() {
    local message=${1:-}
    [[ "${SHOW_SKIPPED}" == true ]] && {
        skip_count=$((skip_count + 1))
        echo " [ ${bold_text}${yellow_text}Skip${reset} ] ${message}"
    }
}

# -------------------------------------------------------------------------------- #
# Funciones de Verificación                                                         #
# -------------------------------------------------------------------------------- #

function check_file() {
    local filename=$1
    local errors

    file_count=$((file_count + 1))
    if ! errors=$(run_command "${DOCKER_RUN_COMMAND[@]}" < "${filename}"); then
        fail "${filename}" "${errors}"
        fail_count=$((fail_count + 1))
    else
        success "${filename}"
        ok_count=$((ok_count + 1))
    fi
}

function is_excluded() {
    local needle=$1
    [[ ${#exclude_files[@]} -eq 0 ]] && return 1
    
    local pattern
    for pattern in "${exclude_files[@]}"; do
        [[ "${needle}" =~ ${pattern} ]] && return 0
    done
    return 1
}

function is_included() {
    local needle=$1
    [[ ${#include_files[@]} -eq 0 ]] && return 1
    
    local pattern
    for pattern in "${include_files[@]}"; do
        [[ "${needle}" =~ ${pattern} ]] && return 0
    done
    return 1
}

function check() {
    local filename=$1

    if is_included "${filename}"; then
        check_file "${filename}"
        return
    fi

    if is_excluded "${filename}"; then
        skip "${filename}"
        return
    fi

    if [[ "${#include_files[@]}" -ne 0 ]]; then
        return
    fi
    check_file "${filename}"
}

# -------------------------------------------------------------------------------- #
# Funciones de Instalación y Versión                                                #
# -------------------------------------------------------------------------------- #

function install_prerequisites() {
    stage 'Instalar Prerrequisitos'

    if [[ "${USE_DOCKER}" = true ]] ; then
        if ! errors=$(run_command "${DOCKER_PULL_COMMAND[@]}"); then
            fail "${DOCKER_PULL_COMMAND[*]}" "${errors}" true
            exit "${EXIT_VALUE}"
        else
            success "${DOCKER_PULL_COMMAND[*]}"
        fi
    else
        if ! "${DOCKER_RUN_COMMAND[@]}" --help &> /dev/null; then
            if ! errors=$(run_command "${DOCKER_PULL_COMMAND[@]}"); then
                fail "${DOCKER_PULL_COMMAND[*]}" "${errors}" true
                exit "${EXIT_VALUE}"
            else
                success "${DOCKER_PULL_COMMAND[*]}"
            fi
        else
            success "${DOCKER_RUN_COMMAND[*]} ya está instalado"
        fi
    fi
}

function get_version_information() {
    local output

    if [[ "${USE_DOCKER}" = true ]] ; then
        output=$(run_command docker run "${DOCKER_IMAGE}" "${DOCKER_IMAGE_SHORT}" --version)
    else
        output=$(run_command "${DOCKER_RUN_COMMAND[@]}" --version)
    fi
    
    VERSION=$(echo "${output}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    
    if [[ -z "${VERSION}" ]]; then
        VERSION="1.0.0"
    fi
    
    BANNER="Ejecutar ${TOOL_NAME} (v${VERSION})"
}

# -------------------------------------------------------------------------------- #
# Funciones Principales                                                             #
# -------------------------------------------------------------------------------- #

function setup() {
    export TERM=xterm
    handle_color_parameters
    setup_colors
    CURRENT_STAGE=0
    EXIT_VALUE=0
}

function setup_colors() {
    screen_width=0
    if [[ "${NO_COLOR}" == false ]]; then
        screen_width=$(tput cols)
        screen_width=$((screen_width - 2))
        
        bold_text=$(tput bold)
        reset=$(tput sgr0)
        black_text=$(tput setaf 0)
        red_text=$(tput setaf 1)
        green_text=$(tput setaf 2)
        yellow_text=$(tput setaf 3)
        blue_text=$(tput setaf 4)
        magenta_text=$(tput setaf 5)
        cyan_text=$(tput setaf 6)
        white_text=$(tput setaf 7)
    else
        bold_text='' reset='' black_text='' red_text='' 
        green_text='' yellow_text='' blue_text='' magenta_text='' 
        cyan_text='' white_text=''
    fi

    (( screen_width < 140 )) && screen_width=140
}

function handle_color_parameters() {
    if [[ -n "${NO_COLOR-}" ]]; then
        case "${NO_COLOR}" in
            [Tt][Rr][Uu][Ee]|[Yy]|[Yy][Ee][Ss]|1)
                NO_COLOR=true
                ;;
            *)
                NO_COLOR=false
                ;;
        esac
    else
        NO_COLOR=false
    fi
}

function display_parameters() {
    local parameters=false
    [[ "${SHOW_ERRORS}" == false ]] && {
        echo " Mostrar Errores: ${cyan_text}false${reset}"
        parameters=true
    }

    [[ "${parameters}" != true ]] && echo " No se dieron parámetros"
}

function scan_files() {
    while IFS= read -r filename; do
        if file -b "${filename}" | grep -qE "${FILE_TYPE_PATTERN}" || \
           [[ "${filename}" =~ ${FILE_NAME_PATTERN} ]]; then
            check "${filename}"
        fi
    done < <(find "${SEARCH_ROOT}" -type f -not -path "./.git/*" | sed 's|^./||' | sort -Vf || true)
}

function footer() {
    stage 'Reporte'
    echo " ${bold_text}Total${reset}: ${file_count}, ${bold_text}${green_text}OK${reset}: ${ok_count}, ${bold_text}${red_text}Fallidos${reset}: ${fail_count}, ${bold_text}${yellow_text}Omitidos${reset}: ${skip_count}"
    stage 'Completo'
}

# -------------------------------------------------------------------------------- #
# Ejecución Principal                                                               #
# -------------------------------------------------------------------------------- #

setup
show_banner
install_prerequisites
get_version_information
stage "${BANNER}"
scan_files
footer

EXIT_VALUE=0
exit "${EXIT_VALUE}"