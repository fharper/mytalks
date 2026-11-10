#!/usr/bin/env bash
set -euo pipefail

# Prevent Corepack from blocking based on a parent directory's packageManager field
export COREPACK_ENABLE_STRICT=0

DEMO_DIR="docusaurus"
BASE_SNAPSHOT="docusaurus-base.tgz"

# Cache mode: WARM by default (reuses npm's real cache -> fast, good for live demos).
# Pass --cold for a throwaway cache -> full download, for benchmarking.
CACHE_ARGS=()
MODE="warm"
if [ "${1:-}" = "--cold" ]; then
  MODE="cold"
  COLD_CACHE="$(mktemp -d /tmp/npm-cold-XXXXXX)"
  trap 'rm -rf "$COLD_CACHE"' EXIT
  CACHE_ARGS=(--cache "$COLD_CACHE")
fi

echo "================================================"
echo "  Docusaurus demo — npm  (${MODE} install)"
echo "================================================"

# 1. Restore the pristine base snapshot (run setup.sh first)
echo ""
echo "[1/2] Restoring ./${DEMO_DIR} from the base snapshot..."
if [ ! -f "${BASE_SNAPSHOT}" ]; then
  echo "  ERROR: ${BASE_SNAPSHOT} not found. Run ./setup.sh first." >&2
  exit 1
fi
rm -rf "${DEMO_DIR}"
mkdir "${DEMO_DIR}"
tar xzf "${BASE_SNAPSHOT}" -C "${DEMO_DIR}"
cd "${DEMO_DIR}"

# 2. Install
echo "[2/2] Running npm install..."
echo ""
start=$(python3 -c "import time; print(int(time.time()*1000))")
# --ignore-scripts: parity with the other managers (lifecycle scripts disabled everywhere)
# --no-audit --no-fund: npm-only extra work the others don't do
npm install --loglevel=error --ignore-scripts --no-audit --no-fund "${CACHE_ARGS[@]}"
end=$(python3 -c "import time; print(int(time.time()*1000))")
elapsed=$(python3 -c "print(round(($end - $start) / 1000, 2))")

# Stats
NPM_VERSION=$(npm --version)
TOP_LEVEL=$(ls node_modules | grep -v '^\.' | wc -l | tr -d ' ')
NM_SIZE=$(du -sh node_modules | cut -f1)
STATS=$(python3 - << 'PYSTATS'
import json
from collections import defaultdict
pkg = json.load(open('package.json'))
declared = len(pkg.get('dependencies', {})) + len(pkg.get('devDependencies', {}))
d = json.load(open('package-lock.json'))
versions = defaultdict(set)
for path, meta in d['packages'].items():
    if not path: continue
    name = path.split('node_modules/')[-1]
    if meta.get('version'):
        versions[name].add(meta['version'])
total = sum(len(v) for v in versions.values())
dup = sum(1 for v in versions.values() if len(v) > 1)
print(f"{declared}|{total}|{dup}")
PYSTATS
)
DECLARED=$(echo "$STATS" | cut -d'|' -f1)
RESOLVED=$(echo "$STATS" | cut -d'|' -f2)
DUPED=$(echo "$STATS" | cut -d'|' -f3)

echo ""
echo "================================================"
echo "  Done!  (npm)"
echo "================================================"
echo "  Package manager:    npm ${NPM_VERSION}"
echo "  Install time:       ${elapsed}s"
echo "  Lockfile:           package-lock.json"
echo ""
echo "  Declared deps:      ${DECLARED}"
echo "  Total dependencies: ${RESOLVED}"
echo "  Duplicated:         ${DUPED}  (same package, >1 version)"
echo "  Top-level folders:  ${TOP_LEVEL}"
echo "  node_modules size:  ${NM_SIZE}"
echo "================================================"
