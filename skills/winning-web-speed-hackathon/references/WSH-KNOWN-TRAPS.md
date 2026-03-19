# WSH Known Traps — Intentional Performance Pitfalls

Organizers deliberately introduce these issues. Check for ALL of them early.

## Build/Configuration Traps

| Trap | How to Find | Fix |
|------|-------------|-----|
| `NODE_ENV=development` | Check `package.json` scripts, `.env`, Dockerfile | Set to `production` |
| Webpack `mode: 'none'` or `'development'` | `webpack.config.*` | Set `mode: 'production'` |
| `devtool: 'inline-source-map'` | `webpack.config.*` | Remove or set `devtool: false` |
| No chunk splitting | Webpack `optimization.splitChunks` missing | Add `splitChunks: { chunks: 'all' }` |
| Babel processing all `node_modules` | `babel-loader` without `exclude` | Add `exclude: /node_modules/` |
| No browserslist | Missing `.browserslistrc` or `browserslist` in package.json | Add `last 1 Chrome version` |
| CJS transform killing tree shaking | `@babel/plugin-transform-modules-commonjs` | Remove the plugin |
| PostCSS source maps inlined | `postcss.config.*` with `map: { inline: true }` | Disable or remove |
| CSS custom properties `preserve: true` | PostCSS custom properties plugin | Set `preserve: false` |

## Dependency Bloat Traps

| Dependency | Typical Size | Replacement |
|-----------|-------------|-------------|
| `@iconify/json` | ~60MB | Import only used icons individually |
| `@ffmpeg/ffmpeg` + `@ffmpeg/core` | ~25MB | Remove, use server-side or CDN |
| `zengin-code` | ~5MB | Inline only needed bank data |
| `moment-timezone` | ~1MB | `dayjs` + timezone plugin (~10KB) |
| `lodash` (full) | ~530KB | Native JS or `lodash-es` with tree shaking |
| `canvaskit-wasm` | ~7MB | CSS/`<img>`/Canvas 2D |
| `Three.js` | ~600KB | `<img>` for static renders |
| `@fortawesome/fontawesome-free` | ~1.5MB | SVG icons for only used glyphs |
| `jQuery` | ~87KB | Native DOM APIs |
| `axios` | ~40KB | `fetch()` |
| `bluebird` | ~80KB | Native `Promise` |
| `ImmutableJS` | ~60KB | Spread operator / structuredClone |
| `@js-temporal/polyfill` | ~100KB | `Intl.DateTimeFormat` or `dayjs` |
| `zipcode-ja` | ~1.5MB | API call or subset |
| Various ES5/6/7 shims | ~200KB+ | Remove (target modern Chrome) |

## Network/Delivery Traps

| Trap | How to Find | Fix |
|------|-------------|-----|
| No compression | Missing compression middleware | Add `@fastify/compress`, `compression`, etc. |
| `Cache-Control: no-store` | Response headers in DevTools | Set proper caching for static assets |
| Artificial delays (500-1000ms) | Search `setTimeout`, `sleep`, `delay`, `jitter` in server code | Remove |
| No `defer`/`async` on scripts | Check `<script>` tags in HTML | Add `defer` |
| All images loaded eagerly | Missing `loading="lazy"` | Add lazy loading for off-screen images |
| Oversized images (MB-sized) | Network tab, check image sizes | Resize + convert to AVIF/WebP |
| GIF for animations | Check for `.gif` files | Convert to WebM `<video>` |
| Render-blocking CSS | Large CSS files in `<head>` without async load | Extract critical CSS, defer rest |

## Code-Level Traps

| Trap | How to Find | Fix |
|------|-------------|-----|
| Sequential API calls | Look for `await` chains without `Promise.all` | `Promise.all()` |
| N+1 DB queries | Server route handlers with loops containing queries | JOIN or batch query |
| ReDoS regex | Complex regex in validators (email, password) | Simplify regex |
| Runtime CSS generation | UnoCSS runtime, styled-components without SSR extract | Static CSS files |
| Dynamic component creation in render | `new Component()` or factory in render body | Move outside render, memoize |
| Unnecessary re-renders | React DevTools Profiler | `React.memo`, `useMemo`, `useCallback` |
| Heavy canvas for simple display | CanvasKit for image rendering | `<img>` or CSS |
| Redundant API response data | Circular references (e.g., series→episodes→series) | Trim response payload |
| Random ID generation overhead | `crypto.randomUUID()` in hot paths | Pre-generate or use auto-increment |
| `onMouseOver` instead of `onMouseEnter` | Search for `onMouseOver` | Replace with `onMouseEnter`/`onMouseLeave` |

## Year-Specific Patterns

### WSH 2025 (Video Streaming — AREMA)
- Tech: React 19, Zustand, React Router 7, UnoCSS runtime, Fastify 5, Webpack 5, libSQL
- Key traps: `@ffmpeg/ffmpeg` in bundle, `@iconify/json`, UnoCSS runtime, shaka-player/hls.js/video.js all included
- Video scoring: time-to-first-play matters

### WSH 2024 (Manga — Cyber TOON)
- Tech: React, MUI, Yup, Hono, Drizzle, tsup, SQLite
- Key traps: `canvaskit-wasm` for manga rendering, `Three.js` for hero, zstd compression
- Rule: manga images must stay obfuscated, Service Worker required
- Winner reduced 120MB bundle to 0.39MB

### WSH 2023 (Shopping — Kaeru Organic)
- Tech: React 18, Recoil, styled-components, Koa, GraphQL, Vite (dev mode!), SQLite
- Key traps: Vite running in dev mode, `canvaskit-wasm`, `@js-temporal/polyfill`, `zipcode-ja`, `lodash`

### WSH 2022 (Betting — CyberTicket)
- Tech: React 17, styled-components, framer-motion, Fastify, Webpack 5, SQLite
- Key traps: `zengin-code`, `moment-timezone`, `lodash`, `@fortawesome/fontawesome-free`, `axios`

### WSH 2020 (Blog — Amida Blog)
- Tech: React, Express, Webpack, SQLite
- Key traps: jQuery, moment-timezone, lodash, ImmutableJS, bluebird, axios, multiple ES shims
- Official detailed writeup available in repo wiki
