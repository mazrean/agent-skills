# Advanced Lit Features

Context API, Task, Reactive Controllers, Server-Side Rendering, and template compilation.

## Reactive Controllers

Reusable, lifecycle-aware logic that can be shared across components.

### Creating a Controller

```typescript
import {ReactiveController, ReactiveControllerHost} from 'lit';

export class ClockController implements ReactiveController {
  host: ReactiveControllerHost;
  value = new Date();
  private _intervalId?: number;

  constructor(host: ReactiveControllerHost) {
    this.host = host;
    host.addController(this);
  }

  hostConnected() {
    this._intervalId = window.setInterval(() => {
      this.value = new Date();
      this.host.requestUpdate();
    }, 1000);
  }

  hostDisconnected() {
    window.clearInterval(this._intervalId);
  }
}
```

### Using a Controller

```typescript
import {LitElement, html} from 'lit';
import {customElement} from 'lit/decorators.js';
import {ClockController} from './clock-controller.js';

@customElement('my-clock')
export class MyClock extends LitElement {
  private _clock = new ClockController(this);

  render() {
    return html`<p>Time: ${this._clock.value.toLocaleTimeString()}</p>`;
  }
}
```

### Controller with Options

```typescript
interface MouseControllerOptions {
  target?: EventTarget;
}

export class MouseController implements ReactiveController {
  host: ReactiveControllerHost;
  pos = {x: 0, y: 0};
  private _target: EventTarget;

  constructor(host: ReactiveControllerHost, options?: MouseControllerOptions) {
    this.host = host;
    this._target = options?.target ?? window;
    host.addController(this);
  }

  private _onMouseMove = (e: MouseEvent) => {
    this.pos = {x: e.clientX, y: e.clientY};
    this.host.requestUpdate();
  };

  hostConnected() {
    this._target.addEventListener('mousemove', this._onMouseMove);
  }

  hostDisconnected() {
    this._target.removeEventListener('mousemove', this._onMouseMove);
  }
}
```

## Context API (@lit/context)

Dependency injection through the DOM tree without prop drilling.

### Setup

```bash
npm install @lit/context
```

### Creating Context

```typescript
// logger-context.ts
import {createContext} from '@lit/context';

export interface Logger {
  log: (message: string) => void;
  error: (message: string) => void;
}

export const loggerContext = createContext<Logger>('logger');
```

### Providing Context

```typescript
import {LitElement, html} from 'lit';
import {customElement} from 'lit/decorators.js';
import {provide} from '@lit/context';
import {loggerContext, Logger} from './logger-context.js';

@customElement('app-root')
export class AppRoot extends LitElement {
  @provide({context: loggerContext})
  logger: Logger = {
    log: (msg) => console.log(`[APP] ${msg}`),
    error: (msg) => console.error(`[APP] ${msg}`),
  };

  render() {
    return html`<slot></slot>`;
  }
}
```

### Consuming Context

```typescript
import {LitElement, html} from 'lit';
import {customElement} from 'lit/decorators.js';
import {consume} from '@lit/context';
import {loggerContext, Logger} from './logger-context.js';

@customElement('my-component')
export class MyComponent extends LitElement {
  @consume({context: loggerContext})
  logger?: Logger;

  private _handleClick() {
    this.logger?.log('Button clicked');
  }

  render() {
    return html`<button @click=${this._handleClick}>Click Me</button>`;
  }
}
```

### Subscribing to Context Changes

```typescript
@customElement('my-component')
export class MyComponent extends LitElement {
  // Re-render when context value changes
  @consume({context: loggerContext, subscribe: true})
  @state()
  logger?: Logger;
}
```

### Using ContextProvider Controller

```typescript
import {ContextProvider} from '@lit/context';
import {loggerContext, Logger} from './logger-context.js';

@customElement('app-root')
export class AppRoot extends LitElement {
  private _loggerProvider = new ContextProvider(this, {
    context: loggerContext,
    initialValue: {
      log: (msg) => console.log(msg),
      error: (msg) => console.error(msg),
    },
  });

  updateLogger(newLogger: Logger) {
    this._loggerProvider.setValue(newLogger);
  }
}
```

## Task (@lit/task)

Reactive controller for managing async operations.

### Setup

```bash
npm install @lit/task
```

### Basic Usage

