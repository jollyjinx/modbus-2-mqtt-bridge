#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
REVISION="${1:-HEAD}"

version="$(git -C "${REPO_ROOT}" show -s --format='%cd' --date=format:'%Y.%m.%d.%H%M%S' "${REVISION}")"
if [[ ! "${version}" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]{6}$ ]]; then
  echo "error: could not derive a YYYY.MM.DD.HHMMSS version from ${REVISION}" >&2
  exit 1
fi

printf '%s\n' "${version}"
