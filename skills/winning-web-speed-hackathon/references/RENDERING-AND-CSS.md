# Rendering & CSS Optimization

## Remove Runtime CSS-in-JS

Runtime CSS-in-JS (styled-components, Emotion without extract, UnoCSS runtime) generates styles in JS at render time, blocking paint.

### UnoCSS Runtime → Static
```bash
# Generate static CSS at build time
pnpm add -D @unocss/cli
npx unocss "src/**/*.tsx" -o dist/uno.css
```

Then import the static CSS file instead of the runtime.

### styled-components → Static CSS
Replace with plain CSS modules or a utility framework:
```tsx
// Before
const Button = styled.button`
  background: blue;
  color: white;
  padding: 8px 16px;
`;

// After (CSS module)
// Button.module.css: .button { background: blue; color: white; padding: 8px 16px; }
import styles from './Button.module.css';
const Button = (props) => <button className={styles.button} {...props} />;
```

Or extract at build time with `babel-plugin-styled-components` + SSR extraction.

## Critical CSS

### Inline Above-Fold CSS
```html
<head>
  <style>
    /* Critical CSS — only styles needed for initial viewport */
    body { margin: 0; font-family: sans-serif; }
    .header { height: 64px; background: #fff; }
    .hero { width: 100%; aspect-ratio: 16/9; }
  </style>
  <!-- Defer non-critical CSS -->
  <link rel="preload" as="style" href="/styles/main.css" onload="this.rel='stylesheet'" />
  <noscript><link rel="stylesheet" href="/styles/main.css" /></noscript>
</head>
```

### Automated with Critters (Webpack)
```js
const Critters = require('critters-webpack-plugin');

plugins: [
  new Critters({
    preload: 'swap',
    inlineFonts: false,
  }),
]
```

## Remove Unused CSS

### PurgeCSS
```js
// postcss.config.js
const purgecss = require('@fullhuman/postcss-purgecss');

module.exports = {
  plugins: [
    purgecss({
      content: ['./src/**/*.tsx', './src/**/*.html'],
      safelist: ['active', 'open', /^data-/],
    }),
  ],
};
```

### Quick Check
Use Chrome DevTools Coverage tab to see unused CSS percentage. If >50% is unused, purging will help significantly.

## CLS (Cumulative Layout Shift) Fixes

CLS is 25% of the Lighthouse score. Common causes and fixes:

### Images Without Dimensions
```html
<!-- Bad: causes layout shift when image loads -->
<img src="photo.avif" alt="..." />

<!-- Good: reserves space -->
<img src="photo.avif" alt="..." width="800" height="600" />

<!-- Also good: CSS aspect-ratio -->
<img src="photo.avif" alt="..." style="aspect-ratio: 4/3; width: 100%; height: auto;" />
```

### Font Swap Layout Shift
```css
@font-face {
  font-family: 'CustomFont';
  src: url('/font.woff2') format('woff2');
  font-display: swap;
  /* Add size-adjust to minimize swap shift */
  size-adjust: 105%;
  ascent-override: 90%;
  descent-override: 20%;
  line-gap-override: 0%;
}
```

### Dynamic Content Insertion
```css
/* Reserve space for dynamic content */
.ad-slot { min-height: 250px; }
.skeleton { min-height: 200px; background: #f0f0f0; }
```

### Avoid `top`/`left` Animation
```css
/* Bad: triggers layout */
.animate { transition: top 0.3s, left 0.3s; }

/* Good: GPU-composited, no layout shift */
.animate { transition: transform 0.3s; }
```

## Script Loading

```html
<!-- Render-blocking (bad) -->
<script src="/app.js"></script>

<!-- Non-blocking (good) -->
<script src="/app.js" defer></script>

<!-- For non-critical third-party -->
<script src="/analytics.js" async></script>
```

`defer` maintains execution order; `async` does not. Use `defer` for app scripts.

## content-visibility for Off-Screen Content

```css
/* Skip rendering off-screen sections */
.below-fold-section {
  content-visibility: auto;
  contain-intrinsic-size: 0 500px; /* Estimated height */
}
```

Dramatically reduces initial rendering work for long pages.

## Avoid Layout Thrashing

```js
// Bad: read-write-read-write cycle
elements.forEach(el => {
  const height = el.offsetHeight; // read
  el.style.height = height + 10 + 'px'; // write
});

// Good: batch reads, then batch writes
const heights = elements.map(el => el.offsetHeight); // all reads
elements.forEach((el, i) => {
  el.style.height = heights[i] + 10 + 'px'; // all writes
});
```
