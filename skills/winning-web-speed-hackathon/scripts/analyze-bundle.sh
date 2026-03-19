#!/bin/bash
# Quick bundle analysis for WSH projects
# Usage: bash scripts/analyze-bundle.sh [dist-dir]

DIST_DIR="${1:-dist}"

echo "=== Bundle Size Analysis ==="
echo ""

if [ ! -d "$DIST_DIR" ]; then
  echo "Error: $DIST_DIR not found. Build the project first."
  exit 1
fi

echo "--- Top 20 largest files ---"
find "$DIST_DIR" -type f -exec du -h {} + | sort -rh | head -20

echo ""
echo "--- Total size by extension ---"
for ext in js css html json woff2 woff ttf png jpg jpeg gif svg webp avif mp4 webm wasm; do
  total=$(find "$DIST_DIR" -name "*.$ext" -type f -exec du -cb {} + 2>/dev/null | tail -1 | cut -f1)
  if [ -n "$total" ] && [ "$total" -gt 0 ]; then
    human=$(numfmt --to=iec-i --suffix=B "$total" 2>/dev/null || echo "${total}B")
    printf "  %-8s %s\n" ".$ext" "$human"
  fi
done

echo ""
echo "--- Total dist size ---"
du -sh "$DIST_DIR"

echo ""
echo "=== Quick Checks ==="

# Check for source maps
SOURCEMAPS=$(find "$DIST_DIR" -name "*.map" -type f | wc -l)
if [ "$SOURCEMAPS" -gt 0 ]; then
  echo "⚠ Found $SOURCEMAPS source map files — remove them!"
else
  echo "✓ No source map files"
fi

# Check for large JS bundles (>500KB)
echo ""
echo "--- JS files >500KB (need splitting) ---"
find "$DIST_DIR" -name "*.js" -type f -size +500k -exec du -h {} +

# Check for unoptimized images (>200KB)
echo ""
echo "--- Image files >200KB (need optimization) ---"
find "$DIST_DIR" \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" \) -type f -size +200k -exec du -h {} +

# Check for wasm files
WASM=$(find "$DIST_DIR" -name "*.wasm" -type f | wc -l)
if [ "$WASM" -gt 0 ]; then
  echo ""
  echo "⚠ Found $WASM WASM files — check if they're necessary:"
  find "$DIST_DIR" -name "*.wasm" -type f -exec du -h {} +
fi
