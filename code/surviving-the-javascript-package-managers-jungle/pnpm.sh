#!/usr/bin/env bash
set -euo pipefail

# Prevent Corepack from blocking based on a parent directory's packageManager field
export COREPACK_ENABLE_STRICT=0

DEMO_DIR="docusaurus"
BASE_SNAPSHOT="docusaurus-base.tgz"

# Cache mode: WARM by default (reuses pnpm's real global store -> fast, good for live demos).
# Pass --cold for a throwaway store -> full download, for benchmarking.
CACHE_ARGS=()
MODE="warm"
if [ "${1:-}" = "--cold" ]; then
  MODE="cold"
  COLD_CACHE="$(mktemp -d /tmp/pnpm-cold-XXXXXX)"
  trap 'rm -rf "$COLD_CACHE"' EXIT
  # --store-dir alone is NOT fully cold: pnpm keeps resolved registry metadata in a
  # separate cache (~/Library/Caches/pnpm on macOS) and reuses it across runs.
  # --config.cache-dir sends that metadata cache to the throwaway dir too.
  CACHE_ARGS=(--store-dir "$COLD_CACHE/store" --config.cache-dir="$COLD_CACHE/cache")
fi

echo "================================================"
echo "  Docusaurus demo — pnpm  (${MODE} install)"
echo "================================================"

# 1. Restore the pristine base snapshot (run setup.sh first)
echo ""
echo "[1/3] Restoring ./${DEMO_DIR} from the base snapshot..."
if [ ! -f "${BASE_SNAPSHOT}" ]; then
  echo "  ERROR: ${BASE_SNAPSHOT} not found. Run ./setup.sh first." >&2
  exit 1
fi
rm -rf "${DEMO_DIR}"
mkdir "${DEMO_DIR}"
tar xzf "${BASE_SNAPSHOT}" -C "${DEMO_DIR}"
cd "${DEMO_DIR}"

# 2. Check pnpm (--ignore-workspace so a parent workspace/packageManager can't interfere)
echo "[2/3] Checking pnpm..."
if ! command -v pnpm &>/dev/null; then
  echo "      pnpm not found — installing via npm..."
  npm install -g pnpm --loglevel=error
fi
PNPM_VERSION=$(pnpm --version --ignore-workspace)
echo "      pnpm ${PNPM_VERSION} ready"

# 3. Install
echo "[3/3] Running pnpm install..."
echo ""
start=$(python3 -c "import time; print(int(time.time()*1000))")
pnpm install --ignore-scripts --ignore-workspace "${CACHE_ARGS[@]}"
end=$(python3 -c "import time; print(int(time.time()*1000))")
elapsed=$(python3 -c "print(round(($end - $start) / 1000, 2))")

# Stats
TOP_LEVEL=$(ls node_modules | grep -v '^\.' | wc -l | tr -d ' ')
NM_SIZE=$(du -sh node_modules | cut -f1)
if [ "$MODE" = "warm" ]; then
  STORE_PATH=$(pnpm store path --ignore-workspace 2>/dev/null)
  STORE_SIZE=$(du -sh "$STORE_PATH" 2>/dev/null | cut -f1 || echo "n/a")
else
  STORE_SIZE=$(du -sh "$COLD_CACHE/store" 2>/dev/null | cut -f1 || echo "n/a")
fi
STATS=$(python3 - << 'PYSTATS'
import json, re
from collections import defaultdict
pkg = json.load(open('package.json'))
declared = len(pkg.get('dependencies', {})) + len(pkg.get('devDependencies', {}))
text = open('pnpm-lock.yaml').read()
versions = defaultdict(set)
for m in re.finditer(r"^  (?:'?)((?:@[^/]+/)?[^@'\s]+)@([^':\s()]+)", text, re.MULTILINE):
    versions[m.group(1)].add(m.group(2))
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
echo "  Done!  (pnpm)"
echo "================================================"
echo "  Package manager:    pnpm ${PNPM_VERSION}"
echo "  Install time:       ${elapsed}s"
echo "  Lockfile:           pnpm-lock.yaml"
echo ""
echo "  Declared deps:      ${DECLARED}"
echo "  Total dependencies: ${RESOLVED}"
echo "  Duplicated:         ${DUPED}  (same package, >1 version)"
echo "  Top-level folders:  ${TOP_LEVEL}"
echo "  node_modules size:  ${NM_SIZE}"
echo "  Global store size:  ${STORE_SIZE}"
echo "================================================"
