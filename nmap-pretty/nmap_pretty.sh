#!/usr/bin/env bash
# nmap_pretty.sh - Parseador y coloreador mejorado para salida de nmap
# Uso: nmap_pretty.sh [-j] <archivo_nmap>
#   -j  : salida en JSON (una sola línea JSON por host)

set -euo pipefail

# --- argumentos ---
OUT_JSON=0
if [[ "${1:-}" == "-j" ]]; then
  OUT_JSON=1
  shift
fi

if [ -z "${1:-}" ]; then
  echo "Uso: $0 [-j] <archivo_nmap>"
  exit 1
fi
input_file="$1"
if [ ! -f "$input_file" ]; then
  echo "El archivo $input_file no existe."
  exit 1
fi

# --- Colores (tput si está, fallback ANSI) ---
if command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
  BOLD="$(tput bold)"
  RESET="$(tput sgr0)"
  CLR_BLUE="$(tput setaf 4)"
  CLR_CYAN="$(tput setaf 6)"
  CLR_GREEN="$(tput setaf 2)"
  CLR_YELLOW="$(tput setaf 3)"
  CLR_RED="$(tput setaf 1)"
  CLR_MAG="$(tput setaf 5)"
  CLR_WHITE="$(tput setaf 7)"
else
  BOLD="\e[1m"; RESET="\e[0m"
  CLR_BLUE="\e[34m"; CLR_CYAN="\e[36m"; CLR_GREEN="\e[32m"; CLR_YELLOW="\e[33m"
  CLR_RED="\e[31m"; CLR_MAG="\e[35m"; CLR_WHITE="\e[37m"
fi

# Colores por estado (más legibles)
COLOR_FOR_OPEN="${BOLD}${CLR_GREEN}"
COLOR_FOR_FILTERED="${BOLD}${CLR_YELLOW}"
COLOR_FOR_CLOSED="${BOLD}${CLR_RED}"
COLOR_FOR_UNKNOWN="${BOLD}${CLR_CYAN}"

