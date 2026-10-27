#!/usr/bin/env bash
# Downloads Are.na's developer docs and v3 OpenAPI spec into docs/arena/ so they
# can be read offline and committed for reference.
#
# Usage: ./scripts/fetch-arena-docs.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root/docs/arena"
mkdir -p "$out"

# "<url> <output file>"
sources=(
  "https://api.are.na/v3/openapi.json openapi.json"
  "https://www.are.na/developers/all.md developers-all.md"
  "https://www.are.na/developers/all-compact.md developers-all-compact.md"
  "https://www.are.na/llms-full.txt llms-full.txt"
)

failed=0
for entry in "${sources[@]}"; do
  read -r url file <<<"$entry"
  if curl -fsSL --retry 3 --retry-delay 2 -o "$out/$file.tmp" "$url"; then
    mv "$out/$file.tmp" "$out/$file"
    echo "ok    $file  ($(wc -c <"$out/$file" | tr -d ' ') bytes)"
  else
    rm -f "$out/$file.tmp"
    echo "fail  $url" >&2
    failed=$((failed + 1))
  fi
done

# Pretty-print the spec so diffs stay readable when it changes.
spec="$out/openapi.json"
if [[ -f "$spec" ]] && command -v jq >/dev/null; then
  jq . "$spec" >"$spec.tmp" && mv "$spec.tmp" "$spec"
fi

if ((failed > 0)); then
  echo "$failed download(s) failed" >&2
  exit 1
fi
echo "Saved to ${out#"$root"/}/"
