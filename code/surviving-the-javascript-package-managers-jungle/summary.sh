#!/usr/bin/env bash
set -euo pipefail

export COREPACK_ENABLE_STRICT=0

BASE_SNAPSHOT="docusaurus-base.tgz"

# Pass --cold through to every script (default: warm)
MODE_ARG=""
MODE_LABEL="warm"
if [ "${1:-}" = "--cold" ]; then
  MODE_ARG="--cold"
  MODE_LABEL="cold"
fi

echo "================================================"
echo "  Package manager comparison — running all four"
echo "  (${MODE_LABEL} installs)"
echo "================================================"

if [ ! -f "${BASE_SNAPSHOT}" ]; then
  echo "  ERROR: ${BASE_SNAPSHOT} not found. Run ./setup.sh first." >&2
  exit 1
fi

# Run each demo script, capturing its full output to a temp log.
declare -a TOOLS=("npm" "pnpm" "yarn" "bun")
declare -a SCRIPTS=("npm.sh" "pnpm.sh" "yarn.sh" "bun.sh")

TMP="$(mktemp -d /tmp/pm-summary-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

for i in "${!SCRIPTS[@]}"; do
  s="${SCRIPTS[$i]}"
  t="${TOOLS[$i]}"
  echo ""
  echo ">>> Running ${s} ..."
  if [ ! -f "$s" ]; then
    echo "    (skipped: $s not found)"
    : > "${TMP}/${t}.log"
    continue
  fi
  bash "$s" $MODE_ARG > "${TMP}/${t}.log" 2>&1 || echo "    (warning: $s exited non-zero)"
done

# Extract one field from a tool's log: grep the label, take the value after the colon,
# strip the trailing parenthetical note and surrounding whitespace.
field() {  # $1 = tool, $2 = label
  grep -m1 "  $2:" "${TMP}/$1.log" 2>/dev/null \
    | sed "s|.*$2:[[:space:]]*||; s|  (.*||; s|[[:space:]]*\$||"
}

row() {  # $1 = label, $2 = field-name
  printf "  %-20s | %-12s | %-12s | %-12s | %-12s\n" \
    "$1" "$(field npm "$2")" "$(field pnpm "$2")" "$(field yarn "$2")" "$(field bun "$2")"
}

echo ""
echo "================================================================================"
echo "  COMPARISON SUMMARY"
echo "================================================================================"
printf "  %-20s | %-12s | %-12s | %-12s | %-12s\n" "" "npm" "pnpm" "yarn (PnP)" "bun"
echo "  ---------------------+--------------+--------------+--------------+-------------"
row "Install time"        "Install time"
row "Declared deps"       "Declared deps"
row "Total dependencies"  "Total dependencies"
row "Duplicated"          "Duplicated"
row "node_modules size"   "node_modules size"
# tool-specific extras
printf "  %-20s | %-12s | %-12s | %-12s | %-12s\n" \
  "Top-level folders" "$(field npm 'Top-level folders')" "$(field pnpm 'Top-level folders')" "$(field yarn 'node_modules')" "$(field bun 'Top-level folders')"
printf "  %-20s | %-12s | %-12s | %-12s | %-12s\n" \
  "Other store/cache" "-" "$(field pnpm 'Global store size') store" "$(field yarn '.yarn/cache size') cache" "-"
echo "================================================================================"
echo "  (yarn runs in Plug'n'Play: no node_modules, uses a .pnp.cjs resolver instead)"
echo "================================================================================"
