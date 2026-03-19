---
name: checking-wsh-vrt
description: Runs Visual Regression Testing (VRT) locally to prevent disqualification in Web Speed Hackathon. Captures screenshots, compares against baselines, updates snapshots, and validates visual integrity after performance optimizations. Use when optimizing WSH apps, running VRT checks, updating VRT baselines, or investigating VRT failures.
---

# Checking WSH VRT

Prevents disqualification in Web Speed Hackathon by running Visual Regression Testing locally. VRT failures mean your optimizations broke the visual appearance — and that means disqualification, no matter how fast your app is.

**Use this skill when** you need to run VRT checks during WSH optimization, investigate VRT failures, or update baselines after intentional visual changes.

**Supporting files:**
- [VRT-TROUBLESHOOTING.md](references/VRT-TROUBLESHOOTING.md) — Common VRT failures and fixes

## Quick Start

```bash
# 1. Install dependencies (first time only)
npx playwright install --with-deps chromium

# 2. Start the app
npm run build && npm run start &

# 3. Run VRT
npx playwright test --project=vrt

# 4. If tests fail, review diffs
npx playwright show-report
```

## Core Workflow

### Before Any Optimization

1. **Read `docs/regulation.md`** — Understand what visual elements must be preserved
2. **Verify VRT passes on unmodified code** — If baseline is broken, fix it first
3. **Commit the clean state** — You need a known-good point to revert to

### After Every 2-3 Optimizations

Run the full VRT check cycle:

```bash
# Build and start (ensure latest changes are reflected)
npm run build && npm run start &

# Wait for server to be ready, then run VRT
npx playwright test --project=vrt
```

**If VRT passes**: Commit immediately. This is your new safe checkpoint.

**If VRT fails**: See the failure resolution workflow below.

### VRT Failure Resolution

1. **Open the HTML report** to see visual diffs:
   ```bash
   npx playwright show-report
   ```

2. **Classify the failure**:
   - **Unintentional breakage** — Your optimization broke something. Revert or fix.
   - **Intentional change** — Layout improved (e.g., CLS fix added explicit dimensions). Update baseline.
   - **Flaky test** — Animation timing, lazy-load race condition. Needs stabilization.

3. **For unintentional breakage**:
   ```bash
   # Revert to last known-good commit
   git stash   # or git checkout -- .
   ```
   Then re-apply optimizations one by one to isolate the culprit.

4. **For intentional changes** (only if regulation allows):
   ```bash
   # Update baseline snapshots
   npx playwright test --project=vrt --update-snapshots

   # Verify the new baselines look correct
   npx playwright show-report

   # Commit updated baselines
   git add -A '*.png'
   git commit -m "update VRT baselines: <reason>"
   ```

5. **For flaky tests**: See [VRT-TROUBLESHOOTING.md](references/VRT-TROUBLESHOOTING.md)

## Critical Rules

- **Never skip VRT** — "I'll check later" leads to compounding visual regressions that are impossible to debug
- **Never batch more than 3 changes** before running VRT — Bisecting visual bugs across many changes wastes hours
- **Never blindly update baselines** — Every `--update-snapshots` must be reviewed. Blindly updating hides regulation violations
- **Always read the regulation first** — Some competitions have specific VRT configurations or custom comparison thresholds
- **Commit after every green VRT run** — Your commit history is your safety net

## Regulation Awareness

WSH regulations typically specify:
- **Which pages are tested** — VRT may only cover scored pages
- **Comparison thresholds** — Pixel diff tolerance (e.g., 0.1% threshold)
- **Required viewport sizes** — Desktop and/or mobile
- **Animation handling** — Whether animations must be disabled during capture

Check `docs/regulation.md` and the VRT config (usually `playwright.config.ts`) for project-specific settings.

## WSH-Specific VRT Pitfalls

| Optimization | VRT Risk | Mitigation |
|---|---|---|
| Image format conversion (AVIF/WebP) | Color shift, quality loss | Compare carefully, adjust quality parameter |
| Font subsetting | Missing glyphs | Verify all characters used on scored pages |
| CSS-in-JS removal | Style differences | Pixel-level comparison in report |
| Lazy loading images | Images not loaded in screenshot | Ensure scroll/wait in test or disable lazy for VRT |
| CLS fixes (dimensions) | Layout shift (intentional) | Update baselines after confirming improvement |
| SSR implementation | Hydration mismatch visible | Check for flicker or unstyled content |
| Library replacement | Rendering differences | Carefully compare component output |

## Playwright Config Check

Before running VRT, verify the Playwright config has correct VRT settings:

```typescript
// Expected in playwright.config.ts
{
  project: {
    name: 'vrt',
    testMatch: /.*\.vrt\.ts/,  // or similar pattern
    use: {
      // Consistent viewport for reproducible screenshots
      viewport: { width: 1440, height: 900 },
      // Animations disabled for deterministic captures
      // Check regulation for required settings
    }
  }
}
```

If the project doesn't have VRT configured, check `docs/regulation.md` for the competition's expected VRT setup before creating your own.
