#!/usr/bin/env bash
set -euo pipefail

# Prevent Corepack from blocking based on a parent directory's packageManager field
export COREPACK_ENABLE_STRICT=0

DEMO_DIR="docusaurus"
BASE_SNAPSHOT="docusaurus-base.tgz"

# Cache mode: WARM by default (reuses Bun's real cache -> fast, good for live demos).
# Pass --cold for a throwaway cache -> full download, for benchmarking.
CACHE_ARGS=()
MODE="warm"
if [ "${1:-}" = "--cold" ]; then
  MODE="cold"
  COLD_CACHE="$(mktemp -d /tmp/bun-cold-XXXXXX)"
  trap 'rm -rf "$COLD_CACHE"' EXIT
  CACHE_ARGS=(--cache-dir "$COLD_CACHE")
fi

echo "================================================"
echo "  Docusaurus demo — Bun  (${MODE} install)"
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

# 2. Check Bun
echo "[2/3] Checking Bun..."
if ! command -v bun &>/dev/null; then
  echo "      Bun not found — installing..."
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
fi
BUN_VERSION=$(bun --version)
echo "      Bun ${BUN_VERSION} ready"

# 3. Install
echo "[3/3] Running bun install..."
echo ""
start=$(python3 -c "import time; print(int(time.time()*1000))")
# --ignore-scripts: parity — dependency scripts are blocked by default in Bun,
# this also skips the project's own lifecycle scripts like the other managers
bun install --ignore-scripts "${CACHE_ARGS[@]}"
end=$(python3 -c "import time; print(int(time.time()*1000))")
elapsed=$(python3 -c "print(round(($end - $start) / 1000, 2))")

# Stats
TOP_LEVEL=$(ls node_modules | grep -v '^\.' | wc -l | tr -d ' ')
NM_SIZE=$(du -sh node_modules | cut -f1)
STATS=$(python3 - << 'PYSTATS'
import json, re
from collections import defaultdict
pkg = json.load(open('package.json'))
declared = len(pkg.get('dependencies', {})) + len(pkg.get('devDependencies', {}))
text = open('bun.lock').read()
clean = re.sub(r',(\s*[}\]])', r'\1', text)  # strip trailing commas -> valid JSON
d = json.loads(clean)
versions = defaultdict(set)
for key, val in d.get('packages', {}).items():
    ident = val[0] if isinstance(val, list) and val else key
    m = re.match(r'((?:@[^/]+/)?[^@]+)@(.+)', ident)
    if m:
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
echo "  Done!  (Bun)"
echo "================================================"
echo "  Package manager:    bun ${BUN_VERSION}"
echo "  Install time:       ${elapsed}s"
echo "  Lockfile:           bun.lock"
echo ""
echo "  Declared deps:      ${DECLARED}"
echo "  Total dependencies: ${RESOLVED}"
echo "  Duplicated:         ${DUPED}  (same package, >1 version)"
echo "  Top-level folders:  ${TOP_LEVEL}"
echo "  node_modules size:  ${NM_SIZE}"
echo "================================================"
