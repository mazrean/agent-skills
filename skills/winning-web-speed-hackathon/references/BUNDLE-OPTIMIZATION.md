# Bundle Optimization

## Webpack Production Config

```js
// webpack.config.js — essential production settings
module.exports = {
  mode: 'production',
  devtool: false, // NO source maps in production
  optimization: {
    minimize: true,
    splitChunks: {
      chunks: 'all',
      cacheGroups: {
        vendor: {
          test: /[\\/]node_modules[\\/]/,
          name: 'vendor',
          chunks: 'all',
        },
      },
    },
  },
  module: {
    rules: [
      {
        test: /\.[jt]sx?$/,
        exclude: /node_modules/, // CRITICAL: don't transpile node_modules
        use: 'babel-loader',
      },
    ],
  },
};
```

## Browserslist

Create `.browserslistrc`:
```
last 1 Chrome version
```

This eliminates unnecessary polyfills and transpilation for the Lighthouse Chrome environment.

## Babel Config — Remove Tree Shaking Killers

```diff
// babel.config.js
 {
   "presets": ["@babel/preset-env", "@babel/preset-react"],
   "plugins": [
-    "@babel/plugin-transform-modules-commonjs"  // REMOVE THIS
   ]
 }
```

## Route-Based Code Splitting

```tsx
import { lazy, Suspense } from 'react';

const HomePage = lazy(() => import('./pages/HomePage'));
const DetailPage = lazy(() => import('./pages/DetailPage'));

function App() {
  return (
    <Suspense fallback={null}>
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/detail/:id" element={<DetailPage />} />
      </Routes>
    </Suspense>
  );
}
```

## Preact Migration (Drop-in)

```bash
pnpm add preact
```

Webpack aliases:
```js
resolve: {
  alias: {
    'react': 'preact/compat',
    'react-dom': 'preact/compat',
    'react/jsx-runtime': 'preact/jsx-runtime',
  },
}
```

~3KB vs ~40KB for React + ReactDOM.

## Dependency Replacement Patterns

### lodash → native
```js
// Before
import _ from 'lodash';
_.get(obj, 'a.b.c');
_.debounce(fn, 300);
_.uniqBy(arr, 'id');

// After
obj?.a?.b?.c;
// debounce: inline 5-line implementation or import from lodash-es
import { debounce } from 'lodash-es'; // tree-shakeable
[...new Map(arr.map(item => [item.id, item])).values()];
```

### moment-timezone → dayjs
```js
// Before
import moment from 'moment-timezone';
moment(date).tz('Asia/Tokyo').format('YYYY-MM-DD');

// After
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
dayjs.extend(utc);
dayjs.extend(timezone);
dayjs(date).tz('Asia/Tokyo').format('YYYY-MM-DD');
```

### axios → fetch
```js
// Before
const { data } = await axios.get('/api/items');

// After
const data = await fetch('/api/items').then(r => r.json());
```

## Bundle Analysis

### Webpack
```bash
# Add to webpack config:
# const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer');
# plugins: [new BundleAnalyzerPlugin()]

# Or generate stats:
npx webpack --json > stats.json
npx webpack-bundle-analyzer stats.json
```

### Vite
```bash
npx vite-bundle-visualizer
```

### Quick Size Check
```bash
# Check what's largest in the build output
du -sh dist/assets/* | sort -rh | head -20
```

## esbuild / SWC as Minifier

If Webpack build is slow, replace terser:
```js
const TerserPlugin = require('terser-webpack-plugin');

optimization: {
  minimizer: [
    new TerserPlugin({
      minify: TerserPlugin.esbuildMinify, // 10-100x faster
    }),
  ],
}
```