```typescript
import {LitElement, html} from 'lit';
import {customElement, property} from 'lit/decorators.js';
import {Task} from '@lit/task';

interface User {
  id: number;
  name: string;
  email: string;
}

@customElement('user-profile')
export class UserProfile extends LitElement {
  @property({type: Number}) userId?: number;

  private _userTask = new Task(this, {
    task: async ([userId]) => {
      if (!userId) throw new Error('No user ID');
      const response = await fetch(`/api/users/${userId}`);
      if (!response.ok) throw new Error('Failed to fetch');
      return response.json() as Promise<User>;
    },
    args: () => [this.userId],
  });

  render() {
    return this._userTask.render({
      pending: () => html`<p>Loading...</p>`,
      complete: (user) => html`
        <h2>${user.name}</h2>
        <p>${user.email}</p>
      `,
      error: (e) => html`<p class="error">Error: ${e.message}</p>`,
    });
  }
}
```

### Task with Initial Value

```typescript
private _dataTask = new Task(this, {
  task: async ([query]) => {
    const response = await fetch(`/api/search?q=${query}`);
    return response.json();
  },
  args: () => [this.searchQuery],
  initialValue: [],  // Show empty list initially
});
```

### Manual Task Execution

```typescript
private _submitTask = new Task(this, {
  task: async ([data]) => {
    const response = await fetch('/api/submit', {
      method: 'POST',
      body: JSON.stringify(data),
    });
    return response.json();
  },
  args: () => [this._formData],
  autoRun: false,  // Don't run automatically
});

private async _handleSubmit() {
  await this._submitTask.run();
}
```

### Task Status

```typescript
render() {
  const {status, value, error} = this._userTask;

  switch (status) {
    case TaskStatus.INITIAL:
      return html`<p>Enter a user ID</p>`;
    case TaskStatus.PENDING:
      return html`<spinner-element></spinner-element>`;
    case TaskStatus.COMPLETE:
      return html`<user-card .user=${value}></user-card>`;
    case TaskStatus.ERROR:
      return html`<error-message .error=${error}></error-message>`;
  }
}
```

## Server-Side Rendering (SSR)

Render Lit components on the server for improved initial load.

### Setup

```bash
npm install @lit-labs/ssr @lit-labs/ssr-client
```

### Server Rendering

```typescript
// server.ts
import {render} from '@lit-labs/ssr';
import {collectResult} from '@lit-labs/ssr/lib/render-result.js';
import {html} from 'lit';
import './my-element.js';  // Import component

const template = html`
  <my-element name="World"></my-element>
`;

const result = render(template);
const htmlString = await collectResult(result);

// Send htmlString to client
```

### Express Integration

```typescript
import express from 'express';
import {render} from '@lit-labs/ssr';
import {collectResult} from '@lit-labs/ssr/lib/render-result.js';
import {html} from 'lit';
import './components/my-app.js';

const app = express();

app.get('/', async (req, res) => {
  const ssrResult = render(html`<my-app></my-app>`);
  const content = await collectResult(ssrResult);

  res.send(`
    <!DOCTYPE html>
    <html>
      <head>
        <script type="module" src="/client.js"></script>
      </head>
      <body>
        ${content}
      </body>
    </html>
  `);
});
```

### Client Hydration

```typescript
// client.ts
import '@lit-labs/ssr-client/lit-element-hydrate-support.js';
import './components/my-app.js';  // Import components
```

### Declarative Shadow DOM

Lit SSR uses Declarative Shadow DOM (DSD):

```html
<!-- Server output -->
<my-element>
  <template shadowrootmode="open">
    <style>:host { display: block; }</style>
    <p>Hello, World!</p>
  </template>
</my-element>
```

### SSR-Safe Components

```typescript
@customElement('ssr-safe-element')
export class SsrSafeElement extends LitElement {
  // Check if running on server
  private _isServer = typeof window === 'undefined';

  connectedCallback() {
    super.connectedCallback();
    if (!this._isServer) {
      // Browser-only code
      this._setupBrowserFeatures();
    }
  }

  render() {
    return html`
      <div>
        ${this._isServer
          ? html`<p>Loading...</p>`
          : html`<interactive-widget></interactive-widget>`
        }
      </div>
    `;
  }
}
```

## Template Compilation (@lit-labs/compiler)

Pre-compile templates for faster first render.

### Setup

```bash
npm install -D @lit-labs/compiler
```

### Rollup Configuration

```javascript
// rollup.config.js
import typescript from '@rollup/plugin-typescript';
import {compileLitTemplates} from '@lit-labs/compiler';

export default {
  input: 'src/index.ts',
  output: {
    dir: 'dist',
    format: 'es',
  },
  plugins: [
    typescript({
      transformers: {
        before: [compileLitTemplates()],
      },
    }),
  ],
};
```

### Vite Configuration

