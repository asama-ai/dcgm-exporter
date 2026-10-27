#!/bin/bash
# Use a listening nv-hostengine, or start asama-nv-hostengine on 127.0.0.1:5555.
# Keep an operator-set endpoint that is not that default.
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

# 0 when pid has a TCP listen socket at endpoint. Wildcard binds are stored as 127.0.0.1.
tcp_listener_matches() {
  local pid="$1" endpoint="$2" host port line addr
  command -v ss >/dev/null 2>&1 || return 1
  host="${endpoint%:*}"
  port="${endpoint##*:}"
  case "$port" in
    ''|*[!0-9]*) return 1 ;;
  esac
  while IFS= read -r line; do
    case "$line" in
      *"pid=${pid},"*|*"pid=${pid})"*) ;;
      *) continue ;;
    esac
    addr=$(printf '%s\n' "$line" | awk '{print $4}')
    case "$addr" in
      "${host}:${port}") return 0 ;;
    esac
    if [ "$host" = "127.0.0.1" ]; then
      case "$addr" in
        "0.0.0.0:${port}"|"[::]:${port}"|"*:${port}") return 0 ;;
      esac
    fi
  done < <(ss -H -ltnp 2>/dev/null || true)
  return 1
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
    local saw_process=0 endpoint
    while IFS= read -r line; do
      line=${line#"${line%%[![:space:]]*}"}
      [ -n "$line" ] || continue
      saw_process=1
      pid=${line%% *}
      args=${line#"${pid}"}
      # shellcheck disable=SC2086
      endpoint=$(endpoint_from_args $args)
      tcp_listener_matches "$pid" "$endpoint" || continue
      printf '%s %s\n' "$pid" "$endpoint"
      return 0
    done < <(ps -C nv-hostengine -o pid= -o args= 2>/dev/null || true)
    if [ "$saw_process" -eq 1 ]; then
      echo "ERROR: nv-hostengine process has no verified TCP listener" >&2
    fi
  fi
  return 1
}

configured_endpoint() {
  local file="$1"
  awk -F= '/^DCGM_REMOTE_HOSTENGINE_INFO=/{print substr($0, index($0, "=") + 1); exit}' "$file"
}

# 0 when any env file is missing, unset, or still the package default.
endpoint_needs_update() {
  local name file current
  for name in identity health analysis; do
    file="${config_dir}/dcgm-exporter-${name}.env"
    if [ ! -f "$file" ] || ! grep -q '^DCGM_REMOTE_HOSTENGINE_INFO=' "$file"; then
      return 0
    fi
    current=$(configured_endpoint "$file")
    if [ -z "$current" ] || [ "$current" = "$default_endpoint" ]; then
      return 0
    fi
  done
  return 1
}

set_endpoint() {
  local endpoint="$1" name file current tmp
  for name in identity health analysis; do
    file="${config_dir}/dcgm-exporter-${name}.env"
    [ -f "$file" ] || continue
    if grep -q '^DCGM_REMOTE_HOSTENGINE_INFO=' "$file"; then
      current=$(configured_endpoint "$file")
      if [ -n "$current" ] && [ "$current" != "$default_endpoint" ]; then
        continue
      fi
      # Write through the existing file so owner and mode stay as installed.
      tmp=$(mktemp)
      sed "s|^DCGM_REMOTE_HOSTENGINE_INFO=.*|DCGM_REMOTE_HOSTENGINE_INFO=${endpoint}|" "$file" > "$tmp"
      cat "$tmp" > "$file"
      rm -f "$tmp"
    else
      printf 'DCGM_REMOTE_HOSTENGINE_INFO=%s\n' "$endpoint" >> "$file"
    fi
  done
}

stop_packaged_unit() {
  local load state
  if ! load=$(systemctl show -p LoadState --value "$unit" 2>/dev/null); then
    echo "ERROR: cannot read ${unit} state" >&2
    return 1
  fi
  case "$load" in
    not-found|"") return 0 ;;
  esac
  systemctl disable --now "$unit"
  state=$(systemctl show -p ActiveState --value "$unit" 2>/dev/null || true)
  case "$state" in
    inactive|failed) return 0 ;;
  esac
  echo "ERROR: failed to stop ${unit} (state ${state:-unknown})" >&2
  return 1
}

main() {
  local found="" pid="" endpoint="$default_endpoint" our="" configure=0
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
  if endpoint_needs_update; then
    configure=1
    set_endpoint "$endpoint"
  fi
  if [ -z "$found" ]; then
    if [ "$configure" -eq 0 ]; then
      return 0
    fi
    if [ ! -x /usr/bin/nv-hostengine ]; then
      echo "ERROR: /usr/bin/nv-hostengine is not installed. Install the NVIDIA DCGM runtime that provides nv-hostengine." >&2
      return 1
    fi
    systemctl enable --now "$unit" || echo "ERROR: Failed to start ${unit}" >&2
  else
    stop_packaged_unit || return 1
    if [ "$configure" -eq 1 ]; then
      echo "[INFO] Using existing nv-hostengine at ${endpoint}"
    fi
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
