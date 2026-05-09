# Top Team Strategies

Distilled tactics from published participation reports of teams that finished in the top 10 of recent ISUCONs. Each entry is a transferable habit, not a one-off trick.

## takonomura — ISUCON14 Champion (solo, 58,153 pts)

Source: https://logmi.jp/main/technology/329539, https://github.com/takonomura/isucon14, https://techplay.jp/column/1370

**1. Pre-day work is non-negotiable.**
GitHub repo, dotfiles, alp/Netdata installs, deploy script — all done before the morning. Day-of effort starts at "first benchmark", not "set up SSH".

**2. Use tools you actually understand.**
Prefers Netdata for live metrics (visual, no learning curve mid-run) and `sshuttle` for SSH-as-VPN over more flexible alternatives. The cost of an unfamiliar tool failing under pressure is larger than its theoretical capability advantage.

**3. Decide based on measurement, not score.**
After a change, the question is "is the bottleneck where I expected?", not "did the score go up?". Sometimes the score is flat because a different bottleneck has emerged — the change was correct and you continue. Sometimes the score went up but the wrong thing got faster — revert and try again.

**4. Ruthless about wasted changes.**
If there is no clear measurement basis for a change, do not make it. The cost of a 30-min experiment that doesn't help is two opportunity-missed optimizations elsewhere.

**5. Topology: 3 instances, dedicated DB.**
Standard top-team layout: app + nginx on isu1 and isu2, DB on isu3.

## NaruseJun (LayerX team) — ISUCON14, 4th place (48,615 pts)

Source: https://zenn.dev/layerx/articles/3bd55b77e047c4

**1. Annotate every SQL with caller location.**
Custom `database/sql` driver that prepends `/* file:line:funcname */` to every statement. The slow query log then maps back to the exact handler. Removes the "where does this query come from" search from every cycle.

**2. Decisions are team-wide, code is individual.**
The whole team sits together over the alp + pt-query-digest output and agrees on the next priority. Then one person implements while the others continue measurement and prepare the next change. Avoids "two people optimize the same thing" and "I changed it without telling you" failures.

**3. Algorithmic wins come late.**
The big jumps for this team were:
  - 4,981 → 10,221: DB onto its own instance.
  - 10,221 → 21,372: matching algorithm changed from random to nearest-chair (single biggest jump).
  - 21,372 → 30,936: completion-state recorded in DB to avoid recomputation, notification interval tuned.

The pattern: infrastructure first (DB split), then algorithm (matching), then last-mile (notifications/streaming).

**4. Streaming response for hot endpoints.**
Final-hour optimization: turned the notification endpoint into a stream rather than per-request lookup → +8k score in one change.

## Common patterns across multiple top finishers

### Reading from many years of write-ups

**A. The first 60 minutes are sacred for measurement.**
Top teams almost never start optimizing before T+60min. The teams that "rush in" with a guessed index burn 30 minutes on something not in the top 5 hot queries.

**B. One person owns the deploy pipeline from minute zero.**
A botched deploy mid-contest costs ~20 minutes per occurrence. Top teams have a `make deploy` that is tested by hour 1 and used unchanged for the remaining 7. Avoid `vim`-on-server edits.

**C. Re-measure after every win.**
The bottleneck moves. The team that reads alp + pt-query-digest only at the start has the wrong target by hour 3. Top teams budget 5 minutes after every change for re-measurement.

**D. Score-and-commit-hash log.**
Every benchmark run is logged with: timestamp, score, commit hash, what changed since last run. This is the difference between "we are stuck at 25k" and "we know exactly which of the last 6 commits is responsible".

**E. Watch the bench log as carefully as the score.**
A score that looks flat may hide a degraded request mix (the benchmarker stopped issuing some endpoints because the app failed early ones). Read the per-endpoint counts in the bench output, not just the total.

**F. Reboot test at T−90min, not T−30min.**
Teams that test reboot late discover unfixable issues with 20 minutes left. Top teams treat T−90 to T−60 as "reboot validation window" and refuse to make new optimizations during it.

**G. Algorithmic rewrites preserve the API.**
The benchmarker validates the API contract, not the implementation. A rewritten matching algorithm that returns equivalent results for benchmark traffic is fine; one that subtly changes ordering or counts will fail. Always validate with the benchmarker before committing.

**H. Finals: lock at T−15min, do nothing.**
A push at T−5min that forgets to compile or restart is the all-time canonical loss. Top teams put down the keyboards, watch the score, and drink water.

## Anti-patterns observed in mid-pack finishes

These appear repeatedly in retrospectives:

- **Switching language at hour 3.** The 30% perf gain from Rust does not pay back the 4 hours of porting.
- **Optimizing the test endpoint instead of the production endpoint.** A `/api/health` that gets 50% of requests in the bench is not "production traffic" — it is a benchmarker artifact, ignore it unless the manual confirms otherwise.
- **Adding Redis when in-memory would do.** Until you have multiple app instances, in-memory is faster, simpler, and has no consistency story.
- **Disabling cache invalidation "just for now" to debug a bug.** Forgetting to re-enable it before the final benchmark is the #1 way to fail correctness in the last hour.
- **Not running the bench at all in the last hour.** Some teams hold the score they have, refuse to bench again, then fail re-test. Always run a final bench with the exact final config.

## Reading List (post-mortems worth studying)

- ISUCON14 official explanation: https://isucon.net/archives/cat_1024995.html (latest year)
- LayerX/NaruseJun ISUCON14 write-up: https://zenn.dev/layerx/articles/3bd55b77e047c4
- takonomura ISUCON10 victory interview: https://techplay.jp/column/1370
- takonomura ISUCON9 Qualify report: https://www.takono.io/posts/2019/09/isucon/
- ISUCON11 official strategy guide: https://isucon.net/archives/56082639.html
- South37 ISUCON cheat sheet (commands and configs): https://gist.github.com/south37/d4a5a8158f49e067237c17d13ecab12a

Each retrospective has a different idea you can lift. Read at least two per past ISUCON before competing.
