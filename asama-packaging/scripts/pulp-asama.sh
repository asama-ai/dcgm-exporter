#!/usr/bin/env bash
# Always pass --api-root on the CLI. pulp-cli 0.40 defaults --api-root to /pulp/,
# which Console Dex-redirects; config-file api_root is not enough.
set -euo pipefail
cfg="${PULP_CLI_CONFIG:-${HOME}/.config/pulp/cli.toml}"
: "${PULP_CLI_BASE_URL:?PULP_CLI_BASE_URL is required}"
: "${PULP_API_ROOT:?PULP_API_ROOT is required}"
exec pulp \
  --config "$cfg" \
  --base-url "$PULP_CLI_BASE_URL" \
  --api-root "$PULP_API_ROOT" \
  "$@"
