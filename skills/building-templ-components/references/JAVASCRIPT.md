# JavaScript Integration in Templ

Handle JavaScript with script templates, event handlers, and integration patterns.

## Script Templates

Define reusable JavaScript functions:

```templ
script showAlert(message string) {
    alert(message);
}

script logValue(key string, value string) {
    console.log(key + ": " + value);
}

templ Button() {
    <button onclick={ showAlert("Hello!") }>
        Click me
    </button>
}
```

### Scripts with Parameters

```templ
script submitForm(formId string, endpoint string) {
    const form = document.getElementById(formId);
    fetch(endpoint, {
        method: 'POST',
        body: new FormData(form)
    });
}

templ Form() {
    <form id="myForm">
        <input type="text" name="name"/>
        <button type="button" onclick={ submitForm("myForm", "/api/submit") }>
            Submit
        </button>
    </form>
}
```

### Scripts with Multiple Parameters

```templ
script updateElement(id string, content string, className string) {
    const el = document.getElementById(id);
    el.textContent = content;
    el.className = className;
}

templ Interactive() {
    <div id="target">Initial</div>
    <button onclick={ updateElement("target", "Updated!", "highlight") }>
        Update
    </button>
}
```

## Event Handlers

### Standard Events

```templ
script handleClick() {
    console.log("Clicked!");
}

script handleHover() {
    console.log("Hovered!");
}

templ InteractiveElement() {
    <button
        onclick={ handleClick() }
        onmouseover={ handleHover() }
    >
        Interact
    </button>
}
```

### Form Events

```templ
script handleSubmit(e) {
    e.preventDefault();
    console.log("Form submitted");
}

script handleInput(fieldName string) {
    console.log(fieldName + " changed");
}

templ Form() {
    <form onsubmit={ handleSubmit() }>
        <input
            type="text"
            name="email"
            oninput={ handleInput("email") }
        />
        <button type="submit">Submit</button>
    </form>
}
```

## Using templ.JSExpression

Access browser objects like `event`:

```templ
script handleClickWithEvent(e) {
    console.log("Target:", e.target);
    console.log("Type:", e.type);
}

templ Button() {
    <button onclick={ handleClickWithEvent(templ.JSExpression("event")) }>
        Click
    </button>
}
```

## HTMX Integration

```templ
script handleSwap() {
    console.log("Content swapped");
}

templ HtmxButton() {
    <button
        hx-get="/api/data"
        hx-target="#result"
        hx-trigger="click"
        hx-on::after-swap={ handleSwap() }
    >
        Load Data
    </button>
    <div id="result"></div>
}
```

### HTMX with hx-on

```templ
script onBeforeRequest() {
    console.log("Request starting");
}

script onAfterRequest() {
    console.log("Request completed");
}

templ HtmxForm() {
    <form
        hx-post="/api/submit"
        hx-on::before-request={ onBeforeRequest() }
        hx-on::after-request={ onAfterRequest() }
    >
        <input type="text" name="data"/>
        <button type="submit">Submit</button>
    </form>
}
```

## External Scripts

```templ
templ Head() {
    <head>
        <script src="/static/app.js"></script>
        <script src="https://unpkg.com/htmx.org@1.9.10"></script>
    </head>
}
```

### Script with onload

```templ
script initLibrary() {
    console.log("Library loaded");
}

templ ExternalScript() {
    <script
        src="https://cdn.example.com/lib.js"
        onload={ initLibrary() }
    ></script>
}
```

## Inline Script Blocks

```templ
templ PageWithScript() {
    <body>
        <div id="app"></div>
        <script>
            document.getElementById('app').textContent = 'Loaded';
        </script>
    </body>
}
```

## CSP Nonce Support

For Content Security Policy compliance:

```go
func handler(w http.ResponseWriter, r *http.Request) {
    nonce := generateNonce()
    ctx := templ.WithNonce(r.Context(), nonce)

    w.Header().Set("Content-Security-Policy",
        fmt.Sprintf("script-src 'nonce-%s'", nonce))

    Page().Render(ctx, w)
}
```

## Script Deduplication

Templ automatically deduplicates scripts:

```templ
script counter() {
    let count = 0;
    window.increment = () => count++;
}

templ MultipleButtons() {
    // Script is only included once in output
    <button onclick={ counter() }>Button 1</button>
    <button onclick={ counter() }>Button 2</button>
    <button onclick={ counter() }>Button 3</button>
}
```

## Best Practices

1. **Use script templates** for reusable JavaScript
2. **Pass parameters** to scripts for dynamic behavior
3. **Use templ.JSExpression** for browser objects
4. **Leverage HTMX** for server-driven interactions
5. **Scripts are deduplicated** - define once, use many times
6. **Set CSP nonces** for security in production
