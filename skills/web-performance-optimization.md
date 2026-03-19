# Web Frontend Performance Optimization - Comprehensive Guide (2024-2026)

Techniques for maximizing Lighthouse / Core Web Vitals scores in a hackathon setting.

---

## 1. Image Optimization

### Modern Formats

| Format | Savings vs JPEG | Browser Support | Best For |
|--------|----------------|-----------------|----------|
| WebP   | ~25-35%        | 97%+            | General use, both lossy/lossless |
| AVIF   | ~50%+          | 92%+            | Maximum compression, high quality |

### `<picture>` Element with Format Fallback

```html
<picture>
  <source srcset="image.avif" type="image/avif">
  <source srcset="image.webp" type="image/webp">
  <img src="image.jpg" alt="description"
       width="800" height="600"
       loading="lazy"
       decoding="async">
</picture>
```

### Responsive Images with srcset

```html
<img
  srcset="image-400.webp 400w,
          image-800.webp 800w,
          image-1200.webp 1200w"
  sizes="(max-width: 600px) 400px,
         (max-width: 900px) 800px,
         1200px"
  src="image-800.webp"
  alt="description"
  width="800" height="600"
  loading="lazy"
  decoding="async"
>
```

### LCP Image: Eager Load with fetchpriority

```html
<!-- For the LCP hero image: NO lazy loading, high priority -->
<img
  src="hero.webp"
  alt="Hero"
  width="1200" height="600"
  fetchpriority="high"
  decoding="async"
>
<!-- Also preload it in <head> -->
<link rel="preload" as="image" href="hero.webp" fetchpriority="high">
```

### Compression Quality Settings

- **WebP lossy**: 70-85% quality (visually identical to original)
- **AVIF lossy**: 50-80% quality (even better compression)
- **Use tools**: `sharp`, `squoosh`, `imagemin` for automated compression in build pipelines

### Key Rules

- Always set explicit `width` and `height` attributes (prevents CLS)
- Use `loading="lazy"` for below-the-fold images
- Use `loading="eager"` + `fetchpriority="high"` for LCP image only
- Use `decoding="async"` on all images
- Serve responsive sizes -- never serve a 2000px image to a 400px viewport

---

## 2. JavaScript Optimization

### Code Splitting with Dynamic Imports

```javascript
// Route-based splitting (React)
import { lazy, Suspense } from 'react';

const Dashboard = lazy(() => import('./pages/Dashboard'));
const Settings = lazy(() => import('./pages/Settings'));

function App() {
  return (
    <Suspense fallback={<LoadingSpinner />}>
      <Routes>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
      </Routes>
    </Suspense>
  );
}
```

### Tree Shaking -- Use Named Imports

```javascript
// BAD: imports entire library (~70KB for lodash)
import _ from 'lodash';

// GOOD: tree-shakeable, imports only what's used (~4KB)
import { debounce } from 'lodash-es';

// BEST: use native alternatives when possible
// Instead of lodash.cloneDeep, use structuredClone()
const copy = structuredClone(originalObject);
```

### Replace Heavy Libraries

| Heavy Library | Lighter Alternative | Size Reduction |
|--------------|--------------------|-|
| moment.js (330KB) | date-fns or dayjs (~2-7KB) | ~97% |
| lodash (70KB) | lodash-es (tree-shakeable) or native | ~80%+ |
| axios (13KB) | native fetch() | 100% |
| jQuery (87KB) | native DOM APIs | 100% |
| numeral.js | Intl.NumberFormat (native) | 100% |

### Bundle Analysis

```bash
# Webpack
npx webpack-bundle-analyzer stats.json

# Vite
npx vite-bundle-visualizer
```

### Minification

- Vite/esbuild: enabled by default in production
- Webpack: use TerserPlugin or esbuild-loader
- Enable `compress.drop_console: true` to strip console.log in production

---

## 3. CSS Optimization

### Critical CSS Inlining

