#!/usr/bin/env bash
set -euo pipefail

# Prevent Corepack from blocking based on a parent directory's packageManager field
export COREPACK_ENABLE_STRICT=0

DEMO_DIR="docusaurus"
BASE_SNAPSHOT="docusaurus-base.tgz"
YARN_VERSION="4.16.0"

# Cache mode: WARM by default (shared persistent Yarn cache + mirror -> fast, good for live demos).
# Pass --cold for throwaway cache and mirror -> full download, for benchmarking.
MODE="warm"
if [ "${1:-}" = "--cold" ]; then
  MODE="cold"
  # Cold zips go to Yarn's default location, .yarn/cache INSIDE the project: still a
  # true cold install (the project dir is recreated from the snapshot every run), and
  # .pnp.cjs gets valid relative paths so the project remains runnable afterward.
  # Only the global mirror is throwaway tmp — .pnp.cjs never references it — and the
  # mirror is off, otherwise Yarn silently copies zips from ~/.yarn/berry/cache
  # instead of downloading (verified: installs succeed fully offline).
  CACHE_DIR=""   # empty -> don't set cacheFolder, Yarn defaults to <project>/.yarn/cache
  GLOBAL_DIR="$(mktemp -d /tmp/yarn-cold-global-XXXXXX)"
  ENABLE_MIRROR="false"
  trap 'rm -rf "$GLOBAL_DIR"' EXIT
else
  # Shared, persistent cache + global mirror in the user's home (survives across runs -> fast)
  CACHE_DIR="${HOME}/.cache/yarn-berry-demo"
  GLOBAL_DIR="${HOME}/.cache/yarn-berry-demo-global"
  ENABLE_MIRROR="true"
  mkdir -p "$CACHE_DIR" "$GLOBAL_DIR"
fi

echo "================================================"
echo "  Docusaurus demo — Yarn Berry, PnP  (${MODE} install)"
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

# 2. Bootstrap Yarn Berry
echo "[2/3] Bootstrapping Yarn Berry..."
# Download the Berry CLI binary directly and invoke it via `node`. This bypasses any
# globally-installed Yarn v1 and ignores a parent package.json's "packageManager" field.
mkdir -p .yarn/releases
curl -fsSL "https://repo.yarnpkg.com/${YARN_VERSION}/packages/yarnpkg-cli/bin/yarn.js" \
  -o ".yarn/releases/yarn-${YARN_VERSION}.cjs"
YARN="node .yarn/releases/yarn-${YARN_VERSION}.cjs"

# An empty yarn.lock marks this folder as its own project root (no walking up).
touch yarn.lock
# Default Plug'n'Play: no nodeLinker line -> no node_modules, just a .pnp.cjs resolver.
# (For a classic node_modules layout instead, add: nodeLinker: node-modules)
# enableScripts: false -> parity with the other managers (lifecycle scripts disabled)
cat > .yarnrc.yml << EOF
yarnPath: .yarn/releases/yarn-${YARN_VERSION}.cjs
enableGlobalCache: false
enableScripts: false
enableMirror: ${ENABLE_MIRROR}
globalFolder: ${GLOBAL_DIR}
EOF
if [ -n "$CACHE_DIR" ]; then
  echo "cacheFolder: ${CACHE_DIR}" >> .yarnrc.yml
fi
echo "      Yarn ${YARN_VERSION} ready (local binary)"

# 3. Install
echo "[3/3] Running yarn install..."
echo ""
start=$(python3 -c "import time; print(int(time.time()*1000))")
$YARN install
end=$(python3 -c "import time; print(int(time.time()*1000))")
elapsed=$(python3 -c "print(round(($end - $start) / 1000, 2))")

# Stats (PnP: no node_modules; packages live as zips in .yarn/cache)
PNP_SIZE=$(du -sh .pnp.cjs 2>/dev/null | cut -f1)
CACHE_SIZE=$(du -sh "${CACHE_DIR:-.yarn/cache}" 2>/dev/null | cut -f1)
HAS_NM=$([ -d node_modules ] && echo "yes" || echo "none")
STATS=$(python3 - << 'PYSTATS'
import json, re
from collections import defaultdict
pkg = json.load(open('package.json'))
declared = len(pkg.get('dependencies', {})) + len(pkg.get('devDependencies', {}))
text = open('yarn.lock').read()
versions = defaultdict(set)
for m in re.finditer(r'^"?((?:@[^/]+/)?[^@"\s]+)@npm:([^",\s]+)', text, re.MULTILINE):
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
echo "  Done!  (Yarn Berry — Plug'n'Play)"
echo "================================================"
echo "  Package manager:    yarn ${YARN_VERSION}"
echo "  Install time:       ${elapsed}s"
echo "  Lockfile:           yarn.lock"
echo ""
echo "  Declared deps:      ${DECLARED}"
echo "  Total dependencies: ${RESOLVED}"
echo "  Duplicated:         ${DUPED}  (same package, >1 version)"
echo "  node_modules:       ${HAS_NM}"
echo "  .pnp.cjs resolver:  ${PNP_SIZE}"
echo "  .yarn/cache size:   ${CACHE_SIZE}"
echo "================================================"
