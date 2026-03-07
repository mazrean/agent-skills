---
name: building-lit-components
description: Builds fast, lightweight Web Components using Lit library. Use when creating Lit components, defining reactive properties, handling lifecycle, using directives, styling with Shadow DOM, implementing Context API, Task for async, or SSR with Lit.
---

# Building Lit Components

Lit is a lightweight (~5KB) library for building fast Web Components with reactive state, scoped styles, and declarative templates.

**Use this skill when** creating web components with Lit, optimizing rendering, implementing reactive properties, using directives, or building component libraries.

**Supporting files:** [COMPONENTS.md](references/COMPONENTS.md) for component patterns, [DIRECTIVES.md](references/DIRECTIVES.md) for built-in directives, [STYLING.md](references/STYLING.md) for styling best practices, [ADVANCED.md](references/ADVANCED.md) for Context, Task, SSR.

## Quick Start

```typescript
import {LitElement, html, css} from 'lit';
import {customElement, property} from 'lit/decorators.js';

@customElement('my-element')
export class MyElement extends LitElement {
  static styles = css`
    :host { display: block; }
    .greeting { color: blue; }
  `;

  @property() name = 'World';

  render() {
    return html`<p class="greeting">Hello, ${this.name}!</p>`;
  }
}
```

## Core Concepts

### Component Structure

| Part | Purpose |
|------|---------|
| `@customElement` | Register as custom element |
| `static styles` | Scoped CSS (Shadow DOM) |
| `@property()` | Reactive public property |
| `@state()` | Internal reactive state |
| `render()` | Return template |

### Reactive Properties

```typescript
// Public property (reflects to attribute)
@property({type: String, reflect: true})
name?: string;

// Internal state (no attribute)
@state()
private _count = 0;

// Complex objects
@property({type: Object, attribute: false})
data?: { id: number; name: string };
```

**Property Options:**
- `type`: Converter type (String, Number, Boolean, Array, Object)
- `reflect`: Sync to attribute (default: false)
- `attribute`: Custom attribute name or false
- `state`: Mark as internal state

### Lifecycle Methods

```typescript
class MyElement extends LitElement {
  // Called when added to DOM
  connectedCallback() {
    super.connectedCallback();
    // Add external event listeners
  }

  // Called before render when props change
  willUpdate(changedProperties: PropertyValues) {
    // Compute derived values
  }

  // Called after first render
  firstUpdated() {
    // DOM is available, focus inputs, etc.
  }

  // Called after every render
  updated(changedProperties: PropertyValues) {
    // React to specific prop changes
  }

  // Called when removed from DOM
  disconnectedCallback() {
    super.disconnectedCallback();
    // Clean up listeners
  }
}
```

### Templates & Events

```typescript
render() {
  return html`
    <!-- Property binding -->
    <input .value=${this.inputValue}>

    <!-- Attribute binding -->
    <div id=${this.elementId}></div>

    <!-- Boolean attribute -->
    <button ?disabled=${this.isDisabled}>Click</button>

    <!-- Event listener -->
    <button @click=${this._handleClick}>Submit</button>

    <!-- Event with options -->
    <div @scroll=${this._onScroll} @scroll=${(e) => this._onScroll(e)}></div>
  `;
}

private _handleClick(e: Event) {
  this.dispatchEvent(new CustomEvent('item-selected', {
    detail: { id: this.itemId },
    bubbles: true,
    composed: true
  }));
}
```

## Essential Decorators

| Decorator | Usage | Purpose |
|-----------|-------|---------|
| `@customElement('tag')` | Class | Register custom element |
| `@property()` | Field | Reactive public property |
| `@state()` | Field | Reactive internal state |
| `@query('#id')` | Field | Select single element |
| `@queryAll('.class')` | Field | Select all elements |
| `@eventOptions({...})` | Method | Event listener options |

```typescript
@customElement('my-element')
class MyElement extends LitElement {
  @property({type: Number}) count = 0;
  @state() private _active = false;

  @query('#input') input!: HTMLInputElement;
  @queryAll('.item') items!: NodeListOf<HTMLElement>;

  @eventOptions({passive: true})
  private _onScroll(e: Event) { /* ... */ }
}
```

## Common Directives

| Directive | Usage | Purpose |
|-----------|-------|---------|
| `repeat` | Lists | Efficient list rendering with keys |
| `map` | Lists | Simple list transformation |
| `when` | Conditional | If-else rendering |
| `classMap` | Classes | Dynamic class names |
| `styleMap` | Styles | Dynamic inline styles |
| `live` | Forms | Sync with live DOM value |
| `ref` | DOM | Get element reference |
| `until` | Async | Show placeholder until resolved |

```typescript
import {repeat} from 'lit/directives/repeat.js';
import {classMap} from 'lit/directives/class-map.js';
import {live} from 'lit/directives/live.js';

render() {
  return html`
    <!-- Efficient list -->
    ${repeat(this.items, (i) => i.id, (i) => html`<li>${i.name}</li>`)}

    <!-- Dynamic classes -->
    <div class=${classMap({active: this.isActive, error: this.hasError})}></div>

    <!-- Sync with user input -->
    <input .value=${live(this.inputValue)}>
  `;
}
```

## Key Best Practices

1. **Keep render() pure**: Don't modify state in render
2. **Use @state for internal data**: Prevents attribute exposure
3. **Prefer property over attribute for objects**: `attribute: false`
4. **Use live() for form inputs**: Keeps DOM in sync
5. **Clean up in disconnectedCallback**: Remove external listeners
6. **Use CSS custom properties for theming**: Enables external customization

## Common Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Modify props in render() | Infinite loops | Use willUpdate() |
| Dynamic tag names | Performance issues | Use static tags |
| Objects as attributes | Serialization overhead | Use `attribute: false` |
| Skip `super.connectedCallback()` | Breaks lifecycle | Always call super |
| DOM manipulation outside render | State desync | Use template bindings |

## Detailed Guides

- **Component patterns & composition**: See [COMPONENTS.md](references/COMPONENTS.md)
- **All built-in directives**: See [DIRECTIVES.md](references/DIRECTIVES.md)
- **Styling & theming**: See [STYLING.md](references/STYLING.md)
- **Context, Task, SSR, Controllers**: See [ADVANCED.md](references/ADVANCED.md)

## Resources

- Documentation: https://lit.dev/docs/
- Playground: https://lit.dev/playground/
- GitHub: https://github.com/lit/lit
