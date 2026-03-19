# WSH Improvement Catalog

Known improvement patterns for Web Speed Hackathon, sorted by typical impact. Use this as a reference when analyzing a project — not all items apply to every year's competition.

## Tier 1: Critical (Est. +50-200 pts)

### BUILD-001: Production Mode
- **What**: Set `NODE_ENV=production` and bundler `mode: 'production'`
- **Find**: `webpack.config.*`, `vite.config.*`, `.env`, `package.json` scripts
- **Affects**: TBT, SI, FCP
- **VRT Risk**: Low

### BUILD-002: Remove Source Maps
- **What**: Remove `devtool: 'inline-source-map'` or similar
- **Find**: `webpack.config.*`
- **Affects**: TBT, SI
- **VRT Risk**: Low

### BUILD-003: Remove Bloated Dependencies
- **What**: Remove or replace massively oversized dependencies
- **Find**: `package.json`, run `npm ls` or check `node_modules` sizes
- **Common targets**: `@iconify/json`, `@ffmpeg/ffmpeg`, `zengin-code`, `canvaskit-wasm`, `Three.js`
- **Affects**: TBT, SI, FCP
- **VRT Risk**: Medium-High (depends on what the dependency renders)
- **Note**: Generate ONE command per dependency removal, not a batch

### BUILD-004: Enable Tree Shaking
- **What**: Remove `@babel/plugin-transform-modules-commonjs`, ensure ES modules
- **Find**: `babel.config.*`, `.babelrc`, `webpack.config.*`
- **Affects**: TBT, SI
- **VRT Risk**: Low

### BUILD-005: Code Splitting
- **What**: `React.lazy()` + `<Suspense>` per route
- **Find**: Router config, main entry point
- **Affects**: TBT, FCP
- **VRT Risk**: Low-Medium

## Tier 2: High Impact (Est. +20-80 pts)

### IMG-001: Convert Images to Modern Formats
- **What**: Convert PNG/JPEG to AVIF or WebP
- **Find**: `public/`, `assets/`, `static/` directories
- **Affects**: LCP, SI
- **VRT Risk**: Medium (color shifts, quality differences)

### IMG-002: Resize Oversized Images
- **What**: Resize to actual display dimensions
- **Find**: Network tab analysis, image file sizes
- **Affects**: LCP, SI
- **VRT Risk**: Low-Medium

### IMG-003: Convert GIF to Video
- **What**: Replace animated GIFs with WebM/MP4 `<video>`
- **Find**: Search for `.gif` references
- **Affects**: LCP, SI
- **VRT Risk**: Medium

### NET-001: Enable Compression
- **What**: Add gzip/Brotli compression middleware
- **Find**: Server entry file (e.g., `server.ts`, `app.ts`)
- **Affects**: FCP, LCP, SI
- **VRT Risk**: Low

### NET-002: Fix Cache Headers
- **What**: Set proper `Cache-Control` for static assets
- **Find**: Server static file serving config
- **Affects**: Repeat-visit scores
- **VRT Risk**: Low

### NET-003: Remove Artificial Delays
- **What**: Remove `setTimeout`, `sleep`, `delay` in server code
- **Find**: Search server code for delay patterns
- **Affects**: LCP, FCP, SI
- **VRT Risk**: Low

### NET-004: Fix N+1 Queries
- **What**: Batch DB queries, add JOINs
- **Find**: Server route handlers, ORM usage
- **Affects**: LCP, SI
- **VRT Risk**: Low

### CSS-001: Remove Runtime CSS-in-JS
- **What**: Replace UnoCSS runtime / styled-components with static CSS
- **Find**: Check for runtime CSS generation in bundle
- **Affects**: TBT, FCP
- **VRT Risk**: Medium-High

### CSS-002: Fix CLS Sources
- **What**: Add explicit dimensions, `aspect-ratio`, `font-display: swap`
- **Find**: Images without width/height, `@font-face` declarations
- **Affects**: CLS
- **VRT Risk**: Medium

## Tier 3: Medium Impact (Est. +10-30 pts)

### BUILD-006: Modern Browser Target
- **What**: Set browserslist to `last 1 Chrome version`
- **Find**: `.browserslistrc`, `package.json` browserslist field
- **Affects**: TBT
- **VRT Risk**: Low

### BUILD-007: Minification Check
- **What**: Ensure terser/esbuild minification is active
- **Find**: Build config optimization section
- **Affects**: TBT, SI
- **VRT Risk**: Low

### IMG-004: Lazy Load Below-Fold Images
- **What**: Add `loading="lazy"` to off-screen images
- **Find**: Image components, HTML templates
- **Affects**: LCP (by not competing for bandwidth)
- **VRT Risk**: Medium (VRT may capture before lazy images load)

### IMG-005: Prioritize LCP Image
- **What**: Add `fetchpriority="high"` to LCP image element
- **Find**: Hero image, main content image
- **Affects**: LCP
- **VRT Risk**: Low

### FONT-001: Subset Fonts
- **What**: Subset to used characters only
- **Find**: Font files in assets, `@font-face` declarations
- **Affects**: FCP, CLS
- **VRT Risk**: Medium (missing glyphs)

### FONT-002: Font Display Swap
- **What**: Add `font-display: swap` and preload critical fonts
- **Find**: `@font-face` in CSS
- **Affects**: FCP, CLS
- **VRT Risk**: Low-Medium

### NET-005: Add Resource Hints
- **What**: `<link rel="preconnect">`, `<link rel="preload">` for critical assets
- **Find**: HTML head, main template
- **Affects**: FCP, LCP
- **VRT Risk**: Low

### NET-006: Parallelize API Calls
- **What**: `Promise.all()` for independent sequential fetches
- **Find**: Page data loading, `useEffect` chains
- **Affects**: LCP, SI
- **VRT Risk**: Low

### CSS-003: Critical CSS Extraction
- **What**: Inline above-fold CSS in `<head>`, defer rest
- **Find**: Main CSS bundle, entry CSS
- **Affects**: FCP, SI
- **VRT Risk**: Medium

### RUNTIME-001: Fix ReDoS
- **What**: Simplify catastrophic backtracking regex patterns
- **Find**: Validators, input handlers (email, password, URL)
- **Affects**: TBT, INP
- **VRT Risk**: Low

### RUNTIME-002: Optimize React Renders
- **What**: `React.memo`, `useMemo` for expensive computations
- **Find**: React DevTools Profiler, component render analysis
- **Affects**: TBT, INP
- **VRT Risk**: Low

## Tier 4: Advanced (Est. +20-100 pts, higher effort)

### ADV-001: SSR Implementation
- **What**: `renderToPipeableStream` for server-side rendering
- **Affects**: FCP, LCP, SI
- **VRT Risk**: High
- **Effort**: Large

### ADV-002: Preact Migration
- **What**: Replace React with Preact (~3KB vs ~40KB)
- **Affects**: TBT
- **VRT Risk**: Medium
- **Effort**: Medium

### ADV-003: Vite Migration
- **What**: Replace Webpack with Vite for better tree shaking and build
- **Affects**: TBT, SI
- **VRT Risk**: Medium
- **Effort**: Large

## Usage Notes

- Not all items exist in every WSH project — analyze the actual codebase
- Generate commands only for issues actually found
- One command per item (exception: BUILD-001 + BUILD-002 can be combined as they're in the same file and low risk)
- Tier 1 items first, then Tier 2, etc.
- Skip items that would violate the competition regulation
