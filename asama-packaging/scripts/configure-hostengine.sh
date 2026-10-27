#!/bin/bash
# Use a running nv-hostengine, or start asama-nv-hostengine on 127.0.0.1:5555.
# A second engine cannot share the GPUs, including on another port.
set -euo pipefail

config_dir=/opt/asama.ai/config
unit=asama-nv-hostengine.service
default_endpoint=127.0.0.1:5555

endpoint_from_local() {
  local local="$1" host port
  case "$local" in
    \[*\]:*)
      host="${local%:*}"
      port="${local##*:}"
      ;;
    *:*)
      host="${local%:*}"
      port="${local##*:}"
      ;;
    *)
      return 1
      ;;
  esac
  case "$port" in
    ''|*[!0-9]*) return 1 ;;
  esac
  case "$host" in
    0.0.0.0|\*|'[::]'|ALL|all) printf '127.0.0.1:%s\n' "$port" ;;
    *) printf '%s:%s\n' "$host" "$port" ;;
  esac
}

endpoint_from_args() {
  local port=5555 bind=0.0.0.0 prev= word
  for word in "$@"; do
    case "$prev" in
      -p|--port) port="$word"; prev=; continue ;;
      -b|--bind-interface) bind="$word"; prev=; continue ;;
    esac
    case "$word" in
      -p|--port|-b|--bind-interface) prev="$word" ;;
      --port=*) port="${word#--port=}" ;;
      --bind-interface=*) bind="${word#--bind-interface=}" ;;
    esac
  done
  case "$bind" in
    ''|0.0.0.0|\*|ALL|all) printf '127.0.0.1:%s\n' "$port" ;;
    *) printf '%s:%s\n' "$bind" "$port" ;;
  esac
}

# Prints "pid endpoint" for the first nv-hostengine listener.
parse_ss_line() {
  local line="$1" local_addr pid endpoint
  case "$line" in
    *nv-hostengine*) ;;
    *) return 1 ;;
  esac
  local_addr=$(printf '%s\n' "$line" | awk '{print $4}')
  pid=$(printf '%s\n' "$line" | sed -n 's/.*pid=\([0-9][0-9]*\).*/\1/p')
  endpoint=$(endpoint_from_local "$local_addr") || return 1
  printf '%s %s\n' "${pid:-0}" "$endpoint"
}

find_listener() {
  local line pid args
  if command -v ss >/dev/null 2>&1; then
    while IFS= read -r line; do
      if parse_ss_line "$line"; then
        return 0
      fi
    done < <(ss -H -ltnp 2>/dev/null || true)
  fi
  if command -v ps >/dev/null 2>&1; then
    while IFS= read -r line; do
      line=${line#"${line%%[![:space:]]*}"}
      [ -n "$line" ] || continue
      pid=${line%% *}
      args=${line#"${pid}"}
      # shellcheck disable=SC2086
      printf '%s %s\n' "$pid" "$(endpoint_from_args $args)"
      return 0
    done < <(ps -C nv-hostengine -o pid= -o args= 2>/dev/null || true)
  fi
  return 1
}

set_endpoint() {
  local endpoint="$1" name file
  for name in identity health analysis; do
    file="${config_dir}/dcgm-exporter-${name}.env"
    [ -f "$file" ] || continue
    if grep -q '^DCGM_REMOTE_HOSTENGINE_INFO=' "$file"; then
      # Write through the existing file so owner and mode stay as installed.
      local tmp
      tmp=$(mktemp)
      sed "s|^DCGM_REMOTE_HOSTENGINE_INFO=.*|DCGM_REMOTE_HOSTENGINE_INFO=${endpoint}|" "$file" > "$tmp"
      cat "$tmp" > "$file"
      rm -f "$tmp"
    else
      printf 'DCGM_REMOTE_HOSTENGINE_INFO=%s\n' "$endpoint" >> "$file"
    fi
  done
}

main() {
  local found="" pid="" endpoint="$default_endpoint" our=""
  found=$(find_listener || true)
  if [ -n "$found" ]; then
    pid=${found%% *}
    endpoint=${found#* }
    our=$(systemctl show -p MainPID --value "$unit" 2>/dev/null || true)
    if [ -n "${our}" ] && [ "$our" != 0 ] && [ "$pid" = "$our" ]; then
      endpoint=$default_endpoint
      found=""
    fi
  fi
  set_endpoint "$endpoint"
  if [ -z "$found" ]; then
    systemctl enable --now "$unit" || echo "ERROR: Failed to start ${unit}" >&2
  else
    echo "[INFO] Using existing nv-hostengine at ${endpoint}"
    systemctl disable --now "$unit" >/dev/null 2>&1 || true
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
