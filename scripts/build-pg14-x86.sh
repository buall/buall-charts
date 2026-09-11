#!/usr/bin/env bash
#
# build-pg14-x86.sh — build the PostgreSQL 14 x86 (amd64) extension image
# on the Vultr remote. Intended to run ON the remote server.
#
# The Dockerfile (images/postgres-extensions/14/Dockerfile) must be present
# in the build directory before running this script. It pulls the base image
# and all extension sources at build time, so no other local files are needed.
#
# Usage:
#   BUILD_DIR=/tmp/pg14-build PG_TAG=postgres-extensions:14.24 bash build-pg14-x86.sh
#
set -euo pipefail

BUILD_DIR="${BUILD_DIR:-/tmp/pg14-build}"
PG_TAG="${PG_TAG:-postgres-extensions:14.24}"
PG_VERSION="${PG_VERSION:-14.24}"
PLATFORM="${PLATFORM:-linux/amd64}"

echo "==> Build directory : ${BUILD_DIR}"
echo "==> Image tag       : ${PG_TAG}"
echo "==> PG version      : ${PG_VERSION}"
echo "==> Target platform : ${PLATFORM}"

mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

if [[ ! -f Dockerfile ]]; then
  echo "ERROR: Dockerfile not found in ${BUILD_DIR}. Upload images/postgres-extensions/14/Dockerfile first." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not installed/available on this host." >&2
  exit 1
fi

echo "==> Starting docker build (this compiles TimescaleDB, pg_cron, pgAudit, repmgr — can take 10-20 min)..."
docker build \
  --platform "${PLATFORM}" \
  --build-arg "POSTGRESQL_VERSION=${PG_VERSION}" \
  -t "${PG_TAG}" \
  .

echo "==> Build complete. Image:"
docker images "${PG_TAG}"

echo "==> Verifying extensions are present in the image:"
docker run --rm --platform "${PLATFORM}" "${PG_TAG}" \
  bash -c 'ls /usr/lib/postgresql/*/lib/ | grep -E "timescaledb|pgaudit|pg_cron|repmgr" || true'
