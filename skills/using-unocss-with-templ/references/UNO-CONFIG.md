# UnoCSS Configuration for Templ

Detailed configuration options for `uno.config.ts` when using UnoCSS with templ.

## Basic Configuration

```ts
// uno.config.ts
import { defineConfig, presetUno } from 'unocss'

export default defineConfig({
  presets: [presetUno()],
  content: {
    filesystem: ['**/*.templ'],
  },
})
```

## Content Extraction

### Filesystem Extraction

For templ projects, use `filesystem` to specify which files to scan:

```ts
export default defineConfig({
  content: {
    filesystem: [
      '**/*.templ',           // All templ files
      'components/**/*.templ', // Specific directory
      'static/**/*.html',      // HTML files too
    ],
  },
})
```

### CLI Entry Points

Configure multiple output files:

```ts
export default defineConfig({
  cli: {
    entry: [
      {
        patterns: ['components/**/*.templ'],
        outFile: 'static/components.css',
      },
      {
        patterns: ['pages/**/*.templ'],
        outFile: 'static/pages.css',
      },
    ],
  },
})
```

## Presets

### preset-uno (Default)

Tailwind/Windi CSS compatible utilities:

```ts
import { presetUno } from 'unocss'

export default defineConfig({
  presets: [presetUno()],
})
```

### preset-mini

Minimal preset with essential utilities:

```ts
import { presetMini } from 'unocss'

export default defineConfig({
  presets: [presetMini()],
})
```

### preset-wind3

Full Tailwind CSS v3 compatibility:

```ts
import presetWind3 from '@unocss/preset-wind3'

export default defineConfig({
  presets: [presetWind3()],
})
```

### preset-wind4

Tailwind CSS v4 compatibility with CSS variables:

```ts
import presetWind4 from '@unocss/preset-wind4'

export default defineConfig({
  presets: [
    presetWind4({
      preflights: {
        reset: true,
        theme: { mode: 'on-demand' },
      },
    }),
  ],
})
```

### preset-icons

Pure CSS icons from Iconify:

```ts
import { presetIcons } from 'unocss'

export default defineConfig({
  presets: [
    presetUno(),
    presetIcons({
      scale: 1.2,
      cdn: 'https://esm.sh/',
    }),
  ],
})
```

Usage in templ:
```templ
<span class="i-heroicons-check text-green-500"></span>
```

### Combining Presets

```ts
import { defineConfig, presetUno, presetIcons, presetWebFonts } from 'unocss'

export default defineConfig({
  presets: [
    presetUno(),
    presetIcons(),
    presetWebFonts({
      provider: 'google',
      fonts: {
        sans: 'Inter',
        mono: 'Fira Code',
      },
    }),
  ],
})
```

## Custom Rules

Define custom utilities:

```ts
export default defineConfig({
  rules: [
    // Static rule
    ['card', { 'border-radius': '8px', 'box-shadow': '0 2px 4px rgba(0,0,0,0.1)' }],

    // Dynamic rule with regex
    [/^m-(\d+)$/, ([, d]) => ({ margin: `${Number(d) * 4}px` })],

    // With variants support
    [/^p-(\d+)$/, ([, d]) => ({ padding: `${Number(d) * 0.25}rem` }), { layer: 'utilities' }],
  ],
})
```

## Shortcuts

Combine multiple utilities:

```ts
export default defineConfig({
  shortcuts: {
    // Static shortcut
    'btn': 'px-4 py-2 rounded font-medium',
    'btn-primary': 'btn bg-blue-500 text-white hover:bg-blue-600',
    'btn-secondary': 'btn bg-gray-200 text-gray-800 hover:bg-gray-300',

    // Card variants
    'card': 'p-4 bg-white rounded-lg shadow',
    'card-hover': 'card hover:shadow-lg transition-shadow',
  },

  // Dynamic shortcuts
  shortcuts: [
    ['btn', 'px-4 py-2 rounded font-medium'],
    [/^btn-(.*)$/, ([, c]) => `btn bg-${c}-500 text-white hover:bg-${c}-600`],
  ],
})
```

Usage in templ:
```templ
<button class="btn-primary">Submit</button>
<div class="card-hover">Content</div>
```

## Theme Customization

```ts
export default defineConfig({
  theme: {
    colors: {
      brand: {
        primary: '#3B82F6',
        secondary: '#10B981',
        accent: '#F59E0B',
      },
    },
    spacing: {
      xs: '0.25rem',
      sm: '0.5rem',
      md: '1rem',
      lg: '1.5rem',
      xl: '2rem',
    },
    breakpoints: {
      sm: '640px',
      md: '768px',
      lg: '1024px',
      xl: '1280px',
    },
  },
})
```

Usage:
```templ
<div class="bg-brand-primary p-md text-white">Branded content</div>
```

## Safelist

Always include specific utilities:

```ts
export default defineConfig({
  safelist: [
    // Explicit list
    'bg-red-500',
    'bg-green-500',
    'bg-blue-500',

    // Generate programmatically
    ...['red', 'green', 'blue'].map(c => `text-${c}-500`),
    ...Array.from({ length: 10 }, (_, i) => `p-${i}`),
  ],
})
```

### Dynamic Safelist from Theme

```ts
export default defineConfig({
  safelist: (theme) => {
    const colors = Object.keys(theme.colors || {})
    return colors.flatMap(c => [`bg-${c}`, `text-${c}`, `border-${c}`])
  },
})
```

## Layers

Control CSS output order:

```ts
export default defineConfig({
  layers: {
    preflights: -1,  // First
    base: 0,
    components: 1,
    default: 2,      // Most utilities
    utilities: 3,    // Last
  },
})
```

### CSS Cascade Layers

Output to CSS `@layer`:

```ts
export default defineConfig({
  outputToCssLayers: true,
  // Custom layer names
  outputToCssLayers: {
    cssLayerName: (layer) => `uno-${layer}`,
  },
})
```

## Transformers

### Variant Groups

Enable `hover:(bg-blue-500 text-white)` syntax:

```ts
import transformerVariantGroup from '@unocss/transformer-variant-group'

export default defineConfig({
  transformers: [transformerVariantGroup()],
})
```

### Directives

Enable `@apply` in CSS:

```ts
import transformerDirectives from '@unocss/transformer-directives'

export default defineConfig({
  transformers: [transformerDirectives()],
})
```

## Complete Example

```ts
// uno.config.ts
import {
  defineConfig,
  presetUno,
  presetIcons,
  transformerVariantGroup,
} from 'unocss'

export default defineConfig({
  presets: [
    presetUno(),
    presetIcons({
      scale: 1.2,
      extraProperties: {
        'display': 'inline-block',
        'vertical-align': 'middle',
      },
    }),
  ],
  transformers: [transformerVariantGroup()],
  content: {
    filesystem: ['**/*.templ'],
  },
  theme: {
    colors: {
      brand: {
        50: '#eff6ff',
        500: '#3b82f6',
        900: '#1e3a8a',
      },
    },
  },
  shortcuts: {
    'btn': 'px-4 py-2 rounded-lg font-medium transition-colors',
    'btn-primary': 'btn bg-brand-500 text-white hover:bg-brand-900',
    'card': 'p-6 bg-white rounded-xl shadow-md',
  },
  safelist: [
    'bg-red-500',
    'bg-green-500',
    'bg-yellow-500',
  ],
})
```
