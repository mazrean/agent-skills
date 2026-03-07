# Styling Lit Components

Best practices for styling Lit components with Shadow DOM, CSS custom properties, and theming patterns.

## Static Styles

### Basic Usage

```typescript
import {LitElement, html, css} from 'lit';
import {customElement} from 'lit/decorators.js';

@customElement('my-element')
export class MyElement extends LitElement {
  static styles = css`
    :host {
      display: block;
      padding: 16px;
    }

    .title {
      font-size: 1.5rem;
      font-weight: bold;
    }

    .content {
      margin-top: 8px;
    }
  `;

  render() {
    return html`
      <h1 class="title">Title</h1>
      <div class="content"><slot></slot></div>
    `;
  }
}
```

### Multiple Style Sheets

```typescript
// Shared styles
const sharedStyles = css`
  .btn {
    padding: 8px 16px;
    border-radius: 4px;
    cursor: pointer;
  }
`;

@customElement('my-element')
export class MyElement extends LitElement {
  static styles = [
    sharedStyles,
    css`
      :host { display: block; }
      .btn { background: blue; color: white; }
    `
  ];
}
```

### Importing External CSS

```typescript
import {css, unsafeCSS} from 'lit';
import resetStyles from './reset.css?inline';

@customElement('my-element')
export class MyElement extends LitElement {
  static styles = [
    unsafeCSS(resetStyles),
    css`/* component styles */`
  ];
}
```

## Host Element Styling

### :host Selector

```css
/* Default host styles */
:host {
  display: block;
  box-sizing: border-box;
}

/* Host with specific attribute */
:host([hidden]) {
  display: none;
}

/* Host with specific class */
:host(.highlighted) {
  background-color: yellow;
}

/* Host based on context */
:host-context(.dark-theme) {
  background: #333;
  color: white;
}
```

### Display Behavior

```css
/* Block-level component */
:host {
  display: block;
}

/* Inline component */
:host {
  display: inline-block;
}

/* Flex container */
:host {
  display: flex;
  flex-direction: column;
}

/* Grid container */
:host {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}
```

## CSS Custom Properties (Design Tokens)

### Defining Custom Properties