Inline above-the-fold CSS directly in `<head>`, lazy-load the rest:

```html
<head>
  <!-- Critical CSS inlined -->
  <style>
    /* Only styles needed for above-the-fold content */
    body { margin: 0; font-family: system-ui, sans-serif; }
    .hero { display: flex; align-items: center; min-height: 60vh; }
    .nav { display: flex; gap: 1rem; padding: 1rem; }
  </style>

  <!-- Full CSS lazy-loaded -->
  <link rel="preload" href="/styles.css" as="style" onload="this.onload=null;this.rel='stylesheet'">
  <noscript><link rel="stylesheet" href="/styles.css"></noscript>
</head>
```

#### Build Tool: Critters (Webpack) / Beasties (Vite)

```javascript
// Webpack
const Critters = require('critters-webpack-plugin');
module.exports = {
  plugins: [
    new Critters({
      preload: 'swap',
      includeSelectors: [/^\.btn/, '.banner'],
    })
  ]
};

// Vite -- use beasties
import { defineConfig } from 'vite';
import beasties from 'vite-plugin-beasties';

export default defineConfig({
  plugins: [
    beasties({ options: { preload: 'swap' } })
  ]
});
```

### Remove Unused CSS

```javascript
// PurgeCSS with PostCSS (postcss.config.js)
module.exports = {
  plugins: [
    require('@fullhuman/postcss-purgecss')({
      content: ['./src/**/*.html', './src/**/*.jsx', './src/**/*.tsx'],
      defaultExtractor: content => content.match(/[\w-/:]+(?<!:)/g) || [],
      safelist: ['active', 'disabled', /^data-/],
    }),
    require('cssnano')({ preset: 'default' }),
  ]
};
```

### Efficient CSS Patterns

```css
/* BAD: triggers layout reflow */
.box { transition: width 0.3s ease; }

/* GOOD: GPU-composited, only affects composite layer */
.box { transition: transform 0.3s ease; }
.box:hover { transform: scale(1.05); }

/* Use contain for isolated components */
.card {
  contain: layout style paint;
  contain-intrinsic-size: 300px 200px;
}

/* Prefer efficient selectors */
/* BAD */  body #sidebar ul li .nav-link { color: blue; }
/* GOOD */ .sidebar-nav-link { color: blue; }
```

---

## 4. Font Optimization

### WOFF2 with font-display and Subsetting

```css
@font-face {
  font-family: 'CustomFont';
  src: url('/fonts/custom-latin.woff2') format('woff2');
  font-weight: 400;
  font-style: normal;
  font-display: swap;          /* swap for body text */
  unicode-range: U+0000-00FF;  /* Latin only -- smaller file */
}

/* Optional for decorative fonts */
@font-face {
  font-family: 'DecorativeFont';
  src: url('/fonts/decorative.woff2') format('woff2');
  font-display: optional;      /* optional = skip if slow */
}
```

### Preload Critical Fonts (max 1-2)

```html
<link rel="preload"
      href="/fonts/custom-latin.woff2"
      as="font"
      type="font/woff2"
      crossorigin>
```

### Font Subsetting Commands

```bash
# Using pyftsubset (Python)
pip install fonttools brotli
pyftsubset font.ttf \
  --output-file=font-subset.woff2 \
  --flavor=woff2 \
  --layout-features='*' \
  --unicodes="U+0000-00FF,U+0100-017F"

# Using glyphhanger
npm install -g glyphhanger
glyphhanger --whitelist=U+0000-00FF --subset=font.ttf --formats=woff2
```

### Unicode-Range Splitting (Load Only What's Needed)

```css
/* Basic Latin -- always loaded */
@font-face {
  font-family: 'FontName';
  src: url('/fonts/font-latin.woff2') format('woff2');
  unicode-range: U+0000-00FF;
}

/* Latin Extended -- only if characters present on page */
@font-face {
  font-family: 'FontName';
  src: url('/fonts/font-latin-ext.woff2') format('woff2');
  unicode-range: U+0100-017F;
}
```

