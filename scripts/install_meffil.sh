#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ts="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="${REPO_ROOT}/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/install_meffil_${ts}.log"

exec >>"${LOG_FILE}" 2>&1
echo "[install_meffil.sh] logging to ${LOG_FILE}" >&2

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

export PKG_CONFIG_PATH="${ENV_DIR_ABS}/lib/pkgconfig:${ENV_DIR_ABS}/share/pkgconfig:${PKG_CONFIG_PATH-}"

export TMPDIR="${ENV_DIR_ABS}/tmp"
mkdir -p "${TMPDIR}"

INSTALLER="${REPO_ROOT}/install_meffil_only.R"

if [[ ! -f "${INSTALLER}" ]]; then
    echo "❌ Installer script missing at ${INSTALLER}." >&2
    exit 1
fi

ARCH_CMD=(arch -x86_64 /bin/bash -lc)
RUN_CMD="'"${RSCRIPT}"' '"${INSTALLER}"'"

"${ARCH_CMD[@]}" "${RUN_CMD}"
