# UnoCSS Presets Guide

Presets define the available utility classes in UnoCSS.

## Official Presets

### preset-uno (Default)

Tailwind CSS / Windi CSS compatible:

```ts
import { presetUno } from 'unocss'

export default defineConfig({
  presets: [presetUno()],
})
```

### preset-mini

Minimal essential utilities:

```ts
import { presetMini } from 'unocss'

export default defineConfig({
  presets: [presetMini()],
})
```

### preset-wind3 / preset-wind4

Full Tailwind compatibility:

```ts
import presetWind3 from '@unocss/preset-wind3'
// or
import presetWind4 from '@unocss/preset-wind4'
```

## Feature Presets

### preset-icons

Pure CSS icons from Iconify:

```ts
import { presetIcons } from 'unocss'

export default defineConfig({
  presets: [
    presetUno(),
    presetIcons({ cdn: 'https://esm.sh/' }),
  ],
})
```

Usage: `<span class="i-heroicons-check text-green-500"></span>`

### preset-typography

Prose styling:

```ts
import { presetTypography } from 'unocss'
```

Usage: `<article class="prose">{ content }</article>`

### preset-web-fonts

```ts
import { presetWebFonts } from 'unocss'

presetWebFonts({
  fonts: { sans: 'Inter' },
})
```

## Recommended Setup

```ts
export default defineConfig({
  presets: [
    presetUno(),
    presetIcons({ cdn: 'https://esm.sh/' }),
  ],
})
```