### System Font Stack as Fallback / Alternative

```css
/* Eliminates font loading entirely */
body {
  font-family: system-ui, -apple-system, BlinkMacSystemFont,
               'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
}
```

---

## 5. Network Optimization

### Resource Hints in `<head>` (Order Matters)

```html
<head>
  <!-- 1. Preconnect to critical origins (saves 100-500ms each) -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://cdn.example.com" crossorigin>

  <!-- 2. DNS-prefetch as fallback for broader support -->
  <link rel="dns-prefetch" href="https://analytics.example.com">

  <!-- 3. Preload critical resources -->
  <link rel="preload" href="/fonts/main.woff2" as="font" type="font/woff2" crossorigin>
  <link rel="preload" href="/hero.webp" as="image" fetchpriority="high">
  <link rel="preload" href="/critical.css" as="style">

  <!-- 4. Prefetch resources for likely next navigation -->
  <link rel="prefetch" href="/next-page.js">
</head>
```

### Compression (Server/CDN Configuration)

```nginx
# Nginx -- Enable Brotli (20-26% better than gzip)
brotli on;
brotli_comp_level 6;          # 4-6 for dynamic, 9-11 for pre-compressed static
brotli_types text/html text/css application/javascript application/json image/svg+xml;

# Fallback gzip
gzip on;
gzip_comp_level 6;
gzip_types text/html text/css application/javascript application/json image/svg+xml;
```

### Caching Headers

```nginx
# Static assets with content hash in filename -- immutable
location ~* \.(js|css|woff2|avif|webp)$ {
  add_header Cache-Control "public, max-age=31536000, immutable";
}

# HTML -- always revalidate
location ~* \.html$ {
  add_header Cache-Control "no-cache, must-revalidate";
}
```

### HTTP/2 Benefits (no config needed if CDN/hosting supports it)

- Multiplexing: multiple requests over one connection
- Header compression
- Server push (deprecated in HTTP/3, use preload hints instead)

---

## 6. Rendering Optimization

### SSR / SSG / ISR Strategy

| Strategy | Best For | LCP Impact |
|----------|----------|------------|
| SSG      | Static content, blogs | Fastest -- pre-rendered HTML from CDN |
| SSR      | Dynamic, personalized content | Fast -- HTML on first request |
| ISR      | Semi-dynamic content | Fast -- cached SSR with revalidation |
| CSR      | App-like dashboards | Slowest -- blank until JS executes |

### Progressive / Partial Hydration

- Only hydrate interactive components; leave static HTML alone
- Frameworks: Astro (islands architecture), React Server Components
- Reduces JavaScript shipped to client dramatically

### HTML Streaming (SSR)

```javascript
// React 18+ streaming SSR
import { renderToPipeableStream } from 'react-dom/server';

app.get('/', (req, res) => {
  const { pipe } = renderToPipeableStream(<App />, {
    bootstrapScripts: ['/client.js'],
    onShellReady() {
      res.statusCode = 200;
      res.setHeader('Content-Type', 'text/html');
      pipe(res);  // Start streaming HTML immediately
    }
  });
});
```

### Avoid Layout Shifts

- Always set `width` + `height` on `<img>`, `<video>`, `<iframe>`
- Use `aspect-ratio` CSS for responsive containers
- Reserve space for dynamic content (ads, embeds) with `min-height`

```css
.ad-slot {
  min-height: 250px;
  contain: layout;
}
.video-wrapper {
  aspect-ratio: 16 / 9;
  width: 100%;
}
```

---

## 7. Core Web Vitals -- Specific Techniques

### Thresholds (2025-2026)

| Metric | Good | Needs Improvement | Poor |
|--------|------|-------------------|------|
| LCP    | ≤ 2.5s | 2.5-4.0s | > 4.0s |
| INP    | ≤ 200ms | 200-500ms | > 500ms |
| CLS    | ≤ 0.1 | 0.1-0.25 | > 0.25 |

