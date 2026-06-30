#!/usr/bin/env bash
# Artisyn Delivery Workspace — bootstrap install from Confluence (mac/linux).
#
# Pulls the catalog-schema wheel from a Confluence release page,
# uv-tool-installs it, and (unless --no-chain) chains into
# `artisyn-workspace install` so the rest of the wheels land in a workspace .venv.
#
# Usage:
#   export ARTISYN_CONFLUENCE_TOKEN=<your Confluence PAT>
#   curl -fsSLO https://conf.dataart.com/.../install-from-confluence.sh
#   bash install-from-confluence.sh                       # latest artisyn-stable
#   bash install-from-confluence.sh 0.2.0                 # pin a version
#   bash install-from-confluence.sh 0.2.0 --no-chain      # just install the CLI
#   bash install-from-confluence.sh --here                # `artisyn-workspace install --here` after
#
# Auth (in priority order; legacy names still honoured):
#   $ARTISYN_CONFLUENCE_TOKEN  →  $AILA_CONFLUENCE_TOKEN  →  $CONFLUENCE_PERSONAL_TOKEN
# URL:
#   $ARTISYN_CONFLUENCE_URL    →  $AILA_CONFLUENCE_URL    →  https://conf.dataart.com  (default)
# Space:
#   $ARTISYN_CONFLUENCE_SPACE  →  $AILA_CONFLUENCE_SPACE  →  SRD                       (default)

set -euo pipefail

# --- Parse args ---
VERSION=""
CHAIN=true
HERE=false
NAME=""
SKILLS=""
while [ $# -gt 0 ]; do
    case "$1" in
        --no-chain) CHAIN=false; shift ;;
        --here) HERE=true; shift ;;
        --name) NAME="$2"; shift 2 ;;
        --name=*) NAME="${1#--name=}"; shift ;;
        --skills) SKILLS="$2"; shift 2 ;;
        --skills=*) SKILLS="${1#--skills=}"; shift ;;
        -h|--help)
            sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        -*) echo "Unknown flag: $1" >&2; exit 2 ;;
        *) VERSION="${1#v}"; shift ;;
    esac
done

# --- Resolve auth + URL (new ARTISYN_ names preferred, legacy still honoured) ---
TOKEN="${ARTISYN_CONFLUENCE_TOKEN:-${AILA_CONFLUENCE_TOKEN:-${CONFLUENCE_PERSONAL_TOKEN:-}}}"
if [ -z "$TOKEN" ]; then
    echo "ERROR: set \$ARTISYN_CONFLUENCE_TOKEN (or legacy \$AILA_CONFLUENCE_TOKEN / \$CONFLUENCE_PERSONAL_TOKEN) first." >&2
    echo "       Generate a PAT at https://conf.dataart.com/plugins/personalaccesstokens/usertokens.action" >&2
    exit 3
fi
BASE_URL="${ARTISYN_CONFLUENCE_URL:-${AILA_CONFLUENCE_URL:-https://conf.dataart.com}}"
BASE_URL="${BASE_URL%/}"
SPACE="${ARTISYN_CONFLUENCE_SPACE:-${AILA_CONFLUENCE_SPACE:-SRD}}"

# --- Verify prerequisites ---
if ! command -v uv > /dev/null 2>&1; then
    echo "==> uv not found; installing via the official installer..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
fi
if ! command -v python3 > /dev/null 2>&1; then
    echo "ERROR: python3 not found (needed for JSON parsing in this script)." >&2
    exit 4
fi

curl_args=(-sS -k -H "Authorization: Bearer $TOKEN" -H "Accept: application/json")

# --- Find the release page ---
if [ -n "$VERSION" ]; then
    echo "==> Looking up release page v$VERSION on $BASE_URL ..."
    page_json="$(
        curl "${curl_args[@]}" -G "$BASE_URL/rest/api/content" \
            --data-urlencode "type=page" \
            --data-urlencode "title=v$VERSION" \
            --data-urlencode "spaceKey=$SPACE"
    )"
