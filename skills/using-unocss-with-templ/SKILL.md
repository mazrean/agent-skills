---
name: using-unocss-with-templ
description: Integrates UnoCSS atomic CSS engine with Go templ templates for static sites. Use when setting up UnoCSS in templ projects, configuring uno.config.ts for .templ files, using utility classes in templ components, or building static sites with Go and atomic CSS.
---

# Using UnoCSS with Templ

Integrate UnoCSS, an instant on-demand atomic CSS engine, with Go's templ templating language to build static sites with utility-first CSS.

**Use this skill when** setting up UnoCSS for templ projects, configuring CSS extraction from `.templ` files, or building static sites with Go and atomic CSS.

## Quick Start

### 1. Install Dependencies

```bash
# Install templ
go install github.com/a-h/templ/cmd/templ@latest

# Install UnoCSS CLI
npm install -D unocss @unocss/cli
```

### 2. Create UnoCSS Config

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

### 3. Add Package Scripts

```json
{
  "scripts": {
    "css:build": "unocss \"**/*.templ\" -o static/uno.css",
    "css:watch": "unocss \"**/*.templ\" -o static/uno.css --watch"
  }
}
```

### 4. Use Classes in Templ

```templ
// components/button.templ
package components

templ Button(text string) {
    <button class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600">
        { text }
    </button>
}
```

### 5. Include CSS in Layout

```templ
// layouts/base.templ
package layouts

templ Base(title string) {
    <!DOCTYPE html>
    <html lang="en">
        <head>
            <meta charset="UTF-8"/>
            <title>{ title }</title>
            <link rel="stylesheet" href="/static/uno.css"/>
        </head>
        <body class="min-h-screen bg-gray-100">
            { children... }
        </body>
    </html>
}
```

### 6. Build Process

```bash
# Development (parallel)
templ generate --watch &
npm run css:watch &

# Production
templ generate
npm run css:build
go build -o app .
```

## Core Concepts

### UnoCSS Overview

UnoCSS is an atomic CSS engine that:
- Generates CSS on-demand from utility class usage
- Has no runtime overhead (build-time only)
- Supports multiple presets (Tailwind-compatible, icons, attributify)
- Extracts classes from any file type via CLI

### How Extraction Works

UnoCSS CLI scans files for utility class patterns and generates only the CSS needed:

```bash
# Scan specific patterns
unocss "components/**/*.templ" "pages/**/*.templ" -o static/uno.css

# With minification
unocss "**/*.templ" -o static/uno.css --minify
```

### Templ Integration

Templ files use standard CSS class syntax:

```templ
// Static classes
<div class="flex items-center gap-4">

// Dynamic classes (extracted if static)
<div class={ "p-4", templ.KV("bg-red-500", hasError) }>

// Conditional classes
if isActive {
    <span class="text-green-500">Active</span>
} else {
    <span class="text-gray-500">Inactive</span>
}
```

## CLI Commands

```bash
# Basic usage
unocss "**/*.templ" -o static/uno.css

# Watch mode for development
unocss "**/*.templ" -o static/uno.css --watch

# With preflights (reset styles)
unocss "**/*.templ" -o static/uno.css --preflights

# Minified output
unocss "**/*.templ" -o static/uno.css --minify

# Custom config file
unocss "**/*.templ" -o static/uno.css -c uno.config.ts
```

## Common Patterns

### Responsive Design

```templ
templ Card() {
    <div class="p-4 md:p-6 lg:p-8">
        <h2 class="text-lg md:text-xl lg:text-2xl">Title</h2>
    </div>
}
```

### Dark Mode

```templ
templ ThemeAwareCard() {
    <div class="bg-white dark:bg-gray-800 text-gray-900 dark:text-white">
        Content
    </div>
}
```

### State Variants

```templ
templ InteractiveButton() {
    <button class="bg-blue-500 hover:bg-blue-600 active:bg-blue-700 focus:ring-2">
        Click me
    </button>
}
```

### Grid Layout

```templ
templ ProductGrid(products []Product) {
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        for _, p := range products {
            @ProductCard(p)
        }
    </div>
}
```

## Safelist for Dynamic Classes

When classes are fully dynamic, use safelist:

```ts
// uno.config.ts
export default defineConfig({
  safelist: [
    // Always include these
    'bg-red-500', 'bg-green-500', 'bg-blue-500',
    // Generate ranges
    ...Array.from({ length: 5 }, (_, i) => `p-${i + 1}`),
  ],
})
```

## Reference Files

- **Configuration**: See [UNO-CONFIG.md](references/UNO-CONFIG.md)
- **Development workflow**: See [WORKFLOW.md](references/WORKFLOW.md)
- **Presets guide**: See [PRESETS.md](references/PRESETS.md)

## Project Structure

```
my-project/
├── components/
│   ├── button.templ
│   └── card.templ
├── layouts/
│   └── base.templ
├── pages/
│   └── home.templ
├── static/
│   └── uno.css          # Generated
├── uno.config.ts
├── package.json
├── go.mod
└── main.go
```

## Troubleshooting

### Classes Not Generated

1. Check file patterns in CLI command match your `.templ` files
2. Verify `content.filesystem` in config includes `.templ`
3. Use safelist for fully dynamic class names

### Classes Not Applied

1. Ensure CSS file is linked in HTML head
2. Check browser dev tools for CSS loading
3. Verify class names match UnoCSS syntax

### Watch Mode Issues

Run templ and UnoCSS watch in separate terminals or use a process manager:

```bash
# Using npm-run-all
npm install -D npm-run-all
```

```json
{
  "scripts": {
    "dev": "run-p dev:*",
    "dev:templ": "templ generate --watch",
    "dev:css": "unocss \"**/*.templ\" -o static/uno.css --watch",
    "dev:go": "go run ."
  }
}
```
