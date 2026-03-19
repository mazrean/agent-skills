---
name: winning-web-speed-hackathon
description: Optimizes deliberately slow web applications for maximum Lighthouse scores in Web Speed Hackathon (CyberAgent). Use when participating in WSH or performing aggressive frontend performance optimization on React/Node.js apps with SQLite backends. Covers bundle reduction, image optimization, Core Web Vitals, server tuning, and known competition traps.
---

# Winning Web Speed Hackathon

Systematic workflow to maximize Lighthouse scores in CyberAgent's Web Speed Hackathon. The competition provides a deliberately de-tuned React + Node.js app; your job is to optimize it while passing VRT and regulation checks.

**Use this skill when** participating in Web Speed Hackathon, or aggressively optimizing a React/Node.js web app for Lighthouse Performance scores.

## Scoring Model

Lighthouse v10 Performance scoring weights per page:
- **FCP** x10 | **SI** x10 | **LCP** x25 | **TBT** x30 | **CLS** x25

User flow scoring: **TBT** x25 + **INP** x25

LCP and TBT dominate. Prioritize accordingly.

## Phase 0: Reconnaissance (First 30 min)

1. **Clone and run** the app locally. Confirm it builds and serves.
2. **Run Lighthouse** locally on all scored pages. Record baseline scores.
3. **Analyze the bundle**:
   ```bash
   npx webpack-bundle-analyzer dist/stats.json  # if webpack
   # or check build output sizes
   ```
4. **Check Chrome DevTools**:
   - **Network tab**: Identify largest transfers, uncompressed assets, no-cache headers
   - **Coverage tab** (Ctrl+Shift+P → "Coverage"): Find unused JS/CSS percentage
   - **Performance tab**: Record page load, identify long tasks and layout shifts
5. **Scan for known traps** — see [WSH-KNOWN-TRAPS.md](references/WSH-KNOWN-TRAPS.md)
6. **Read the regulation/checklist** carefully. Know what you cannot break.
7. **Prioritize** fixes by estimated score impact. Work top-down.

## Phase 1: Build & Bundle (Highest Impact)

These fixes often yield 50-200+ point gains.

1. **Fix build mode**: Ensure `NODE_ENV=production` and bundler `mode: 'production'`
2. **Remove source maps**: Delete `devtool: 'inline-source-map'` or similar
3. **Kill bloated dependencies**: Check for and remove/replace:
   - `@iconify/json`, `@ffmpeg/ffmpeg`, `zengin-code`, `moment-timezone` → `dayjs`
   - `lodash` → native JS or `lodash-es` (tree-shakeable)
   - `canvaskit-wasm`, `Three.js` → simple HTML/CSS/`<img>`
   - Full icon sets → only used icons
4. **Enable tree shaking**: Remove `@babel/plugin-transform-modules-commonjs`
5. **Code split routes**: `React.lazy()` + `<Suspense>` per route
6. **Target modern browsers**: Set browserslist to `last 1 Chrome version`
7. **Minify everything**: Ensure terser/esbuild minification is active
8. **Consider Preact**: Drop-in replacement, ~3KB vs ~40KB for React

Details: [BUNDLE-OPTIMIZATION.md](references/BUNDLE-OPTIMIZATION.md)

## Phase 2: Images & Fonts (High Impact)

1. **Convert images** to AVIF (best) or WebP. Use Sharp or ImageMagick.
2. **Resize** to actual display dimensions (not 4000px originals)
3. **Convert animated GIFs** to WebM/MP4 `<video>` elements
4. **Add** `loading="lazy"` to below-fold images, `fetchpriority="high"` to LCP image
5. **Add explicit** `width`/`height` to all `<img>` (prevents CLS)
6. **Subset fonts** to used characters only (pyftsubset/glyphhanger)
7. **Add** `font-display: swap` and preload critical fonts

Details: [IMAGE-AND-FONT-OPTIMIZATION.md](references/IMAGE-AND-FONT-OPTIMIZATION.md)

## Phase 3: Network & Server (Medium-High Impact)

