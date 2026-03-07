# Templ Syntax Reference

Complete syntax reference for templ components.

## File Structure

```templ
// filename.templ
package mypackage

import (
    "fmt"
    "strconv"
)

// Component definition
templ ComponentName(params...) {
    // HTML and templ expressions
}
```

## Component Definitions

### Basic Component

```templ
templ Hello() {
    <p>Hello, World!</p>
}
```

### Parameters

```templ
// Single parameter
templ Greeting(name string) {
    <p>Hello, { name }!</p>
}

// Multiple parameters
templ UserInfo(name string, age int, active bool) {
    <div>
        <span>{ name }</span>
        <span>{ strconv.Itoa(age) }</span>
        if active {
            <span class="active">Active</span>
        }
    </div>
}

// Struct parameter
templ UserCard(user User) {
    <div class="card">
        <h2>{ user.Name }</h2>
        <p>{ user.Email }</p>
    </div>
}

// Component parameter
templ Wrapper(content templ.Component) {
    <div class="wrapper">
        @content
    </div>
}
```

### Export Rules

```templ
// Exported (uppercase) - accessible from other packages
templ Button(text string) {
    <button>{ text }</button>
}

// Unexported (lowercase) - package-private
templ internalHelper() {
    <span>internal</span>
}
```

## Expressions

### Text Expressions

```templ
templ Example(name string, count int) {
    // String expression
    <p>{ name }</p>

    // Integer (must convert to string)
    <p>{ strconv.Itoa(count) }</p>

    // Formatted expression
    <p>{ fmt.Sprintf("Count: %d", count) }</p>
}
```

### Safe/Unsafe Content

```templ
templ Content(text string, html string) {
    // Auto-escaped (safe)
    <p>{ text }</p>

    // Raw HTML (dangerous - only use with trusted content)
    @templ.Raw(html)
}
```

## Control Flow

### If/Else

```templ
templ Conditional(show bool, level int) {
    if show {
        <div>Visible</div>
    }

    if level >= 90 {
        <span class="excellent">Excellent</span>
    } else if level >= 70 {
        <span class="good">Good</span>
    } else {
        <span class="poor">Poor</span>
    }
}
```

### For Loops

```templ
templ Loops(items []string) {
    <ul>
        for _, item := range items {
            <li>{ item }</li>
        }
    </ul>

    // With index
    for i, item := range items {
        <div data-index={ strconv.Itoa(i) }>{ item }</div>
    }
}
```

### Switch

```templ
templ Status(status string) {
    switch status {
        case "active":
            <span class="badge-success">Active</span>
        case "pending":
            <span class="badge-warning">Pending</span>
        default:
            <span class="badge-secondary">Unknown</span>
    }
}
```

## Component Composition

### Calling Components

```templ
templ Page() {
    @Header()
    @Button("Click me")
    @UserCard(User{Name: "John"})
}
```

### Children

```templ
templ Container() {
    <div class="container">
        { children... }
    </div>
}

templ Page() {
    @Container() {
        <h1>Title</h1>
        <p>Content</p>
    }
}
```

## Attributes

### Dynamic Attributes

```templ
templ Dynamic(id string, disabled bool) {
    <div id={ id }>Content</div>
    <button disabled?={ disabled }>Click</button>
}
```

### Spread Attributes

```templ
templ WithAttrs(attrs templ.Attributes) {
    <input { attrs... }/>
}
```