### LCP Optimization Checklist

1. **Preload the LCP resource**: `<link rel="preload">` with `fetchpriority="high"`
2. **Optimize LCP image**: WebP/AVIF, compressed, responsive sizes
3. **Inline critical CSS**: No render-blocking stylesheets
4. **Reduce TTFB**: CDN, edge caching, SSR/SSG
5. **Eliminate render-blocking JS**: defer/async all scripts
6. **Preconnect to origin**: if LCP resource is cross-origin

### INP Optimization -- Yield to Main Thread

```javascript
// 1. scheduler.yield() -- best option (Chrome 129+)
async function processLargeList(items) {
  for (let i = 0; i < items.length; i++) {
    processItem(items[i]);
    if (i % 10 === 0 && navigator.scheduling?.isInputPending?.()) {
      await scheduler.yield();  // yield, then resume at front of queue
    }
  }
}

// 2. setTimeout fallback -- works everywhere
async function processInChunks(data, chunkSize = 100) {
  for (let i = 0; i < data.length; i += chunkSize) {
    const chunk = data.slice(i, i + chunkSize);
    processChunk(chunk);
    // Yield to main thread
    await new Promise(resolve => setTimeout(resolve, 0));
  }
}

// 3. requestIdleCallback -- for truly non-urgent work
function doNonUrgentWork(tasks) {
  function processNext(deadline) {
    while (deadline.timeRemaining() > 0 && tasks.length > 0) {
      tasks.shift()();
    }
    if (tasks.length > 0) {
      requestIdleCallback(processNext);
    }
  }
  requestIdleCallback(processNext);
}
```

### INP Additional Techniques

- **Reduce DOM size**: keep under 1,400 elements; large DOMs slow down every interaction
- **Use CSS `content-visibility: auto`**: skip rendering off-screen content

```css
.below-fold-section {
  content-visibility: auto;
  contain-intrinsic-size: auto 500px;
}
```

- **Debounce input handlers**: don't process every keystroke

```javascript
const debouncedSearch = debounce((query) => {
  performSearch(query);
}, 300);

input.addEventListener('input', (e) => debouncedSearch(e.target.value));
```

### CLS Optimization Checklist

1. Set explicit dimensions on all media (`width`/`height`, `aspect-ratio`)
2. Use `font-display: optional` or `swap` with proper fallback metrics
3. Reserve space for ads/embeds with `min-height`
4. Never inject content above existing content
5. Use CSS `transform` for animations (not `top`/`left`/`width`/`height`)
6. Preload fonts to avoid FOUT/FOIT layout shifts

---

## 8. Build Tool Optimization

### Vite Configuration (Recommended for 2025+)

```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  build: {
    target: 'es2020',          // Modern browsers only
    minify: 'esbuild',         // Fastest minifier
    sourcemap: false,          // Disable for production
    cssMinify: 'lightningcss', // Fastest CSS minifier
    rollupOptions: {
      output: {
        manualChunks: {
          // Separate vendor chunk for caching
          vendor: ['react', 'react-dom', 'react-router-dom'],
          // Separate large libraries
          // charts: ['recharts', 'd3'],
        },
      },
    },
  },
});
```

### Dynamic Chunk Splitting (Vite)

```typescript
// Automatically create per-dependency chunks
import { dependencies } from './package.json';

function renderChunks(deps: Record<string, string>) {
  const chunks: Record<string, string[]> = {};
  Object.keys(deps).forEach((key) => {
    if (['react', 'react-router-dom', 'react-dom'].includes(key)) return;
    chunks[key] = [key];
  });
  return chunks;
}

export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-router-dom', 'react-dom'],
          ...renderChunks(dependencies),
        },
      },
    },
  },
});
```

### Webpack Optimization