# --- Funciones auxiliares ---
join_from_index() {
  # join array elements from index N onward with " "
  local -n arr=$1
  local start=$2
  local out=""
  for ((i=start;i<${#arr[@]};i++)); do
    out+="${arr[i]}"
    if (( i < ${#arr[@]}-1 )); then out+=" "; fi
  done
  echo "$out"
}

# --- Extraer información del host (primera ocurrencia) ---
host_line=$(grep -m1 "^Host:" "$input_file" || true)
# Si no hay "Host:" intenta con "Nmap scan report for"
if [ -z "$host_line" ]; then
  host_line=$(grep -m1 "^Nmap scan report for" "$input_file" || true)
fi

host=""
status=""
if [ -n "$host_line" ]; then
  # Formatos posibles:
  # Host: 10.10.11.72 ()    Status: Up
  # Nmap scan report for 10.10.11.72
  if echo "$host_line" | grep -q "^Host:"; then
    host=$(echo "$host_line" | awk '{print $2}')
    status=$(echo "$host_line" | awk '{for(i=1;i<=NF;i++) if($i~/Status:/) print $(i+1)}' | tr -d '()' || true)
  else
    host=$(echo "$host_line" | awk '{print $NF}')
  fi
fi

# --- Extraer "Ports:" (puede haber varias líneas; combinamos) ---
ports_field=$(grep "Ports:" "$input_file" | sed -E 's/.*Ports: //g' | tr '\n' ',' | sed 's/,$//')
# Si hay líneas continuadas sin "Ports:" (versión larga), intentamos tomar líneas entre "Ports:" y siguiente "# " o EOF
if [ -z "$ports_field" ]; then
  # fallback: tratar todo el archivo buscando patrones tipo "number/open/..."
  ports_field=$(tr '\n' ' ' < "$input_file" | grep -oE '[0-9]{1,5}\/[a-z]+\/[a-z]+([^,]*)' || true)
fi

# --- Capturar "Ignored State:" si existe ---
ignored_state=$(grep -oE "Ignored State:.*" "$input_file" || true)

# --- Preparar arrays de puertos ---
IFS=',' read -ra ports_array <<< "$ports_field"

# Resultado en JSON si se solicita
if (( OUT_JSON == 1 )); then
  # Construimos JSON simple (no requiere jq)
  json_host="{\"host\":\"${host}\",\"status\":\"${status}\",\"ports\":["
  firstp=1
  for raw in "${ports_array[@]}"; do
    raw="$(echo "$raw" | sed 's/^[ \t]*//;s/[ \t]*$//')"
    # Ignorar vacíos
    [ -z "$raw" ] && continue
    # Normalizar multiples slashes en espacios marcadores
    IFS='/' read -ra parts <<< "$raw"
    port_proto="${parts[0]:-}"
    state="${parts[1]:-}"
    proto="${parts[2]:-}"
    service="${parts[4]:-}"
    # versión: juntar desde parts[5] en adelante
    version=""
    if [ "${#parts[@]}" -gt 5 ]; then
      for ((i=5;i<${#parts[@]};i++)); do
        version+="${parts[i]}"
        if (( i < ${#parts[@]}-1 )); then version+=" "; fi
      done
    fi
    # Escape JSON strings (básico)
    esc_raw=$(printf '%s' "$raw" | sed 's/\\/\\\\/g; s/"/\\"/g')
    esc_service=$(printf '%s' "$service" | sed 's/\\/\\\\/g; s/"/\\"/g')
    esc_version=$(printf '%s' "$version" | sed 's/\\/\\\\/g; s/"/\\"/g')
    if (( firstp == 0 )); then json_host+=", "; else firstp=0; fi
    json_host+="{\"port_proto\":\"${port_proto}\",\"state\":\"${state}\",\"proto\":\"${proto}\",\"service\":\"${esc_service}\",\"version\":\"${esc_version}\",\"raw\":\"${esc_raw}\"}"
  done
  json_host+="],\"ignored\":\"$(printf '%s' "$ignored_state" | sed 's/"/\\"/g')\"}"
  echo "$json_host"
  exit 0
fi

# --- Imprimir cabecera y leyenda ---
echo -e "${BOLD}${CLR_BLUE}Información del Host:${RESET}"
echo -e "  Host: ${BOLD}${CLR_MAG}${host}${RESET}"
if [ -n "$status" ]; then
  st_lower=$(echo "$status" | tr '[:upper:]' '[:lower:]')
  if [[ "$st_lower" =~ up|open ]]; then
    echo -e "  Status: ${COLOR_FOR_OPEN}${status}${RESET}"
  else
    echo -e "  Status: ${COLOR_FOR_CLOSED}${status}${RESET}"
  fi
else
  echo -e "  Status: ${COLOR_FOR_UNKNOWN}unknown${RESET}"
fi
echo

# Encabezado de tabla
printf "${BOLD}${CLR_CYAN}  %-9s %-9s %-6s %-18s %s${RESET}\n" "PORT" "STATE" "PROTO" "SERVICE" "VERSION/EXTRA"
printf "  %s\n" "  -------------------------------------------------------------------------------"

# --- Procesar puertos y mostrar ---
for raw in "${ports_array[@]}"; do
  raw="$(echo "$raw" | sed 's/^[ \t]*//;s/[ \t]*$//')"
  [ -z "$raw" ] && continue

  # Algunas líneas traen '/' consecutivos, o espacios; separamos por '/'
  IFS='/' read -ra parts <<< "$raw"

  port_proto="${parts[0]:-}"   # ej. 53
  state="${parts[1]:-}"        # ej. open
  proto="${parts[2]:-}"        # ej. tcp
  # service puede estar en parts[4], pero si el formato varía lo normalizamos
  service="${parts[4]:-}"
  # version/extra: unir desde parts[5] en adelante
  version=""
  if [ "${#parts[@]}" -gt 5 ]; then
    for ((i=5;i<${#parts[@]};i++)); do
      version+="${parts[i]}"
      if (( i < ${#parts[@]}-1 )); then version+=" "; fi
    done
  fi

  # Si service está vacío, intentamos tomar el tercer campo separado por espacios (por si no hay slash estándar)
  if [ -z "$service" ]; then
    service=$(echo "$raw" | awk '{print $3}' || true)
  fi

  # Normalizar campos para impresión
  port_display="$port_proto"
  state_display="${state:-unknown}"
  proto_display="${proto:--}"
  service_display="${service:--}"
  version_display="${version:--}"

  # Colorear según estado
  case "${state_display,,}" in
    open) color="${COLOR_FOR_OPEN}" ;;
    filtered|filtered\(*|filtered\) ) color="${COLOR_FOR_FILTERED}" ;;
    closed) color="${COLOR_FOR_CLOSED}" ;;
    *) color="${COLOR_FOR_UNKNOWN}" ;;
  esac

  # Imprimir con columnas alineadas
  printf "  %-9s %s%-9s%s %-6s %-18s %s\n" \
    "$port_display" "$color" "$state_display" "$RESET" "$proto_display" "$service_display" "$version_display"
done

# --- Imprimir ignored/state si existe ---
if [ -n "$ignored_state" ]; then
  echo
  echo -e "${BOLD}${CLR_YELLOW}  Nota:${RESET} ${CLR_YELLOW}${ignored_state}${RESET}"
fi

# --- Footer / Leyenda ---
echo
echo -e "${BOLD}Leyenda:${RESET} ${COLOR_FOR_OPEN}open${RESET} ${COLOR_FOR_FILTERED}filtered${RESET} ${COLOR_FOR_CLOSED}closed${RESET} ${COLOR_FOR_UNKNOWN}unknown${RESET}"