```typescript
// vite.config.ts
import {defineConfig} from 'vite';
import {compileLitTemplates} from '@lit-labs/compiler';

export default defineConfig({
  esbuild: false,
  plugins: [
    {
      name: 'lit-compiler',
      transform(code, id) {
        if (id.endsWith('.ts') || id.endsWith('.js')) {
          // Apply lit compiler
        }
      },
    },
  ],
});
```

## Localization (@lit/localize)

Internationalization support for Lit applications.

### Setup

```bash
npm install @lit/localize
npm install -D @lit/localize-tools
```

### Marking Strings for Translation

```typescript
import {LitElement, html} from 'lit';
import {customElement} from 'lit/decorators.js';
import {msg, str} from '@lit/localize';

@customElement('greeting-element')
export class GreetingElement extends LitElement {
  @property() name = '';

  render() {
    return html`
      <h1>${msg('Welcome to our site')}</h1>
      <p>${msg(str`Hello, ${this.name}!`)}</p>
    `;
  }
}
```

### Configuration

```json
// lit-localize.json
{
  "sourceLocale": "en",
  "targetLocales": ["es", "ja"],
  "tsConfig": "./tsconfig.json",
  "output": {
    "mode": "runtime",
    "outputDir": "./src/generated/locales"
  },
  "interchange": {
    "format": "xliff",
    "xliffDir": "./xliff"
  }
}
```

### Switching Locales

```typescript
import {configureLocalization} from '@lit/localize';
import {sourceLocale, targetLocales} from './generated/locale-codes.js';

export const {getLocale, setLocale} = configureLocalization({
  sourceLocale,
  targetLocales,
  loadLocale: (locale) => import(`./generated/locales/${locale}.js`),
});

// Change locale
await setLocale('ja');
```

## Virtualizer (@lit-labs/virtualizer)

Efficiently render large lists by only rendering visible items.

### Setup

```bash
npm install @lit-labs/virtualizer
```

### Basic Usage

```typescript
import {LitElement, html, css} from 'lit';
import {customElement, state} from 'lit/decorators.js';
import {virtualize} from '@lit-labs/virtualizer/virtualize.js';

@customElement('virtual-list')
export class VirtualList extends LitElement {
  static styles = css`
    :host {
      display: block;
      height: 400px;
      overflow: auto;
    }
  `;

  @state() items = Array.from({length: 10000}, (_, i) => ({
    id: i,
    name: `Item ${i}`,
  }));

  render() {
    return html`
      ${virtualize({
        items: this.items,
        renderItem: (item) => html`
          <div class="item">${item.name}</div>
        `,
      })}
    `;
  }
}
```

### Grid Layout

```typescript
import {grid} from '@lit-labs/virtualizer/layouts/grid.js';

render() {
  return html`
    ${virtualize({
      items: this.items,
      renderItem: (item) => html`<item-card .item=${item}></item-card>`,
      layout: grid({
        itemSize: {width: '200px', height: '200px'},
        gap: '16px',
      }),
    })}
  `;
}
```

## Signals (@lit-labs/signals)

Reactive state management with signals (experimental).

### Setup

```bash
npm install @lit-labs/signals
```

### Using Signals

```typescript
import {LitElement, html} from 'lit';
import {customElement} from 'lit/decorators.js';
import {SignalWatcher} from '@lit-labs/signals';
import {signal, computed} from '@lit-labs/signals';

// Create signals
const count = signal(0);
const doubled = computed(() => count.get() * 2);

@customElement('signal-counter')
export class SignalCounter extends SignalWatcher(LitElement) {
  render() {
    return html`
      <p>Count: ${count.get()}</p>
      <p>Doubled: ${doubled.get()}</p>
      <button @click=${() => count.set(count.get() + 1)}>
        Increment
      </button>
    `;
  }
}
```

### Watch Directive

```typescript
import {watch} from '@lit-labs/signals';

render() {
  return html`
    <p>Count: ${watch(count)}</p>
  `;
}
```

## React Integration (@lit/react)

Use Lit components in React applications.

### Setup

```bash
npm install @lit/react
```

### Creating React Wrappers

```typescript
// my-element-react.ts
import {createComponent} from '@lit/react';
import React from 'react';
import {MyElement} from './my-element.js';

export const MyElementReact = createComponent({
  tagName: 'my-element',
  elementClass: MyElement,
  react: React,
  events: {
    onItemSelected: 'item-selected',
    onChange: 'change',
  },
});
```

### Using in React

```tsx
import {MyElementReact} from './my-element-react.js';

function App() {
  return (
    <MyElementReact
      name="World"
      count={42}
      onItemSelected={(e) => console.log(e.detail)}
    />
  );
}
```