1. **Enable compression**: gzip/Brotli middleware (e.g., `@fastify/compress`)
2. **Set Cache-Control**: `max-age=31536000, immutable` for hashed static assets
3. **Remove artificial delays**: Search for `setTimeout`, `sleep`, `delay`, `jitter` in server code
4. **Fix N+1 queries**: Add JOINs or batch loading. Add DB indexes.
5. **Add resource hints**: `<link rel="preconnect">`, `<link rel="preload">` for critical assets
6. **Remove `no-store`** cache headers on static resources
7. **Parallelize API calls**: `Promise.all()` instead of sequential fetches

Details: [NETWORK-AND-SERVER.md](references/NETWORK-AND-SERVER.md)

## Phase 4: CSS & Rendering (Medium Impact)

1. **Remove runtime CSS-in-JS**: Replace UnoCSS runtime / styled-components with static CSS
2. **Extract critical CSS**: Inline above-fold CSS in `<head>`
3. **Remove unused CSS**: PurgeCSS or manual removal
4. **Fix CLS sources**: Add `aspect-ratio`, explicit dimensions, font fallback metrics
5. **Defer non-critical CSS**: Load below-fold styles asynchronously
6. **Add `defer`** to all non-critical `<script>` tags

Details: [RENDERING-AND-CSS.md](references/RENDERING-AND-CSS.md)

## Phase 5: Runtime & Interaction (For INP/TBT)

1. **Fix ReDoS**: Check regex patterns for catastrophic backtracking (email/password validators)
2. **Break long tasks**: Use `scheduler.yield()` or `setTimeout(0)` to yield to main thread
3. **Optimize React renders**: `React.memo`, `useMemo` for expensive computations
4. **Virtualize long lists**: `react-window` or `@tanstack/virtual`
5. **Replace heavy hover handlers**: Use `onMouseEnter`/`onMouseLeave` instead of `onMouseOver`
6. **Remove unnecessary animations**: framer-motion, CSS transitions on layout properties

## Phase 6: SSR & Advanced (If Time Permits)

1. **Implement SSR**: Stream HTML with `renderToPipeableStream` for instant FCP/LCP
2. **Move to Vite**: If stuck with Webpack dev mode, migrate for better DX and build
3. **Deploy static assets to CDN**: Cloudflare Pages or similar
4. **Service Worker**: Cache static assets for repeat visits (if required by rules)

## Validation Loop

After every major change:
```
1. Build → verify no errors
2. Run Lighthouse locally on affected pages
3. Check VRT if available: npx playwright test
4. Compare scores to previous baseline
5. Commit working state before next optimization
```

**Never skip VRT**. Regulation violations = disqualification.

## Time Management (31-hour competition)

| Hours | Focus | Expected Impact |
|-------|-------|----------------|
| 0-0.5 | Recon & analysis | Baseline established |
| 0.5-4 | Build/bundle fixes | +100-300 pts |
| 4-8 | Image/font optimization | +50-150 pts |
| 8-14 | Server/network/API | +30-100 pts |
| 14-20 | CSS/rendering/CLS | +20-80 pts |
| 20-26 | Runtime/INP/TBT polish | +10-50 pts |
| 26-30 | SSR/advanced if needed | +20-100 pts |
| 30-31 | Final VRT check & deploy | Safety margin |

## Reference Files

- [WSH Known Traps](references/WSH-KNOWN-TRAPS.md) — Intentional performance pitfalls by year
- [Bundle Optimization](references/BUNDLE-OPTIMIZATION.md) — Webpack/Vite config, dependency replacement
- [Image & Font Optimization](references/IMAGE-AND-FONT-OPTIMIZATION.md) — Format conversion, lazy loading, subsetting
- [Network & Server](references/NETWORK-AND-SERVER.md) — Compression, caching, DB, API optimization
- [Rendering & CSS](references/RENDERING-AND-CSS.md) — Critical CSS, CLS, runtime CSS-in-JS removal
- [Scoring Reference](references/SCORING-REFERENCE.md) — Historical scoring formulas and thresholds
