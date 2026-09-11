#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <working_directory> [bin_directory]"
    exit 1
fi

DEB_DIR="$1"
BIN_DIR="${2:-build/bin}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PKG="${ROOT}/asama-packaging"

echo "Creating DCGM DEB package structure in ${DEB_DIR}..."

mkdir -p "${DEB_DIR}/opt/asama.ai/bin"
mkdir -p "${DEB_DIR}/opt/asama.ai/config"
mkdir -p "${DEB_DIR}/etc/systemd/system"

if [ ! -f "${BIN_DIR}/dcgm-exporter" ]; then
    echo "ERROR: ${BIN_DIR}/dcgm-exporter not found"
    exit 1
fi

cp "${BIN_DIR}/dcgm-exporter" "${DEB_DIR}/opt/asama.ai/bin/"
cp "${PKG}/systemd/asama-dcgm-exporter.service" "${DEB_DIR}/etc/systemd/system/"
cp "${PKG}/systemd/asama-dcgm-exporter@.service" "${DEB_DIR}/etc/systemd/system/"
cp "${PKG}/config/dcgm-counters-identity.csv" "${DEB_DIR}/opt/asama.ai/config/"
cp "${PKG}/config/dcgm-counters-health.csv" "${DEB_DIR}/opt/asama.ai/config/"
cp "${PKG}/config/dcgm-counters-analysis.csv" "${DEB_DIR}/opt/asama.ai/config/"
cp "${PKG}/config/dcgm-exporter-identity.env" "${DEB_DIR}/opt/asama.ai/config/"
cp "${PKG}/config/dcgm-exporter-health.env" "${DEB_DIR}/opt/asama.ai/config/"
cp "${PKG}/config/dcgm-exporter-analysis.env" "${DEB_DIR}/opt/asama.ai/config/"

echo "DCGM DEB package structure prepared successfully"