```javascript
// webpack.config.js
module.exports = {
  optimization: {
    splitChunks: {
      chunks: 'all',
      maxInitialRequests: 25,
      minSize: 20000,
      cacheGroups: {
        vendor: {
          test: /[\\/]node_modules[\\/]/,
          name(module) {
            const packageName = module.context.match(
              /[\\/]node_modules[\\/](.*?)([\\/]|$)/
            )[1];
            return `vendor.${packageName.replace('@', '')}`;
          },
        },
      },
    },
    minimizer: [
      new TerserPlugin({
        terserOptions: {
          compress: { drop_console: true, drop_debugger: true },
        },
      }),
    ],
  },
};
```

---

## 9. Third-Party Script Optimization

### Script Loading Attributes

```html
<!-- BLOCKING (bad): parser stops, downloads, executes -->
<script src="analytics.js"></script>

<!-- ASYNC: downloads in parallel, executes immediately when ready (may block) -->
<script src="analytics.js" async></script>

<!-- DEFER: downloads in parallel, executes after DOM parsing (best for most) -->
<script src="analytics.js" defer></script>
```

### Facade Pattern -- Lazy Load Embeds

```html
<!-- Instead of loading a YouTube iframe immediately: -->
<!-- Show a static thumbnail, load iframe on click -->
<div class="youtube-facade" data-video-id="dQw4w9WgXcQ">
  <img src="https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"
       alt="Video thumbnail" loading="lazy">
  <button aria-label="Play video">▶</button>
</div>

<script>
document.querySelectorAll('.youtube-facade').forEach(el => {
  el.addEventListener('click', () => {
    const iframe = document.createElement('iframe');
    iframe.src = `https://www.youtube.com/embed/${el.dataset.videoId}?autoplay=1`;
    iframe.allow = 'autoplay; encrypted-media';
    el.replaceWith(iframe);
  }, { once: true });
});
</script>
```

### Move Third-Party Scripts to Web Workers (Partytown)

```html
<!-- Partytown: runs third-party scripts off main thread -->
<script>
  partytown = { forward: ['dataLayer.push'] };
</script>
<script src="/~partytown/partytown.js"></script>

<!-- This script runs in a web worker, not main thread -->
<script type="text/partytown" src="https://www.googletagmanager.com/gtag/js?id=G-XXXXX"></script>
```

### Preconnect to Third-Party Origins

```html
<link rel="preconnect" href="https://www.google-analytics.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="dns-prefetch" href="https://cdn.jsdelivr.net">
```

---

## 10. Server-Side Optimization

### Response Compression (Express.js Example)

```javascript
import compression from 'compression';
import shrinkRay from 'shrink-ray-current'; // Brotli support

// Brotli + gzip
app.use(shrinkRay());

// Or basic gzip
app.use(compression({
  level: 6,
  threshold: 1024,  // Don't compress below 1KB
  filter: (req, res) => {
    if (req.headers['x-no-compression']) return false;
    return compression.filter(req, res);
  }
}));
```

### Cache Headers (Express.js)

```javascript
// Static assets with hashed filenames
app.use('/assets', express.static('dist/assets', {
  maxAge: '1y',
  immutable: true,
}));

// HTML -- always revalidate
app.use(express.static('dist', {
  maxAge: 0,
  etag: true,
  lastModified: true,
}));
```

### Redis Caching for API Responses

```javascript
import Redis from 'ioredis';
const redis = new Redis();

async function getCachedData(key, fetchFn, ttl = 300) {
  const cached = await redis.get(key);
  if (cached) return JSON.parse(cached);

  const data = await fetchFn();
  await redis.setex(key, ttl, JSON.stringify(data));
  return data;
}

