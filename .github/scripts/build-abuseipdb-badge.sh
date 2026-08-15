#!/usr/bin/env bash
# Fetches the AbuseIPDB contributor badge and bakes in the background it needs.
#
# Why this exists: the upstream SVG is fully transparent and draws its text in
# dark grey (#4d4d4d). AbuseIPDB supplies the green background via an inline
# `style` attribute in their copy-paste snippet — and GitHub's markdown
# sanitizer strips `style`, so on a dark README the badge is unreadable.
# AbuseIPDB offers no theme parameter and no raster fallback, so we add the
# background ourselves and serve the result from this repo.
set -euo pipefail

USER_ID="${1:?usage: build-abuseipdb-badge.sh <abuseipdb-user-id> <output-path>}"
OUT="${2:?usage: build-abuseipdb-badge.sh <abuseipdb-user-id> <output-path>}"
SRC="https://www.abuseipdb.com/contributor/${USER_ID}.svg"

tmp="$(mktemp)"
curl -fsSL --max-time 30 -A "Mozilla/5.0 (github-actions; +https://github.com/spydisec)" "$SRC" -o "$tmp"

# Refuse to publish anything that isn't the badge we expect.
grep -q '<svg' "$tmp" || { echo "error: upstream response is not SVG" >&2; exit 1; }
grep -q 'AbuseIPDB Contributor' "$tmp" || { echo "error: badge text missing; upstream format changed" >&2; exit 1; }

# Insert a rounded background + border as the first child of <svg> so it paints
# behind the logo and text. Colours mirror AbuseIPDB's own snippet
# (#35c246 fill with a #058403 accent border). The gradient id is namespaced to
# avoid colliding with the upstream defs, which already use ids a-g.
background='    <defs>\
      <linearGradient id="abuseipdbBg" x1="0" y1="0" x2="0" y2="1">\
        <stop offset="0" stop-color="#3ad152" />\
        <stop offset="0.5" stop-color="#35c246" />\
        <stop offset="0.51" stop-color="#2fae3e" />\
        <stop offset="1" stop-color="#35c246" />\
      </linearGradient>\
    </defs>\
    <rect x="2" y="2" width="396" height="96" rx="10" fill="url(#abuseipdbBg)" stroke="#058403" stroke-width="4" />'

sed "/<svg /a\\
$background" "$tmp" > "$OUT"

grep -q 'abuseipdbBg' "$OUT" || { echo "error: background injection failed" >&2; exit 1; }
rm -f "$tmp"
echo "wrote $OUT ($(wc -c <"$OUT") bytes)"
