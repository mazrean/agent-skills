# Development Workflow

Build processes and development workflows for UnoCSS with templ.

## Development Setup

### Prerequisites

```bash
# Go 1.21+
go version

# Node.js 18+
node --version

# Install tools
go install github.com/a-h/templ/cmd/templ@latest
npm install -D unocss @unocss/cli
```

## Build Commands

### Templ Generation

```bash
templ generate           # One-time
templ generate --watch   # Watch mode
templ fmt .              # Format files
```

### UnoCSS Generation

```bash
# Basic
npx unocss "**/*.templ" -o static/uno.css

# With preflights
npx unocss "**/*.templ" -o static/uno.css --preflights

# Production (minified)
npx unocss "**/*.templ" -o static/uno.css --minify

# Watch mode
npx unocss "**/*.templ" -o static/uno.css --watch
```

## Package.json Scripts

### With npm-run-all

```json
{
  "scripts": {
    "dev": "run-p dev:*",
    "dev:templ": "templ generate --watch",
    "dev:css": "unocss \"**/*.templ\" -o static/uno.css --watch",

    "build": "run-s build:*",
    "build:templ": "templ generate",
    "build:css": "unocss \"**/*.templ\" -o static/uno.css --minify"
  }
}
```

## Makefile Alternative

```makefile
.PHONY: dev build

dev:
	templ generate --watch &
	npx unocss "**/*.templ" -o static/uno.css --watch &
	go run .

build:
	templ generate
	npx unocss "**/*.templ" -o static/uno.css --minify
	go build -o app .
```

## Air for Hot Reload

```toml
# .air.toml
[build]
cmd = "templ generate && go build -o ./tmp/main ."
bin = "./tmp/main"
include_ext = ["go", "templ"]
```

## Static Site Generation

```go
// build.go
func main() {
    pages := map[string]templ.Component{
        "index.html": HomePage(),
        "about.html": AboutPage(),
    }

    os.MkdirAll("dist", 0755)
    for name, page := range pages {
        f, _ := os.Create(filepath.Join("dist", name))
        page.Render(context.Background(), f)
        f.Close()
    }
}
```

## Build Order

1. `templ generate` - Generate Go code
2. `unocss` - Extract CSS from `.templ` files
3. `go build` - Compile Go application