else
    echo "==> Looking up current artisyn-stable release on $BASE_URL ..."
    page_json="$(
        curl "${curl_args[@]}" -G "$BASE_URL/rest/api/content/search" \
            --data-urlencode "cql=label in (\"artisyn-stable\", \"aila-stable\") AND space = \"$SPACE\" AND type = page" \
            --data-urlencode "limit=1"
    )"
fi

PAGE_ID="$(echo "$page_json" | python3 -c '
import json, sys
data = json.load(sys.stdin)
results = data.get("results") or []
if not results:
    sys.exit(0)
node = results[0]
print((node.get("content") or node).get("id", ""))
')"

if [ -z "$PAGE_ID" ]; then
    if [ -n "$VERSION" ]; then
        echo "ERROR: no release page titled \"v$VERSION\" found in space $SPACE." >&2
    else
        echo "ERROR: no page labelled artisyn-stable (or legacy aila-stable) in space $SPACE." >&2
        echo "       Run release.sh <version> --promote on the publisher's side, " >&2
        echo "       or pass a specific version to this script." >&2
    fi
    exit 5
fi
echo "    page id: $PAGE_ID"

# --- Find ALL wheel attachments ---
# The CLI lives in catalog-schema, but since STORY-0005b artisyn-catalog-schema
# declares a real dependency on artisyn-skill-sdk (and neither inter-package
# wheel is on a public registry). So we download every wheel on the page and
# `uv tool install` the catalog-schema wheel with --find-links pointing at the
# local dir, so the sibling deps resolve offline.
echo "==> Listing attachments..."
atts_json="$(
    curl "${curl_args[@]}" \
        "$BASE_URL/rest/api/content/$PAGE_ID/child/attachment?limit=200"
)"

# Emit one "title<TAB>downloadpath" line per wheel attachment.
wheels_tsv="$(echo "$atts_json" | python3 -c '
import json, sys
data = json.load(sys.stdin)
for a in data.get("results") or []:
    title = a.get("title", "")
    if title.endswith(".whl"):
        dl = (a.get("_links") or {}).get("download") or ""
        if dl:
            print(title + "\t" + dl)
')"

if [ -z "$wheels_tsv" ]; then
    echo "ERROR: no *.whl attachments on page $PAGE_ID." >&2
    exit 6
fi

# --- Download every wheel to a temp dir; remember the catalog-schema one ---
TMP="$(mktemp -d -t artisyn-bootstrap-XXXXXX)"
WHEEL_PATH=""
while IFS="$(printf '\t')" read -r title dl; do
    [ -z "$title" ] && continue
    echo "==> Downloading $title ..."
    curl "${curl_args[@]}" -L -o "$TMP/$title" "$BASE_URL$dl"
    case "$title" in
        artisyn_catalog_schema-*|aila_catalog_schema-*) WHEEL_PATH="$TMP/$title" ;;
    esac
done <<EOF
$wheels_tsv
EOF

if [ -z "$WHEEL_PATH" ]; then
    echo "ERROR: no (artisyn|aila)_catalog_schema-*.whl among attachments on page $PAGE_ID." >&2
    exit 6
fi
echo "    CLI wheel: $(basename "$WHEEL_PATH")"

# --- uv tool install (resolve sibling wheels from the downloaded dir) ---
echo "==> uv tool install $(basename "$WHEEL_PATH") (--find-links $TMP) ..."
uv tool install --force --find-links "$TMP" "$WHEEL_PATH"

# Re-export PATH so `artisyn-workspace` is on it in this shell.
export PATH="$HOME/.local/bin:$PATH"

# --- Chain into artisyn-workspace install ---
if [ "$CHAIN" = false ]; then
    echo ""
    echo "✓ CLI installed.  Run: artisyn-workspace install --version $VERSION"
    exit 0
fi

CHAIN_ARGS=("install")
[ -n "$VERSION" ] && CHAIN_ARGS+=("--version" "$VERSION")
[ "$HERE"      = true ] && CHAIN_ARGS+=("--here")
[ -n "$NAME"   ]        && CHAIN_ARGS+=("--name" "$NAME")
[ -n "$SKILLS" ]        && CHAIN_ARGS+=("--skills" "$SKILLS")

echo "==> artisyn-workspace ${CHAIN_ARGS[*]}"
artisyn-workspace "${CHAIN_ARGS[@]}"
