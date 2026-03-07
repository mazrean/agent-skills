# Lit Directives Reference

Complete reference for all built-in lit-html directives.

## List Directives

### repeat

Efficient list rendering with keys for optimal DOM reuse.

```typescript
import {repeat} from 'lit/directives/repeat.js';

interface Item {
  id: number;
  name: string;
}

@state() items: Item[] = [];

render() {
  return html`
    <ul>
      ${repeat(
        this.items,
        (item) => item.id,  // Key function
        (item, index) => html`<li>${index}: ${item.name}</li>`
      )}
    </ul>
  `;
}
```

**When to use:** Lists that reorder, add/remove items. Keys enable efficient DOM updates.

**Without key function:** Works but less efficient for reordering.

### map

Simple list transformation without keys.

```typescript
import {map} from 'lit/directives/map.js';

render() {
  return html`
    <ul>
      ${map(this.items, (item) => html`<li>${item.name}</li>`)}
    </ul>
  `;
}
```

**When to use:** Static lists or when key-based optimization isn't needed.

### range

Generate a sequence of numbers.

```typescript
import {range} from 'lit/directives/range.js';

render() {
  return html`
    <ul>
      ${map(range(5), (i) => html`<li>Item ${i}</li>`)}
    </ul>
  `;
}
// Renders: Item 0, Item 1, Item 2, Item 3, Item 4

// With start and step
${map(range(1, 10, 2), (i) => html`<li>${i}</li>`)}
// Renders: 1, 3, 5, 7, 9
```

### join

Join iterable values with a separator.

```typescript
import {join} from 'lit/directives/join.js';

render() {
  const items = ['Apple', 'Banana', 'Cherry'];
  return html`<p>${join(items, ', ')}</p>`;
}
// Renders: Apple, Banana, Cherry
```

## Conditional Directives

### when

If-else conditional rendering.

```typescript
import {when} from 'lit/directives/when.js';

render() {
  return html`
    ${when(
      this.isLoggedIn,
      () => html`<p>Welcome, ${this.username}!</p>`,
      () => html`<button @click=${this._login}>Login</button>`
    )}
  `;
}
```

### choose

Switch-case style rendering.

```typescript
import {choose} from 'lit/directives/choose.js';

type Status = 'loading' | 'success' | 'error';
@state() status: Status = 'loading';

render() {
  return html`
    ${choose(this.status, [
      ['loading', () => html`<spinner-element></spinner-element>`],
      ['success', () => html`<p>Data loaded!</p>`],
      ['error', () => html`<p class="error">Failed to load</p>`],
    ], () => html`<p>Unknown status</p>`)}
  `;
}
```

### ifDefined

Set attribute only if value is defined.

```typescript
import {ifDefined} from 'lit/directives/if-defined.js';

@property() imageUrl?: string;
@property() altText?: string;

render() {
  return html`
    <img src=${ifDefined(this.imageUrl)} alt=${ifDefined(this.altText)}>
  `;
}
// If imageUrl is undefined, no src attribute is set
```

### guard

Prevent re-renders when dependencies haven't changed.

```typescript
import {guard} from 'lit/directives/guard.js';

@property({type: Object}) expensiveData?: Data;
@property() unrelatedProp = '';

render() {
  return html`
    <!-- Only re-renders when expensiveData changes -->
    ${guard([this.expensiveData], () => html`
      <expensive-component .data=${this.expensiveData}></expensive-component>
    `)}
    <p>${this.unrelatedProp}</p>
  `;
}
```

## Caching Directives

### cache

Cache and reuse DOM for conditional content.

```typescript
import {cache} from 'lit/directives/cache.js';

@state() private _view: 'list' | 'detail' = 'list';

render() {
  return html`
    ${cache(this._view === 'list'
      ? html`<list-view .items=${this.items}></list-view>`
      : html`<detail-view .item=${this.selectedItem}></detail-view>`
    )}
  `;
}
```

**When to use:** Toggle between expensive views while preserving their state.

### keyed

Force re-render when key changes.

```typescript
import {keyed} from 'lit/directives/keyed.js';

@property() userId = '';

render() {
  return html`
    ${keyed(this.userId, html`
      <user-profile .userId=${this.userId}></user-profile>
    `)}
  `;
}
// Component completely re-creates when userId changes
```

## Async Directives

### until

Placeholder until Promise resolves.

```typescript
import {until} from 'lit/directives/until.js';

private _fetchData(): Promise<string> {
  return fetch('/api/data').then(r => r.text());
}

render() {
  return html`
    <div>
      ${until(
        this._fetchData(),
        html`<p>Loading...</p>`
      )}
    </div>
  `;
}
```

**Multiple fallbacks:** Later values take precedence as they resolve.

```typescript
${until(
  this._slowFetch(),
  this._fastFetch(),
  html`<p>Loading...</p>`
)}
```

### asyncAppend

Append values from async iterable as they arrive.

