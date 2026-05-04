#!/usr/bin/env bash
# Linker flags for Asama/package builds: strip symbol tables and stamp BuildVersion
# from hack/VERSION (same semantics as Makefile's DCGM_VERSION / VERSION vars).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

set -a
# shellcheck source=/dev/null
. "${ROOT}/hack/VERSION"
set +a

printf '%s ' \
	'-s' '-w' \
	"-X main.BuildVersion=${NEW_DCGM_VERSION}-${NEW_EXPORTER_VERSION}"