app.get('/api/products', async (req, res) => {
  const products = await getCachedData(
    'products:all',
    () => db.query('SELECT * FROM products'),
    600  // 10 min TTL
  );
  res.json(products);
});
```

### Database Query Optimization

- Add indexes for frequently queried columns
- Use pagination (LIMIT/OFFSET or cursor-based)
- Select only needed columns (`SELECT id, name` not `SELECT *`)
- Use connection pooling
- Cache expensive queries in Redis/Memcached

---

## 11. React-Specific Optimization

### React.lazy + Suspense (Route-Level)

```javascript
import { lazy, Suspense } from 'react';

const Dashboard = lazy(() => import('./pages/Dashboard'));
const Settings = lazy(() => import('./pages/Settings'));

function App() {
  return (
    <Suspense fallback={<LoadingSpinner />}>
      <Routes>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
      </Routes>
    </Suspense>
  );
}
```

### Virtualized Lists (react-window)

```javascript
import { FixedSizeList } from 'react-window';

function ProductList({ products }) {
  return (
    <FixedSizeList
      height={800}
      itemCount={products.length}
      itemSize={120}
      width="100%"
    >
      {({ index, style }) => (
        <div style={style}>
          <ProductCard {...products[index]} />
        </div>
      )}
    </FixedSizeList>
  );
}
```

### Web Workers for Heavy Computation

```javascript
// worker.js
self.onmessage = function(e) {
  const result = performExpensiveOperation(e.data);
  self.postMessage(result);
};

// Component
function DataProcessor({ rawData }) {
  const [processedData, setProcessedData] = useState(null);

  useEffect(() => {
    const worker = new Worker(new URL('./worker.js', import.meta.url));
    worker.onmessage = (e) => setProcessedData(e.data);
    worker.postMessage(rawData);
    return () => worker.terminate();
  }, [rawData]);

  return processedData ? <DataVisualization data={processedData} /> : <Spinner />;
}
```

### React Compiler (2025+)

React Compiler automatically adds memoization at build time. No manual `React.memo`, `useMemo`, or `useCallback` needed:

```javascript
// React Compiler handles this automatically
const ExpensiveComponent = ({ data, onUpdate }) => {
  const processedData = data.map(item => heavyCalculation(item));
  const handleClick = () => onUpdate(processedData);
  return <div onClick={handleClick}>{processedData.length} items</div>;
};
```

### Profiler for Measurement

```javascript
import { Profiler } from 'react';

function onRender(id, phase, actualDuration) {
  if (actualDuration > 16) {  // > 1 frame at 60fps
    console.warn(`Slow render: ${id} took ${actualDuration}ms`);
  }
}

<Profiler id="Dashboard" onRender={onRender}>
  <Dashboard />
</Profiler>
```

### Next.js Image Optimization

```javascript
import Image from 'next/image';

function ProductGallery({ images }) {
  return (
    <div className="gallery">
      {images.map((img, idx) => (
        <Image
          key={img.id}
          src={img.url}
          width={400}
          height={300}
          loading={idx < 3 ? 'eager' : 'lazy'}
          priority={idx === 0}
          placeholder="blur"
          quality={85}
          sizes="(max-width: 768px) 100vw, 33vw"
          alt={img.alt}
        />
      ))}
    </div>
  );
}
```

### Memory Leak Prevention

```javascript
function GoodComponent() {
  useEffect(() => {
    const controller = new AbortController();
    const interval = setInterval(() => setCount(c => c + 1), 1000);
    window.addEventListener('resize', handleResize);

    fetch('/api/data', { signal: controller.signal })
      .then(r => r.json())
      .then(setData);

    return () => {
      controller.abort();
      clearInterval(interval);
      window.removeEventListener('resize', handleResize);
    };
  }, []);
}
```

---

## 12. HTML Optimization

### Optimal `<head>` Order for Performance

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">

  <!-- 1. Preconnect (earliest possible) -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://cdn.example.com" crossorigin>
  <link rel="dns-prefetch" href="https://analytics.example.com">

  <!-- 2. Preload critical resources -->
  <link rel="preload" href="/fonts/main.woff2" as="font" type="font/woff2" crossorigin>
  <link rel="preload" href="/hero.avif" as="image" type="image/avif" fetchpriority="high">

  <!-- 3. Critical CSS inlined -->
  <style>/* above-the-fold styles only */</style>

  <!-- 4. Full CSS lazy-loaded -->
  <link rel="preload" href="/styles.css" as="style" onload="this.onload=null;this.rel='stylesheet'">
  <noscript><link rel="stylesheet" href="/styles.css"></noscript>

  <!-- 5. Prefetch for next page navigation -->
  <link rel="prefetch" href="/about.js">

  <title>Page Title</title>
  <meta name="description" content="...">
</head>
<body>
  <!-- Content -->

  <!-- Scripts at end, deferred -->
  <script src="/app.js" defer></script>
  <script src="/analytics.js" defer></script>
</body>
</html>
```

