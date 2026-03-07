# CSS Styling in Templ

Handle CSS styling with classes, inline styles, and CSS components.

## CSS Classes

### Static Classes

```templ
templ Card() {
    <div class="card shadow rounded">
        Content
    </div>
}
```

### Dynamic Classes

```templ
templ Button(primary bool, size string) {
    <button class={ "btn", "btn-" + size }>
        Click
    </button>
}
```

### Conditional Classes with templ.KV

```templ
templ Status(isActive bool, isDisabled bool) {
    <div class={
        "status",
        templ.KV("active", isActive),
        templ.KV("disabled", isDisabled),
    }>
        Status indicator
    </div>
}
```

### Conditional Classes with Map

```templ
templ Element(showBorder bool, highlight bool) {
    <div class={ map[string]bool{
        "base": true,
        "border": showBorder,
        "highlight": highlight,
    }}>
        Content
    </div>
}
```

### Using templ.Classes

```templ
templ Component(extra string) {
    <div class={ templ.Classes("base", "primary", extra) }>
        Content
    </div>
}
```

## Inline Styles

### Static Styles

```templ
templ Box() {
    <div style="padding: 1rem; margin: 0.5rem;">
        Content
    </div>
}
```

### Dynamic Styles

```templ
templ ColorBox(color string, width int) {
    <div style={ fmt.Sprintf("background-color: %s; width: %dpx;", color, width) }>
        Content
    </div>
}
```

### Safe CSS Values

```templ
templ SafeStyle(bgColor string) {
    <div style={ templ.SafeCSS(fmt.Sprintf("background: %s;", bgColor)) }>
        Content
    </div>
}
```

## CSS Components

Define reusable CSS blocks:

```templ
css button() {
    background-color: blue;
    color: white;
    padding: 0.5rem 1rem;
    border: none;
    border-radius: 4px;
}

templ Button(text string) {
    <button class={ button() }>{ text }</button>
}
```

### CSS Components with Parameters

```templ
css progressBar(percent int) {
    width: { fmt.Sprintf("%d%%", percent) };
    height: 20px;
    background-color: green;
}

templ Progress(value int) {
    <div class="progress-container">
        <div class={ progressBar(value) }></div>
    </div>
}
```

### Dynamic Colors

```templ
css coloredBox(color string) {
    background-color: { color };
    padding: 1rem;
}

templ ColoredCard(bgColor string) {
    <div class={ coloredBox(bgColor) }>
        Content
    </div>
}
```

## Combining Approaches

```templ
css card() {
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

templ ProductCard(featured bool, customBg string) {
    <div
        class={
            card(),
            "product-card",
            templ.KV("featured", featured),
        }
        style={ templ.SafeCSS(fmt.Sprintf("background: %s;", customBg)) }
    >
        { children... }
    </div>
}
```

## Style Tag

Include styles in the document:

```templ
templ Page() {
    <head>
        <style>
            .container {
                max-width: 1200px;
                margin: 0 auto;
            }
        </style>
    </head>
    <body>
        <div class="container">Content</div>
    </body>
}
```

## External Stylesheets

```templ
templ Head() {
    <head>
        <link rel="stylesheet" href="/static/styles.css"/>
        <link rel="stylesheet" href="https://cdn.example.com/lib.css"/>
    </head>
}
```

## Best Practices

1. **Use CSS components** for reusable styles
2. **Use templ.KV** for conditional classes
3. **Escape dynamic values** with templ.SafeCSS when needed
4. **Keep styles scoped** - CSS components generate unique class names
5. **Prefer classes over inline styles** for maintainability