```typescript
@customElement('themed-button')
export class ThemedButton extends LitElement {
  static styles = css`
    :host {
      /* Define defaults */
      --button-bg: var(--theme-primary, #007bff);
      --button-color: var(--theme-on-primary, white);
      --button-radius: var(--theme-radius, 4px);
      --button-padding: 8px 16px;
    }

    button {
      background: var(--button-bg);
      color: var(--button-color);
      border-radius: var(--button-radius);
      padding: var(--button-padding);
      border: none;
      cursor: pointer;
    }

    button:hover {
      filter: brightness(1.1);
    }
  `;

  render() {
    return html`<button><slot></slot></button>`;
  }
}
```

### Consuming from Outside

```html
<!-- Global theme -->
<style>
  :root {
    --theme-primary: #6200ee;
    --theme-on-primary: white;
    --theme-radius: 8px;
  }
</style>

<!-- Instance override -->
<themed-button style="--button-bg: green;"></themed-button>
```

### Design Token Pattern

```typescript
// tokens.ts
export const tokens = css`
  :host {
    /* Colors */
    --color-primary: #007bff;
    --color-secondary: #6c757d;
    --color-success: #28a745;
    --color-danger: #dc3545;
    --color-warning: #ffc107;

    /* Typography */
    --font-family: system-ui, sans-serif;
    --font-size-sm: 0.875rem;
    --font-size-md: 1rem;
    --font-size-lg: 1.25rem;

    /* Spacing */
    --space-xs: 4px;
    --space-sm: 8px;
    --space-md: 16px;
    --space-lg: 24px;
    --space-xl: 32px;

    /* Borders */
    --radius-sm: 2px;
    --radius-md: 4px;
    --radius-lg: 8px;
    --radius-full: 9999px;

    /* Shadows */
    --shadow-sm: 0 1px 2px rgba(0,0,0,0.1);
    --shadow-md: 0 4px 6px rgba(0,0,0,0.1);
    --shadow-lg: 0 10px 15px rgba(0,0,0,0.1);
  }
`;

// Usage
@customElement('my-card')
export class MyCard extends LitElement {
  static styles = [
    tokens,
    css`
      :host {
        display: block;
        padding: var(--space-md);
        border-radius: var(--radius-md);
        box-shadow: var(--shadow-md);
      }
    `
  ];
}
```

## CSS Parts

### Exposing Parts

```typescript
@customElement('fancy-card')
export class FancyCard extends LitElement {
  static styles = css`
    .header { padding: 16px; }
    .content { padding: 16px; }
    .footer { padding: 16px; border-top: 1px solid #eee; }
  `;

  render() {
    return html`
      <div class="header" part="header">
        <slot name="header"></slot>
      </div>
      <div class="content" part="content">
        <slot></slot>
      </div>
      <div class="footer" part="footer">
        <slot name="footer"></slot>
      </div>
    `;
  }
}
```

### Styling from Outside

```css
fancy-card::part(header) {
  background: linear-gradient(to right, #667eea, #764ba2);
  color: white;
}

fancy-card::part(content) {
  min-height: 200px;
}

fancy-card::part(footer) {
  background: #f8f9fa;
}
```

### Forwarding Parts

```typescript
// Inner component
@customElement('inner-element')
export class InnerElement extends LitElement {
  render() {
    return html`<button part="button"><slot></slot></button>`;
  }
}

// Outer component - forward inner parts
@customElement('outer-element')
export class OuterElement extends LitElement {
  render() {
    return html`
      <inner-element exportparts="button: inner-button">
        <slot></slot>
      </inner-element>
    `;
  }
}

// Style from outside
// outer-element::part(inner-button) { ... }
```

## Slotted Content Styling

### ::slotted Selector

```css
/* Style direct children in slots */
::slotted(*) {
  margin: 8px 0;
}

/* Style specific elements */
::slotted(p) {
  line-height: 1.6;
}

/* Style named slots */
::slotted([slot="header"]) {
  font-weight: bold;
}

/* Combine with class (limited) */
::slotted(.highlight) {
  background: yellow;
}
```

**Limitation:** `::slotted` only selects direct children, not deeper descendants.

## Theming Patterns

### Light/Dark Theme

```typescript
@customElement('themeable-component')
export class ThemeableComponent extends LitElement {
  static styles = css`
    :host {
      /* Light theme (default) */
      --bg-color: white;
      --text-color: #333;
      --border-color: #ddd;
    }

    :host([theme="dark"]) {
      --bg-color: #1a1a1a;
      --text-color: #eee;
      --border-color: #444;
    }

    /* Or use media query */
    @media (prefers-color-scheme: dark) {
      :host(:not([theme="light"])) {
        --bg-color: #1a1a1a;
        --text-color: #eee;
        --border-color: #444;
      }
    }

    .container {
      background: var(--bg-color);
      color: var(--text-color);
      border: 1px solid var(--border-color);
    }
  `;

  @property() theme?: 'light' | 'dark';

  render() {
    return html`<div class="container"><slot></slot></div>`;
  }
}
```

### Theme Provider Pattern

```typescript
// theme-provider.ts
@customElement('theme-provider')
export class ThemeProvider extends LitElement {
  static styles = css`
    :host {
      display: contents;
    }

    :host([theme="brand"]) {
      --theme-primary: #6200ee;
      --theme-secondary: #03dac6;
    }

    :host([theme="ocean"]) {
      --theme-primary: #0077b6;
      --theme-secondary: #00b4d8;
    }
  `;

  @property() theme: 'brand' | 'ocean' = 'brand';

  render() {
    return html`<slot></slot>`;
  }
}

// Usage
html`
  <theme-provider theme="ocean">
    <my-app></my-app>
  </theme-provider>
`;
```

## Responsive Design

### Media Queries

```css
:host {
  display: block;
  padding: 16px;
}

@media (min-width: 768px) {
  :host {
    padding: 24px;
  }
}

@media (min-width: 1024px) {
  :host {
    padding: 32px;
    max-width: 1200px;
    margin: 0 auto;
  }
}
```

### Container Queries

```css
:host {
  container-type: inline-size;
}

.grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 16px;
}

@container (min-width: 400px) {
  .grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@container (min-width: 600px) {
  .grid {
    grid-template-columns: repeat(3, 1fr);
  }
}
```

## Dynamic Styles

### Using styleMap

```typescript
import {styleMap} from 'lit/directives/style-map.js';

@property({type: Number}) progress = 0;
@property({type: String}) color = 'blue';

render() {
  const progressStyles = {
    width: `${this.progress}%`,
    backgroundColor: this.color,
    height: '4px',
    transition: 'width 0.3s ease',
  };

  return html`
    <div class="progress-bar">
      <div class="progress" style=${styleMap(progressStyles)}></div>
    </div>
  `;
}
```

### Using classMap

```typescript
import {classMap} from 'lit/directives/class-map.js';

@property({type: Boolean}) primary = false;
@property({type: Boolean}) disabled = false;
@property({type: String}) size: 'sm' | 'md' | 'lg' = 'md';

render() {
  const classes = {
    btn: true,
    'btn--primary': this.primary,
    'btn--disabled': this.disabled,
    [`btn--${this.size}`]: true,
  };

  return html`<button class=${classMap(classes)}><slot></slot></button>`;
}
```

## Animation

### CSS Animations

```css
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(-10px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes pulse {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.05); }
}

.card {
  animation: fadeIn 0.3s ease-out;
}

.notification {
  animation: pulse 2s infinite;
}
```

### Transitions

```css
.btn {
  background: var(--btn-bg);
  transform: scale(1);
  transition:
    background 0.2s ease,
    transform 0.1s ease,
    box-shadow 0.2s ease;
}

.btn:hover {
  background: var(--btn-bg-hover);
  transform: scale(1.02);
  box-shadow: var(--shadow-md);
}

.btn:active {
  transform: scale(0.98);
}
```

## Best Practices

### Do

- Use `:host` for component-level styling
- Define CSS custom properties with sensible defaults
- Use `display: block` or appropriate display value on `:host`
- Expose parts for customization hooks
- Use design tokens for consistency
- Keep styles scoped and modular

### Don't

- Don't use `!important` (breaks customization)
- Don't style outside Shadow DOM boundary
- Don't rely on global styles leaking in
- Don't use overly specific selectors
- Don't forget `:host([hidden]) { display: none; }`
