# VRT Troubleshooting

Common VRT failures in Web Speed Hackathon and how to fix them.

## Flaky Tests

### Animations Not Settled

**Symptom**: Screenshots differ in animation frames (e.g., carousel position, fade-in opacity).

**Fix**: Disable animations before capture:
```typescript
await page.addStyleTag({
  content: `*, *::before, *::after {
    animation-duration: 0s !important;
    transition-duration: 0s !important;
  }`
});
```

**Caution**: Check regulation — some competitions forbid modifying test files.

### Lazy-Loaded Images Not Visible

**Symptom**: Below-fold images appear as blank placeholders in screenshots.

**Fix**: Scroll to trigger lazy loading, then scroll back:
```typescript
// Scroll to bottom to trigger all lazy loads
await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
await page.waitForTimeout(1000);
await page.evaluate(() => window.scrollTo(0, 0));
await page.waitForTimeout(500);
```

Or use `networkidle` wait strategy:
```typescript
await page.goto(url, { waitUntil: 'networkidle' });
```

### Dynamic Content (Timestamps, Ads, Random)

**Symptom**: Content changes between runs (dates, randomized elements).

**Fix**: Use `maxDiffPixelRatio` or mask dynamic regions:
```typescript
await expect(page).toHaveScreenshot({
  maxDiffPixelRatio: 0.01,
  mask: [page.locator('.dynamic-timestamp')],
});
```

### Web Font Loading Race

**Symptom**: Text renders in fallback font in some runs.

**Fix**: Wait for fonts to load:
```typescript
await page.waitForFunction(() => document.fonts.ready);
```

## Environment Issues

### Server Not Ready

**Symptom**: `net::ERR_CONNECTION_REFUSED` or blank page screenshots.

**Fix**: Wait for the server to be ready before running tests:
```bash
# Wait for server to respond
timeout 30 bash -c 'until curl -s http://localhost:3000 > /dev/null 2>&1; do sleep 1; done'
npx playwright test --project=vrt
```

### Port Conflicts

**Symptom**: Server fails to start, tests hit wrong application.

**Fix**: Kill existing processes and use consistent port:
```bash
lsof -ti:3000 | xargs kill -9 2>/dev/null
npm run start &
```

### Missing Chromium

**Symptom**: `browserType.launch: Executable doesn't exist`

**Fix**:
```bash
npx playwright install --with-deps chromium
```

## Diff Analysis

### Reading the HTML Report

```bash
npx playwright show-report
```

The report shows three images per failed test:
1. **Expected** — The baseline (what it should look like)
2. **Actual** — What was captured this run
3. **Diff** — Highlighted pixel differences (pink/red areas)

### Common Diff Patterns

| Diff Pattern | Likely Cause |
|---|---|
| Entire page is different | Wrong page loaded, server error, hydration failure |
| Text shifted slightly | Font metrics changed (subsetting, swap) |
| Images look different | Format conversion quality, missing images |
| Small colored rectangles | Anti-aliasing differences (usually OK if < threshold) |
| Layout shifted | CSS changes, removed styles, CLS fix side effects |
| Bottom of page different | Content reflow from changes above |

### Threshold Tuning

If the competition allows custom thresholds:
```typescript
expect(page).toHaveScreenshot({
  maxDiffPixelRatio: 0.005,  // 0.5% tolerance
  threshold: 0.2,             // Per-pixel color threshold
});
```

**Warning**: Don't increase thresholds to make tests pass — that defeats the purpose. Only adjust if the competition regulation specifies a tolerance.

## Baseline Management

### When to Update Baselines

Update baselines (`--update-snapshots`) ONLY when:
1. You made an intentional visual change that regulation permits
2. You verified the new appearance is correct
3. You can explain exactly what changed and why

### Never Update Baselines When:
- You don't understand why the diff occurred
- The change looks like a regression
- You haven't checked the regulation for that visual element

### Reviewing Updated Baselines

After updating, always verify:
```bash
# Re-run VRT to confirm it passes with new baselines
npx playwright test --project=vrt

# Check git diff to see which baselines changed
git diff --stat
```

Look at each changed `.png` file to confirm the visual change is intentional.
