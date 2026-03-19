# Image & Font Optimization

## Image Format Conversion

### Batch Convert to AVIF (Best Compression)
```bash
# Using ImageMagick
for f in public/images/*.{png,jpg,jpeg}; do
  magick "$f" -quality 50 "${f%.*}.avif"
done

# Using Sharp (Node.js script)
```

```js
// scripts/convert-images.mjs
import sharp from 'sharp';
import { glob } from 'glob';

const files = await glob('public/images/*.{png,jpg,jpeg}');
for (const file of files) {
  const output = file.replace(/\.(png|jpe?g)$/, '.avif');
  await sharp(file)
    .resize({ width: 800, withoutEnlargement: true })
    .avif({ quality: 50 })
    .toFile(output);
  console.log(`${file} → ${output}`);
}
```

### WebP Fallback
```bash
for f in public/images/*.{png,jpg,jpeg}; do
  magick "$f" -quality 75 "${f%.*}.webp"
done
```

## HTML Picture Element
```html
<picture>
  <source srcset="/images/hero.avif" type="image/avif" />
  <source srcset="/images/hero.webp" type="image/webp" />
  <img src="/images/hero.jpg" alt="Hero" width="800" height="450"
       loading="lazy" decoding="async" />
</picture>
```

## LCP Image Optimization
```html
<!-- For the Largest Contentful Paint element -->
<link rel="preload" as="image" href="/images/hero.avif" type="image/avif" />
<img src="/images/hero.avif" alt="Hero" width="800" height="450"
     fetchpriority="high" decoding="async" />
```

**Do NOT** add `loading="lazy"` to the LCP image.

## Animated GIF → Video
```bash
ffmpeg -i animation.gif -c:v libvpx-vp9 -b:v 0 -crf 30 animation.webm
ffmpeg -i animation.gif -c:v libx264 -pix_fmt yuv420p animation.mp4
```

```html
<!-- Replace <img src="animation.gif"> with: -->
<video autoplay loop muted playsinline width="320" height="240">
  <source src="/animation.webm" type="video/webm" />
  <source src="/animation.mp4" type="video/mp4" />
</video>
```

## Responsive Images
```html
<img srcset="/img/photo-400.avif 400w,
             /img/photo-800.avif 800w,
             /img/photo-1200.avif 1200w"
     sizes="(max-width: 600px) 400px, 800px"
     src="/img/photo-800.avif"
     alt="Photo" width="800" height="600"
     loading="lazy" decoding="async" />
```

## CLS Prevention for Images
Always set explicit dimensions:
```html
<img src="photo.avif" width="800" height="600" alt="..." />
```

Or use CSS aspect-ratio:
```css
img {
  aspect-ratio: 16 / 9;
  width: 100%;
  height: auto;
}
```

---

## Font Optimization

### Subsetting with pyftsubset
```bash
# Japanese font — subset to used characters
pyftsubset NotoSansJP-Regular.ttf \
  --text-file=used-chars.txt \
  --output-file=NotoSansJP-subset.woff2 \
  --flavor=woff2

# Or subset to specific Unicode ranges
pyftsubset NotoSansJP-Regular.ttf \
  --unicodes="U+0020-007E,U+3000-30FF,U+4E00-9FFF" \
  --output-file=NotoSansJP-subset.woff2 \
  --flavor=woff2
```

### glyphhanger (Automatic Subsetting)
```bash
npx glyphhanger http://localhost:3000 --subset=fonts/NotoSansJP-Regular.ttf --formats=woff2
```

### Font CSS
```css
@font-face {
  font-family: 'NotoSansJP';
  src: url('/fonts/NotoSansJP-subset.woff2') format('woff2');
  font-display: swap;          /* Show text immediately with fallback */
  font-weight: 400;
  unicode-range: U+3000-30FF, U+4E00-9FFF; /* Only load when needed */
}
```

### Preload Critical Font
```html
<link rel="preload" as="font" type="font/woff2"
      href="/fonts/NotoSansJP-subset.woff2" crossorigin />
```

### Remove Unused Font Weights
If only Regular (400) is used, don't load Bold (700), Light (300), etc. Check which weights are actually referenced in CSS.

### System Font Stack Fallback
```css
/* If custom fonts aren't essential */
font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto,
             'Hiragino Sans', 'Noto Sans JP', sans-serif;
```
