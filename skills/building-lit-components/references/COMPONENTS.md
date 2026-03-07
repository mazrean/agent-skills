# Lit Component Patterns

Detailed patterns for building well-structured Lit components.

## Component Definition

### TypeScript with Decorators (Recommended)

```typescript
import {LitElement, html, css, PropertyValues} from 'lit';
import {customElement, property, state, query} from 'lit/decorators.js';

@customElement('user-card')
export class UserCard extends LitElement {
  static styles = css`
    :host {
      display: block;
      border: 1px solid #ccc;
      padding: 16px;
      border-radius: 8px;
    }
    .name { font-weight: bold; }
    .email { color: #666; }
  `;

  @property({type: String}) name = '';
  @property({type: String}) email = '';
  @state() private _expanded = false;

  @query('.details') private _details!: HTMLElement;

  render() {
    return html`
      <div class="name">${this.name}</div>
      <div class="email">${this.email}</div>
      <button @click=${this._toggle}>
        ${this._expanded ? 'Hide' : 'Show'} Details
      </button>
      <div class="details" ?hidden=${!this._expanded}>
        <slot></slot>
      </div>
    `;
  }

  private _toggle() {
    this._expanded = !this._expanded;
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'user-card': UserCard;
  }
}
```

### JavaScript (No Decorators)

```javascript
import {LitElement, html, css} from 'lit';

export class UserCard extends LitElement {
  static properties = {
    name: {type: String},
    email: {type: String},
    _expanded: {type: Boolean, state: true},
  };

  static styles = css`
    :host { display: block; }
  `;

  constructor() {
    super();
    this.name = '';
    this.email = '';
    this._expanded = false;
  }

  render() {
    return html`
      <div>${this.name}</div>
      <div>${this.email}</div>
    `;
  }
}
customElements.define('user-card', UserCard);
```

## Property Patterns

### Property Type Conversion

```typescript
// String (default)
@property() name?: string;

// Number
@property({type: Number}) count = 0;

// Boolean - presence of attribute = true
@property({type: Boolean}) disabled = false;

// Array/Object - use attribute: false for complex data
@property({type: Array, attribute: false})
items: Item[] = [];

@property({type: Object, attribute: false})
config?: Config;
```

### Custom Converter

```typescript
@property({
  converter: {
    fromAttribute: (value: string | null): Date | null => {
      return value ? new Date(value) : null;
    },
    toAttribute: (value: Date | null): string | null => {
      return value?.toISOString() ?? null;
    }
  },
  reflect: true
})
date?: Date;
```

### Property Change Detection

```typescript
@property({
  hasChanged: (newVal: string, oldVal: string) => {
    // Case-insensitive comparison
    return newVal?.toLowerCase() !== oldVal?.toLowerCase();
  }
})
searchTerm = '';
```

### Derived State with willUpdate

```typescript
@property({type: Array}) items: Item[] = [];
@state() private _filteredItems: Item[] = [];
@state() private _totalCount = 0;

willUpdate(changedProperties: PropertyValues<this>) {
  if (changedProperties.has('items')) {
    this._filteredItems = this.items.filter(i => i.active);
    this._totalCount = this._filteredItems.length;
  }
}
```

## Lifecycle Patterns

### Resource Management

```typescript
@customElement('data-viewer')
export class DataViewer extends LitElement {
  private _resizeObserver?: ResizeObserver;
  private _abortController?: AbortController;

  connectedCallback() {
    super.connectedCallback();

    // Setup resize observer
    this._resizeObserver = new ResizeObserver(this._onResize);
    this._resizeObserver.observe(this);

    // Setup abort controller for fetch
    this._abortController = new AbortController();
  }

  disconnectedCallback() {
    super.disconnectedCallback();

    // Cleanup observers
    this._resizeObserver?.disconnect();

    // Cancel pending requests
    this._abortController?.abort();
  }

  private _onResize = (entries: ResizeObserverEntry[]) => {
    // Handle resize
  };
}
```

### First Render Actions

```typescript
firstUpdated() {
  // Focus input after first render
  this._inputRef.value?.focus();

  // Initialize third-party libraries
  this._chart = new Chart(this._canvasRef.value!, {/* ... */});
}
```

### Async Update Handling

```typescript
async performUpdate() {
  // Wait for data before rendering
  await this._dataPromise;
  super.performUpdate();
}

// Or use updateComplete in consumers
async someMethod() {
  this.someProperty = newValue;
  await this.updateComplete;
  // DOM is now updated
}
```

## Composition Patterns

### Slots

```typescript
// Default slot
render() {
  return html`
    <div class="card">
      <slot></slot>
    </div>
  `;
}

// Named slots
render() {
  return html`
    <header><slot name="header"></slot></header>
    <main><slot></slot></main>
    <footer><slot name="footer"></slot></footer>
  `;
}

// Usage
html`
  <my-card>
    <span slot="header">Title</span>
    <p>Content goes in default slot</p>
    <button slot="footer">Action</button>
  </my-card>
`;
```

### Slot Change Detection

```typescript
render() {
  return html`
    <slot @slotchange=${this._onSlotChange}></slot>
  `;
}

private _onSlotChange(e: Event) {
  const slot = e.target as HTMLSlotElement;
  const assignedNodes = slot.assignedNodes({flatten: true});
  console.log('Slot content changed:', assignedNodes);
}
```

### Component Composition

```typescript
// Container component
@customElement('user-list')
export class UserList extends LitElement {
  @property({type: Array}) users: User[] = [];

  render() {
    return html`
      <ul>
        ${this.users.map(user => html`
          <li>
            <user-card
              .name=${user.name}
              .email=${user.email}
              @user-selected=${this._onUserSelected}
            ></user-card>
          </li>
        `)}
      </ul>
    `;
  }

  private _onUserSelected(e: CustomEvent<{userId: string}>) {
    // Handle child event
  }
}
```

## Event Patterns

### Custom Events

```typescript
// Define event types
export interface UserSelectedEvent {
  userId: string;
  userName: string;
}

// Dispatch typed event
private _selectUser(user: User) {
  this.dispatchEvent(new CustomEvent<UserSelectedEvent>('user-selected', {
    detail: {
      userId: user.id,
      userName: user.name,
    },
    bubbles: true,
    composed: true,  // Cross shadow DOM boundary
  }));
}

// Listen in parent
html`<user-card @user-selected=${this._onUserSelected}></user-card>`;

private _onUserSelected(e: CustomEvent<UserSelectedEvent>) {
  console.log(e.detail.userId);
}
```

### Event Delegation

```typescript
render() {
  return html`
    <ul @click=${this._handleListClick}>
      ${this.items.map(item => html`
        <li data-id=${item.id}>${item.name}</li>
      `)}
    </ul>
  `;
}

private _handleListClick(e: Event) {
  const target = e.target as HTMLElement;
  const li = target.closest('li');
  if (li) {
    const id = li.dataset.id;
    // Handle click on item with id
  }
}
```

## Form Patterns

### Controlled Input

```typescript
@state() private _value = '';

render() {
  return html`
    <input
      .value=${live(this._value)}
      @input=${this._onInput}
    >
  `;
}

private _onInput(e: Event) {
  this._value = (e.target as HTMLInputElement).value;
}
```

### Form Submission

```typescript
render() {
  return html`
    <form @submit=${this._onSubmit}>
      <input name="email" type="email" required>
      <input name="password" type="password" required>
      <button type="submit">Login</button>
    </form>
  `;
}

private _onSubmit(e: Event) {
  e.preventDefault();
  const form = e.target as HTMLFormElement;
  const data = new FormData(form);

  this.dispatchEvent(new CustomEvent('login-submit', {
    detail: Object.fromEntries(data),
    bubbles: true,
  }));
}
```

## Testing Patterns

### Basic Test Setup

```typescript
import {fixture, html, expect} from '@open-wc/testing';
import './user-card.js';
import type {UserCard} from './user-card.js';

describe('UserCard', () => {
  it('renders name and email', async () => {
    const el = await fixture<UserCard>(html`
      <user-card name="John" email="john@example.com"></user-card>
    `);

    expect(el.name).to.equal('John');
    expect(el.shadowRoot!.querySelector('.name')!.textContent)
      .to.equal('John');
  });

  it('dispatches event on click', async () => {
    const el = await fixture<UserCard>(html`<user-card></user-card>`);

    let eventFired = false;
    el.addEventListener('user-selected', () => eventFired = true);

    el.shadowRoot!.querySelector('button')!.click();
    expect(eventFired).to.be.true;
  });
});
```

### Waiting for Updates

```typescript
it('updates after property change', async () => {
  const el = await fixture<UserCard>(html`<user-card></user-card>`);

  el.name = 'Jane';
  await el.updateComplete;

  expect(el.shadowRoot!.querySelector('.name')!.textContent)
    .to.equal('Jane');
});
```
