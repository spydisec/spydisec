#!/usr/bin/env bash
# Fetches the AbuseIPDB contributor badge and wraps it with the background it needs.
#
# Why this exists: the upstream SVG is fully transparent and draws its text in
# dark grey (#4d4d4d). AbuseIPDB supplies the green background via an inline
# `style` attribute in their copy-paste snippet — and GitHub's markdown
# sanitizer strips `style`, so on a dark README the badge is unreadable.
# AbuseIPDB offers no theme parameter (?theme=dark returns an identical file)
# and no raster fallback, so we add the background ourselves.
#
# The upstream file contains a NESTED <svg> for the logo whose opening tag spans
# multiple lines. Do not try to inject into it with line-based tools — that
# corrupts the XML and browsers silently refuse to render it. Instead the whole
# original is nested unmodified inside a wrapper that paints the background.
set -euo pipefail

USER_ID="${1:?usage: build-abuseipdb-badge.sh <abuseipdb-user-id> <output-path>}"
OUT="${2:?usage: build-abuseipdb-badge.sh <abuseipdb-user-id> <output-path>}"
SRC="https://www.abuseipdb.com/contributor/${USER_ID}.svg"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
curl -fsSL --max-time 30 -A "Mozilla/5.0 (github-actions; +https://github.com/spydisec)" "$SRC" -o "$tmp"

# Refuse to publish anything that isn't the badge we expect.
grep -q '<svg' "$tmp" || { echo "error: upstream response is not SVG" >&2; exit 1; }
grep -q 'AbuseIPDB Contributor' "$tmp" || { echo "error: badge text missing; upstream format changed" >&2; exit 1; }

# Drop the XML declaration so the original can be nested as an element.
inner="$(sed '/<?xml/d' "$tmp")"

# Colours mirror AbuseIPDB's own snippet: #35c246 fill, #058403 accent border.
{
  printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
  printf '%s\n' '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 400 100" width="400" height="100" role="img" aria-label="AbuseIPDB Contributor">'
  printf '%s\n' '  <defs>'
  printf '%s\n' '    <linearGradient id="abuseipdbBg" x1="0" y1="0" x2="0" y2="1">'
  printf '%s\n' '      <stop offset="0" stop-color="#3ad152" />'
  printf '%s\n' '      <stop offset="0.5" stop-color="#35c246" />'
  printf '%s\n' '      <stop offset="0.51" stop-color="#2fae3e" />'
  printf '%s\n' '      <stop offset="1" stop-color="#35c246" />'
  printf '%s\n' '    </linearGradient>'
  printf '%s\n' '  </defs>'
  printf '%s\n' '  <rect x="2" y="2" width="396" height="96" rx="10" fill="url(#abuseipdbBg)" stroke="#058403" stroke-width="4" />'
  printf '%s\n' "$inner"
  printf '%s\n' '</svg>'
} > "$OUT"

# A malformed SVG renders as a broken image with no error anywhere, so parse it
# before publishing. This is the check that would have caught the sed corruption.
# On Windows `python3` is often a Microsoft Store stub that exits non-zero, so
# probe for a working interpreter and only warn if there genuinely isn't one.
PY_BIN=""
for cand in python3 python; do
  if command -v "$cand" >/dev/null 2>&1 && "$cand" -c "pass" >/dev/null 2>&1; then
    PY_BIN="$cand"; break
  fi
done

if [ -z "$PY_BIN" ]; then
  echo "warning: no working Python found; skipping XML validation" >&2
  echo "wrote $OUT ($(wc -c <"$OUT") bytes)"
  exit 0
fi

"$PY_BIN" - "$OUT" <<'PY'
import sys, xml.etree.ElementTree as ET
path = sys.argv[1]
try:
    ET.parse(path)
except ET.ParseError as e:
    sys.exit(f"error: generated SVG is not well-formed XML: {e}")
src = open(path, encoding="utf-8").read()
if src.count('id="abuseipdbBg"') != 1:
    sys.exit("error: expected exactly one background gradient definition")
if "AbuseIPDB Contributor" not in src:
    sys.exit("error: badge text missing from output")
print("SVG validated: well-formed, one background, badge text present")
PY

echo "wrote $OUT ($(wc -c <"$OUT") bytes)"
