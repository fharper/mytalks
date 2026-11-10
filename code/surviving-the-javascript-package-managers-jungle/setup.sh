#!/usr/bin/env bash
set -euo pipefail

# Prevent Corepack from blocking based on a parent directory's packageManager field
export COREPACK_ENABLE_STRICT=0

DEMO_DIR="docusaurus"
BASE_SNAPSHOT="docusaurus-base.tgz"

echo "================================================"
echo "  Creating the shared Docusaurus base"
echo "================================================"
echo ""
echo "Run this ONCE. It scaffolds a default Docusaurus project and saves a"
echo "pristine snapshot (${BASE_SNAPSHOT}). Each manager script (npm.sh, pnpm.sh, yarn.sh, bun.sh)"
echo "restores that snapshot first, so you can run them in any order."
echo ""

# 1. Scaffold a fresh default Docusaurus project (source files only, no install)
echo "[1/2] Scaffolding a fresh default Docusaurus project..."
rm -rf "${DEMO_DIR}"
npx -y create-docusaurus@latest "${DEMO_DIR}" classic --skip-install -j

# Remove anything that would pollute the snapshot (no git, no installs).
rm -rf "${DEMO_DIR}/.git" "${DEMO_DIR}/node_modules" \
       "${DEMO_DIR}"/package-lock.json "${DEMO_DIR}"/yarn.lock \
       "${DEMO_DIR}"/pnpm-lock.yaml "${DEMO_DIR}"/bun.lock 2>/dev/null || true

# 2. Save a pristine snapshot of the clean source tree
echo "[2/2] Saving pristine snapshot -> ${BASE_SNAPSHOT}"
tar czf "${BASE_SNAPSHOT}" -C "${DEMO_DIR}" .

DECLARED=$(python3 -c "import json; d=json.load(open('${DEMO_DIR}/package.json')); print(len(d.get('dependencies',{})) + len(d.get('devDependencies',{})))")

echo ""
echo "================================================"
echo "  Base ready."
echo "  Snapshot:      ./${BASE_SNAPSHOT}"
echo "  Declared deps: ${DECLARED}"
echo ""
echo "  Now run any of these, in any order, any number of times:"
echo "    ./npm.sh"
echo "    ./pnpm.sh"
echo "    ./yarn.sh"
echo "    ./bun.sh"
echo "================================================"
