#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "usage: $0 <branch-name>" >&2
  exit 64
fi

branch_name="$1"
branch_tag="$(
  printf '%s' "${branch_name}" |
    LC_ALL=C tr '[:upper:]' '[:lower:]' |
    LC_ALL=C sed -E \
      -e 's/[^a-z0-9_.-]+/-/g' \
      -e 's/^[.-]+//' \
      -e 's/[.-]+$//'
)"

if [ -z "${branch_tag}" ]; then
  checksum="$(printf '%s' "${branch_name}" | cksum | awk '{print $1}')"
  branch_tag="branch-${checksum}"
fi

printf '%s\n' "${branch_tag:0:128}"
