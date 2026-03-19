# Network & Server Optimization

## Compression Middleware

### Fastify
```js
import compress from '@fastify/compress';
await fastify.register(compress, {
  encodings: ['br', 'gzip'], // Brotli preferred
});
```

### Express/Koa
```js
import compression from 'compression';
app.use(compression());
```

### Hono
```js
import { compress } from 'hono/compress';
app.use(compress());
```

## Cache Headers

### Static Assets (hashed filenames)
```js
// Serve static with immutable caching
app.use('/assets', express.static('dist/assets', {
  maxAge: '1y',
  immutable: true,
}));
```

### Fastify Static
```js
import fastifyStatic from '@fastify/static';
fastify.register(fastifyStatic, {
  root: path.join(__dirname, 'dist'),
  prefix: '/assets/',
  maxAge: '1y',
  immutable: true,
});
```

### Remove no-store
Search for `no-store`, `no-cache`, `must-revalidate` on static asset routes and replace:
```js
// Before
res.setHeader('Cache-Control', 'no-store');
// After
res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
```

## Remove Artificial Delays

Common patterns to search for:
```bash
# Search patterns in server code
grep -rn "setTimeout\|sleep\|delay\|jitter\|Math\.random.*1000" src/server/
```

```js
// Before (intentional delay trap)
await new Promise(resolve => setTimeout(resolve, 500 + Math.random() * 500));
const data = await db.query(sql);

// After — just remove the delay
const data = await db.query(sql);
```

## N+1 Query Fix

### Before (N+1)
```js
app.get('/api/posts', async (req, res) => {
  const posts = await db.select().from(postsTable);
  for (const post of posts) {
    post.author = await db.select().from(usersTable).where(eq(usersTable.id, post.authorId));
    post.comments = await db.select().from(commentsTable).where(eq(commentsTable.postId, post.id));
  }
  return posts;
});
```

### After (JOIN or batch)
```js
// Drizzle ORM example
const posts = await db
  .select()
  .from(postsTable)
  .leftJoin(usersTable, eq(postsTable.authorId, usersTable.id))
  .leftJoin(commentsTable, eq(commentsTable.postId, postsTable.id));

// Or batch with IN clause
const authorIds = posts.map(p => p.authorId);
const authors = await db.select().from(usersTable).where(inArray(usersTable.id, authorIds));
```

## Database Indexes

### Drizzle
```ts
export const postsTable = sqliteTable('posts', {
  id: integer('id').primaryKey(),
  authorId: integer('author_id').notNull(),
  createdAt: text('created_at').notNull(),
}, (table) => ({
  authorIdIdx: index('idx_posts_author_id').on(table.authorId),
  createdAtIdx: index('idx_posts_created_at').on(table.createdAt),
}));
```

### Raw SQL
```sql
CREATE INDEX IF NOT EXISTS idx_posts_author_id ON posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at);
```

## Trim API Response Payload

Remove unnecessary nested/circular data:
```js
// Before — bloated response with circular references
// series → episodes → series → episodes → ...

// After — only include needed fields
const response = posts.map(p => ({
  id: p.id,
  title: p.title,
  thumbnailUrl: p.thumbnailUrl,
  authorName: p.author.name,
  // Don't include full author object, comments list, etc.
}));
```

## Parallelize Client-Side Fetches

```js
// Before (sequential)
const user = await fetch('/api/user').then(r => r.json());
const posts = await fetch('/api/posts').then(r => r.json());
const comments = await fetch('/api/comments').then(r => r.json());

// After (parallel)
const [user, posts, comments] = await Promise.all([
  fetch('/api/user').then(r => r.json()),
  fetch('/api/posts').then(r => r.json()),
  fetch('/api/comments').then(r => r.json()),
]);
```

## Resource Hints in HTML

Order matters — place in `<head>` before the resources they hint:
```html
<head>
  <!-- 1. Preconnect to API/CDN origins -->
  <link rel="preconnect" href="https://api.example.com" />
  <link rel="dns-prefetch" href="https://api.example.com" />

  <!-- 2. Preload critical resources -->
  <link rel="preload" as="font" type="font/woff2" href="/fonts/main.woff2" crossorigin />
  <link rel="preload" as="image" href="/images/hero.avif" type="image/avif" />
  <link rel="preload" as="style" href="/styles/critical.css" />

  <!-- 3. Prefetch next-page resources -->
  <link rel="prefetch" href="/next-page-bundle.js" />
</head>
```

## POST /api/initialize

WSH requires this endpoint to reset DB state. Make sure it:
1. Still works after your optimizations
2. Doesn't have a delay you accidentally removed
3. Actually resets all data to initial state