```typescript
import {asyncAppend} from 'lit/directives/async-append.js';

async function* streamData() {
  const response = await fetch('/api/stream');
  const reader = response.body!.getReader();
  while (true) {
    const {done, value} = await reader.read();
    if (done) break;
    yield new TextDecoder().decode(value);
  }
}

render() {
  return html`
    <div class="log">
      ${asyncAppend(streamData())}
    </div>
  `;
}
```

### asyncReplace

Replace content with each new value from async iterable.

```typescript
import {asyncReplace} from 'lit/directives/async-replace.js';

async function* countdown() {
  for (let i = 5; i >= 0; i--) {
    yield i;
    await new Promise(r => setTimeout(r, 1000));
  }
  yield 'Go!';
}

render() {
  return html`<p>${asyncReplace(countdown())}</p>`;
}
```

## DOM Reference Directives

### ref

Get reference to rendered element.

```typescript
import {ref, createRef, Ref} from 'lit/directives/ref.js';

private _inputRef: Ref<HTMLInputElement> = createRef();

render() {
  return html`
    <input ${ref(this._inputRef)} type="text">
    <button @click=${this._focus}>Focus</button>
  `;
}

private _focus() {
  this._inputRef.value?.focus();
}
```

**Callback ref:**

```typescript
render() {
  return html`
    <canvas ${ref(this._setupCanvas)}></canvas>
  `;
}

private _setupCanvas(canvas?: Element) {
  if (canvas) {
    // Canvas is connected
    this._ctx = (canvas as HTMLCanvasElement).getContext('2d');
  } else {
    // Canvas is disconnected
    this._ctx = undefined;
  }
}
```

### live

Sync with live DOM value (for form inputs).

```typescript
import {live} from 'lit/directives/live.js';

@state() private _value = '';

render() {
  return html`
    <input
      .value=${live(this._value)}
      @input=${(e: Event) => this._value = (e.target as HTMLInputElement).value}
    >
  `;
}
```

**When to use:**
- Input elements where user can type
- Custom elements that modify their own properties
- Any case where DOM value might change outside Lit

## Style Directives

### classMap

Dynamic class names from object.

```typescript
import {classMap} from 'lit/directives/class-map.js';

@property({type: Boolean}) active = false;
@property({type: Boolean}) disabled = false;

render() {
  const classes = {
    'btn': true,
    'btn--active': this.active,
    'btn--disabled': this.disabled,
  };
  return html`<button class=${classMap(classes)}>Click</button>`;
}
```

**With static classes:**

```typescript
html`<div class="static-class ${classMap(dynamicClasses)}"></div>`
```

### styleMap

Dynamic inline styles from object.

```typescript
import {styleMap} from 'lit/directives/style-map.js';

@property({type: String}) color = 'blue';
@property({type: Number}) size = 16;

render() {
  const styles = {
    color: this.color,
    fontSize: `${this.size}px`,
    'border-left': '2px solid currentColor',
  };
  return html`<p style=${styleMap(styles)}>Styled text</p>`;
}
```

## Content Directives

### unsafeHTML

Render raw HTML string (use with caution).

```typescript
import {unsafeHTML} from 'lit/directives/unsafe-html.js';

@property() htmlContent = '';

render() {
  // WARNING: Only use with trusted content!
  return html`<div>${unsafeHTML(this.htmlContent)}</div>`;
}
```

**Security:** Never use with user-provided content without sanitization.

### unsafeSVG

Render raw SVG string.

```typescript
import {unsafeSVG} from 'lit/directives/unsafe-svg.js';

@property() svgIcon = '';

render() {
  return html`
    <svg viewBox="0 0 24 24">
      ${unsafeSVG(this.svgIcon)}
    </svg>
  `;
}
```

### templateContent

Clone template element content.

```typescript
import {templateContent} from 'lit/directives/template-content.js';

render() {
  const template = document.getElementById('my-template') as HTMLTemplateElement;
  return html`<div>${templateContent(template)}</div>`;
}
```

## Creating Custom Directives

### Synchronous Directive

```typescript
import {Directive, directive, PartInfo, PartType} from 'lit/directive.js';

class HighlightDirective extends Directive {
  constructor(partInfo: PartInfo) {
    super(partInfo);
    if (partInfo.type !== PartType.ATTRIBUTE) {
      throw new Error('highlight must be used as attribute');
    }
  }

  render(color: string) {
    return `background-color: ${color}`;
  }
}

export const highlight = directive(HighlightDirective);

// Usage
html`<p style=${highlight('yellow')}>Highlighted</p>`
```

### Async Directive

```typescript
import {AsyncDirective, directive} from 'lit/async-directive.js';

class ResolvePromiseDirective extends AsyncDirective {
  render<T>(promise: Promise<T>, placeholder: unknown) {
    Promise.resolve(promise).then((value) => {
      this.setValue(value);
    });
    return placeholder;
  }
}

export const resolvePromise = directive(ResolvePromiseDirective);
```

### Stateful Directive

```typescript
import {Directive, directive, noChange} from 'lit/directive.js';

class CounterDirective extends Directive {
  private count = 0;

  render(increment: number) {
    this.count += increment;
    return this.count;
  }
}

export const counter = directive(CounterDirective);
```
