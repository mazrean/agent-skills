# WSH Scoring Reference

## Lighthouse v10 Performance Scoring Weights

| Metric | Weight | Good Threshold | Poor Threshold |
|--------|--------|----------------|----------------|
| FCP (First Contentful Paint) | 10% | ≤1.8s | >3.0s |
| SI (Speed Index) | 10% | ≤3.4s | >5.8s |
| LCP (Largest Contentful Paint) | 25% | ≤2.5s | >4.0s |
| TBT (Total Blocking Time) | 30% | ≤200ms | >600ms |
| CLS (Cumulative Layout Shift) | 25% | ≤0.1 | >0.25 |

**TBT (30%) + LCP (25%) + CLS (25%) = 80%** of the score. Focus here.

## WSH 2025 Scoring (1200 pts total)

### Page Display — 900 pts (9 pages × 100 pts)
Each page scored with standard Lighthouse Performance formula above.
Only scored if page loads successfully.

### Page Interaction — 200 pts (4 flows × 50 pts)
- TBT × 25 + INP × 25
- Only measured if page display total ≥ 200 pts
- INP (Interaction to Next Paint): Good ≤200ms, Poor >500ms

### Video Playback — 100 pts (2 scenarios × 50 pts)
- Score = (1 − t_mod/(t_mod + 3000)) × 50
- t_mod = time from navigation to first `playing` event
- Target: <1s for maximum points

## WSH 2024 Scoring (150 pts total)

- Page Landing: 4 pages × 25 pts (standard LH formula)
- User Flow: 6 scenarios × ~8.3 pts (TBT × 25 + INP × 25)

## Historical Score Ranges

| Year | Winner Score | 2nd Place | 3rd Place | Typical Midfield |
|------|-------------|-----------|-----------|-----------------|
| 2025 | ~350-400 | ~320 | ~317 | 100-200 |
| 2024 | ~450 | 433.70 | ~400 | 50-150 |
| 2022 | ~480 | ~475 | ~471 | 200-350 |

## Score Estimation Heuristic

Rough point gains from common optimizations (varies by app):

| Optimization | Estimated Gain | Affects |
|-------------|---------------|---------|
| Production mode + source map removal | +50-150 | TBT, SI, FCP |
| Remove bloated dependencies | +30-100 | TBT, SI |
| Image AVIF conversion + resize | +20-80 | LCP, SI |
| Code splitting | +20-60 | TBT, FCP |
| Compression (Brotli/gzip) | +10-40 | FCP, LCP, SI |
| Remove artificial delays | +10-30 | LCP, FCP, SI |
| Fix CLS (dimensions, font-display) | +10-50 | CLS |
| Critical CSS + defer rest | +10-30 | FCP, SI |
| Fix N+1 queries | +5-20 | LCP, SI |
| Runtime CSS-in-JS removal | +10-30 | TBT, FCP |
| SSR implementation | +20-80 | FCP, LCP, SI |
| Preact migration | +10-30 | TBT |

## Running Lighthouse Locally

```bash
# CLI (closest to scoring environment)
npx lighthouse http://localhost:3000 \
  --only-categories=performance \
  --chrome-flags="--headless --no-sandbox" \
  --output=json --output-path=./lh-report.json

# Multiple pages
for url in "/" "/page1" "/page2"; do
  npx lighthouse "http://localhost:3000${url}" \
    --only-categories=performance \
    --chrome-flags="--headless --no-sandbox" \
    --output=html --output-path="./lh-report${url//\//-}.html"
done
```

## Scoring Tool

Clone and run the official scoring tool locally for accurate measurement:
```bash
git clone https://github.com/CyberAgentHack/web-speed-hackathon-scoring-tool
cd web-speed-hackathon-scoring-tool
pnpm install
# Follow README for configuration
```