### content-visibility for Off-Screen Content

```css
/* Browser skips rendering until near viewport -- huge INP/paint win */
section.below-fold {
  content-visibility: auto;
  contain-intrinsic-size: auto 600px;
}
```

### Font Caching Headers (Server Config)

```nginx
# Nginx
location ~* \.(woff2|woff)$ {
  add_header Cache-Control "public, max-age=31536000, immutable";
  add_header Access-Control-Allow-Origin "*";
}
```

```apache
# Apache
<FilesMatch "\.(woff2|woff)$">
  Header set Cache-Control "public, max-age=31536000, immutable"
  Header set Access-Control-Allow-Origin "*"
</FilesMatch>
```

---

## Quick-Win Hackathon Checklist

Priority order for maximum Lighthouse impact in minimal time:

1. **[LCP]** Preload hero image with `fetchpriority="high"`, convert to WebP/AVIF
2. **[LCP]** Inline critical CSS, defer everything else
3. **[LCP]** Add `<link rel="preconnect">` for third-party origins
4. **[CLS]** Add `width`/`height` to all `<img>`, `<video>`, `<iframe>`
5. **[CLS]** Set `font-display: swap` on all `@font-face` rules
6. **[INP]** Defer all non-critical JS with `defer` attribute
7. **[INP]** Code-split routes with dynamic `import()`
8. **[Size]** Enable Brotli/gzip compression on server
9. **[Size]** Set long cache headers for static assets
10. **[Size]** Remove unused CSS with PurgeCSS
11. **[Size]** Tree-shake JS: use ES module imports, drop heavy libraries
12. **[INP]** Use `content-visibility: auto` for below-fold sections
13. **[LCP]** Use SSR or SSG instead of client-side rendering
14. **[All]** Lazy-load all below-fold images and third-party embeds
15. **[All]** Subset and preload fonts (WOFF2 only, 1-2 files)

---

## Sources

