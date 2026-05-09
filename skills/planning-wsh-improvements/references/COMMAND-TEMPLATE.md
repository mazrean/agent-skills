# Command Template

Every generated WSH improvement command MUST follow this template structure.

## File Location

`.claude/commands/wsh-{NNN}-{short-name}.md`

## Template

```markdown
# WSH-{NNN}: {Title}

Category: {Bundle | Image | Font | Network | Server | CSS | Runtime | SSR | Advanced}
Estimated Impact: +{X}-{Y} pts
VRT Risk: {Low | Medium | High}
Affects: {LCP | TBT | CLS | FCP | SI | INP} (list all affected metrics)
Related Skill: wsh-{topic}

## Background Knowledge

Before starting, read the related skill for implementation details and pitfalls:
- Read `.claude/skills/wsh-{topic}/SKILL.md`

## Problem

{1-2 sentences describing the performance issue found in the codebase.
Include specific file paths and line numbers.}

## Changes

{Precise list of changes to make. Be specific — name files, functions, line numbers.
Each change should be unambiguous.}

### File: `{path/to/file}`
- Line {N}: Change `{old}` to `{new}`
- Line {M}: Remove `{code}`

### File: `{path/to/another/file}` (if applicable)
- {changes}

### Dependencies (if applicable)
- Run: `npm install {package}` or `npm uninstall {package}`

## Build Verification

After making changes:
```bash
npm run build
```

Expected: Build succeeds with no errors.
If build fails: {specific guidance on common build errors for this change}

## Lighthouse Score Check

After build verification passes, measure the score impact **before** running VRT.

1. Ensure the app is built with latest changes:
   ```bash
   npm run build
   ```
2. Start the server via portless (no need to kill existing processes):
   ```bash
   portless wsh npm run start &
   ```
3. Wait for the server to be ready:
   ```bash
   timeout 30 bash -c 'until curl -s http://wsh.localhost:1355 > /dev/null 2>&1; do sleep 1; done'
   ```
4. Run Lighthouse on affected pages:
   ```bash
   npx lighthouse http://wsh.localhost:1355{path} \
     --only-categories=performance \
     --chrome-flags="--headless --no-sandbox" \
     --output=json --output-path=./lh-wsh-{NNN}.json
   ```
5. **Compare scores** against the baseline recorded in `wsh-plan.md`:
   - Report per-metric changes: FCP, SI, LCP, TBT, CLS
   - If score **improved or unchanged**: proceed to VRT
   - If score **regressed unexpectedly**: investigate before proceeding — the change may have introduced a new bottleneck. Fix or reconsider the approach, then re-measure

**Note**: Lighthouse scores can fluctuate ±3-5 pts between runs. Focus on clear trends, not noise.

## Quick Verification

After confirming the Lighthouse score is acceptable, do a minimal sanity check. **Do NOT run full e2e/VRT suites** — they are too slow for iterative development.

1. **curl check** — Confirm the app responds and key pages return 200:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" http://wsh.localhost:1355/
   curl -s -o /dev/null -w "%{http_code}" http://wsh.localhost:1355{affected_path}
   ```
2. **Visual spot-check with Playwright CLI** — Take a screenshot of affected pages to visually confirm nothing is broken:
   ```bash
   npx playwright screenshot --browser=chromium http://wsh.localhost:1355{affected_path} /tmp/wsh-{NNN}-check.png
   ```
   Open the screenshot and confirm the page looks correct. If VRT Risk is Medium or High, take screenshots of 2-3 key pages.

3. If something looks broken: fix the issue, rebuild, and re-check.
4. If unable to fix: revert changes with `git checkout -- .` and report the failure.

## Commit & PR

After both Lighthouse and quick verification pass, commit and create a pull request.

### 1. Commit

```bash
git add -A
git commit -m "perf: {short description of optimization}

WSH-{NNN}: {Title}
Lighthouse delta: {score change per page}
Visual check: OK"
```

### 2. Push and Create PR

```bash
git push -u origin HEAD
```

Create a PR with `gh pr create`:

```bash
gh pr create --title "perf: {short description}" --body "$(cat <<'EOF'
## WSH-{NNN}: {Title}

**Category**: {category}
**Estimated Impact**: +{X}-{Y} pts
**Affects**: {metrics}

## Changes
{brief summary of what was changed and why}

## Lighthouse Results

| Page | Before | After | Delta |
|------|--------|-------|-------|
| {page} | {score} | {score} | {+/-} |

## Visual Check
OK — spot-checked via curl + Playwright screenshot.

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### 3. Report

Report: "WSH-{NNN} complete. Lighthouse: {score delta}. Visual check OK. PR created: {PR URL}. Ready for next improvement."

## Rollback

If this optimization causes unfixable issues:
```bash
git checkout -- .
```
```

## Rules for Command Generation

1. **One file per improvement** — Never combine multiple unrelated optimizations
2. **Concrete, not abstract** — "Change line 42 of webpack.config.js from `mode: 'development'` to `mode: 'production'`" not "fix the build mode"
3. **Include VRT risk notes** — Every command must note what specific visual regressions this change might cause
5. **Quick verification is mandatory** — Include curl + Playwright screenshot checks (NOT full VRT/e2e suites)
6. **Adapt the verification commands** to the project — Use the correct port number and key page paths
7. **Commit message format**: `perf: {short description of optimization}`
8. **PR is mandatory** — Every command must create a PR with Lighthouse results and visual check status via `gh pr create`
9. **Include rollback** — Every command must have a rollback section

## VRT Risk Categories

| Risk Level | Meaning | Examples |
|------------|---------|---------|
| Low | Very unlikely to affect visuals | Build mode, source maps, compression, caching headers |
| Medium | May affect rendering subtly | Image format conversion, font subsetting, CSS changes |
| High | Likely to cause visual differences | SSR, library replacement, layout restructuring |

Commands with High VRT risk should include extra-detailed VRT failure guidance specific to the optimization.

## Adapting Verification Commands to the Project

Before generating commands, check:
1. How to build? (`npm run build`, `pnpm build`, custom?)
2. How to start? (`npm run start`, `pnpm start`, custom?) — always wrap with `portless wsh`
3. What are the key page paths to spot-check?

Embed the correct curl/screenshot commands into every generated command file.
