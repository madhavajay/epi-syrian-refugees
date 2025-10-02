#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

mkdir -p "${REPO_ROOT}/logs"
ts="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${REPO_ROOT}/logs/install_cairo_${ts}.log"

exec >>"${LOG_FILE}" 2>&1
echo "[install_cairo.sh] logging to ${LOG_FILE}" >&2

ENV_DIR="${REPO_ROOT}/envs/epigenetic-violence-analysis"
RSCRIPT="${ENV_DIR}/bin/Rscript"

if [[ ! -x "${RSCRIPT}" ]]; then
    echo "❌ Rscript not found at ${RSCRIPT}. Run ./setup_environment.sh first." >&2
    exit 1
fi

ENV_DIR_ABS="$(cd "${ENV_DIR}" && pwd)"
PATCH_HEADER="${REPO_ROOT}/tools/char_traits_patch.h"

if [[ ! -f "${PATCH_HEADER}" ]]; then
    echo "❌ Compatibility header missing at ${PATCH_HEADER}." >&2
    exit 1
fi

if command -v xcrun >/dev/null 2>&1; then
    export SDKROOT="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null)"
fi

for var in PKG_CPPFLAGS CPPFLAGS CFLAGS CXXFLAGS CXX11FLAGS CXX14FLAGS CXX17FLAGS CXX20FLAGS; do
    current="${!var-}"
    flag="-include ${PATCH_HEADER}"
    case " ${current} " in
        *"${flag}"*) : ;;
        *) export ${var}="${flag} ${current}" ;;
    esac
done

export PATH="${ENV_DIR_ABS}/bin:${PATH}"
export PKG_CONFIG="${ENV_DIR_ABS}/bin/pkg-config"
export PKG_CONFIG_PATH="${ENV_DIR_ABS}/lib/pkgconfig:${ENV_DIR_ABS}/share/pkgconfig:${PKG_CONFIG_PATH-}"

export TMPDIR="${ENV_DIR_ABS}/tmp"
mkdir -p "${TMPDIR}"

ensure_cairo_pc() {
    if pkg-config --exists cairo; then
        return 0
    fi

    echo "[install_cairo.sh] pkg-config could not resolve cairo; displaying diagnostics" >&2
    pkg-config --print-errors --exists cairo || true

    if ! command -v micromamba >/dev/null 2>&1; then
        echo "⚠ micromamba not found; cannot auto-install missing libraries." >&2
        return 1
    fi

    echo "[install_cairo.sh] Attempting to install cairo toolchain into micromamba env" >&2
    if [[ "$(uname -m)" == "arm64" ]]; then
        export CONDA_SUBDIR=osx-64
    fi

    micromamba install -y -p "${ENV_DIR_ABS}" \
        cairo pkg-config fontconfig expat freetype pixman glib pango harfbuzz libpng || true
    hash -r

    if pkg-config --exists cairo; then
        return 0
    fi

    echo "[install_cairo.sh] pkg-config still cannot resolve cairo after micromamba install." >&2
    pkg-config --print-errors --exists cairo || true
    return 1
}

if ! ensure_cairo_pc; then
    echo "❌ Unable to satisfy cairo pkg-config dependencies." >&2
    exit 1
fi

if ! command -v pkg-config >/dev/null 2>&1; then
    echo "❌ pkg-config still not available on PATH after setup." >&2
    exit 1
fi

echo "[install_cairo.sh] Using pkg-config at $(command -v pkg-config)"
echo "[install_cairo.sh] Detected cairo includes: $(pkg-config --cflags cairo 2>/dev/null)"
echo "[install_cairo.sh] Detected cairo libs: $(pkg-config --libs cairo 2>/dev/null)"

INSTALLER="${REPO_ROOT}/install_cairo_only.R"
if [[ ! -f "${INSTALLER}" ]]; then
    echo "❌ Installer script missing at ${INSTALLER}." >&2
    exit 1
fi

ARCH_CMD=(arch -x86_64 /bin/bash -lc)
RUN_CMD="'"${RSCRIPT}"' '"${INSTALLER}"'"

"${ARCH_CMD[@]}" "${RUN_CMD}"