- [Image Optimization 2025: WebP, AVIF & Best Practices Guide](https://www.frontendtools.tech/blog/modern-image-optimization-techniques-2025)
- [How to Optimize Website Images: The Complete 2026 Guide](https://requestmetrics.com/web-performance/high-performance-images/)
- [Fix your website's LCP by optimizing image loading (MDN)](https://developer.mozilla.org/en-US/blog/fix-image-lcp/)
- [Image Performance (web.dev)](https://web.dev/learn/performance/image-performance)
- [Complete Guide to JavaScript Bundle Optimization](https://medium.com/@jajibhee/the-complete-guide-to-javascript-bundle-optimization-code-splitting-and-tree-shaking-7ddbdcbd7957)
- [How to Reduce JavaScript Bundle Size in 2025](https://dev.to/frontendtoolstech/how-to-reduce-javascript-bundle-size-in-2025-2n77)
- [Optimizing Bundle Size: Tree-Shaking, Code-Splitting, Dead Code Elimination](https://namastedev.com/blog/optimizing-bundle-size-tree-shaking-code-splitting-and-dead-code-elimination/)
- [CSS Optimization Guide 2025](https://dev.to/satyam_gupta_0d1ff2152dcc/css-optimization-guide-2025-speed-up-your-website-best-practices-code-examples-31ib)
- [CSS Performance Optimization (MDN)](https://developer.mozilla.org/en-US/docs/Learn_web_development/Extensions/Performance/CSS)
- [Complete Web Font Optimization Guide: WOFF2, Subsetting & Performance 2025](https://font-converters.com/guides/web-font-optimization)
- [Font Loading Strategies: font-display, Preloading & Performance Guide 2025](https://font-converters.com/guides/font-loading-strategies)
- [Web Font Optimization in 2026](https://www.enepsters.com/2026/03/web-font-optimization-in-2026-balancing-performance-accessibility-and-design/)
- [Core Web Vitals 2026: INP, LCP & CLS Optimization](https://www.digitalapplied.com/blog/core-web-vitals-2026-inp-lcp-cls-optimization-guide)
- [Core Web Vitals Optimization Guide 2026](https://skyseodigital.com/core-web-vitals-optimization-complete-guide-for-2026/)
- [Most Important Core Web Vitals Metrics in 2026](https://nitropack.io/blog/most-important-core-web-vitals-metrics/)
- [INP Optimization Guide 2025](https://roastweb.com/blog/inp-optimization-guide-2025)
- [scheduler.yield(): Chrome's API for Optimizing INP](https://nitropack.io/blog/post/introducing-scheduler-yield)
- [Optimize Long Tasks (web.dev)](https://web.dev/articles/optimize-long-tasks)
- [React Performance Optimization: 15 Best Practices for 2025](https://dev.to/alex_bobes/react-performance-optimization-15-best-practices-for-2025-17l9)
- [React Performance Optimization in 2026](https://viprasol.com/blog/react-performance-optimization/)
- [React Performance Optimization: Advanced Techniques for 2026](https://softtechnosol.com/blog/react-js-optimization-techniques-for-faster-apps/)
- [Vite Code Splitting That Works](https://sambitsahoo.com/blog/vite-code-splitting-that-works.html)
- [Vite vs. Webpack in 2026: Migration Guide and Performance Analysis](https://dev.to/pockit_tools/vite-vs-webpack-in-2026-a-complete-migration-guide-and-deep-performance-analysis-5ej5)
- [Critters: Webpack Plugin to Inline Critical CSS](https://github.com/GoogleChromeLabs/critters)
- [Beasties: Inline Critical CSS for Vite](https://github.com/danielroe/beasties)
- [Efficiently Load Third-Party JavaScript (web.dev)](https://web.dev/articles/efficiently-load-third-party-javascript)
- [Lazy Load Third-Party Resources with Facades (Chrome DevDocs)](https://developer.chrome.com/docs/lighthouse/performance/third-party-facades)
- [Preload, Preconnect, Prefetch: Resource Hints for Performance](https://nitropack.io/blog/resource-hints-performance-optimization/)
- [Browser Resource Hints (DebugBear)](https://www.debugbear.com/blog/resource-hints-rel-preload-prefetch-preconnect)
- [Frontend Performance Checklist 2025](https://strapi.io/blog/frontend-performance-checklist)
- [Web Performance Best Practices (MDN)](https://developer.mozilla.org/en-US/docs/Learn_web_development/Extensions/Performance/Best_practices)
- [CSR vs SSR vs SSG vs ISR: Best Rendering Method in 2026](https://hashbyt.com/blog/csr-vs-ssr-vs-ssg-vs-isr)
- [Revisiting HTML Streaming for Modern Web Performance](https://calendar.perfplanet.com/2025/revisiting-html-streaming-for-modern-web-performance/)
- [Website Caching Strategies for 2025](https://blog.copyelement.com/website-caching-strategies-for-2025-maximize-speed-and-performance/)
- [Optimizing Performance in REST APIs: Caching to Compression](https://moldstud.com/articles/p-optimizing-performance-in-rest-apis-from-caching-to-compression)
