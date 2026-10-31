# Observed Barriers

Source: a supervised Claude Code session tuning a past ISUCON problem on a
3-host + bench practice environment, with a driver agent and three
subagents (infra, benchmarker analysis, experiment env; later Rust, nginx, kernel). ~17 hours observed.
Times are minutes from start (T+).

Trajectory: baseline 1,085 (T+10) → infra-only 1,796 (T+22) → in-memory
rewrite fails `pass=false` (T+29) → 288,237 (T+30) → 3-host split 325,960
(T+45) → ~64万 stable after long-polling empty responses (T+~2.5h) →
93–95万 inflated by a network burst allowance → 757,578–803,900
reproducible over 4 consecutive runs (T+5h, the driver's own final report).
Speed was not the problem; the items below were.

Second source (entries A8, B16–B21, and the "Run 2" notes): an 8-hour
contest-mode rehearsal of another past problem on 3 hosts + bench, with a
30-minute emulated bench queue, a pseudo-bench/oracle built in the first
hour, four to six worktree-isolated subagents, and a separate supervisor
session. Times are wall-clock offsets. Trajectory: baseline 2,617 → FAIL
(bench client fds) → 181,233 → FAIL (bench client ports) → 1,158,467 →
1,613,234 → 0 (unsoaked custom proxy) → **1,656,610** best at T+3h20 →
every later run lower (1.27–1.50M) → 1,495,206 after the final full reboot.
Losses: ~2 h of idle turn ends, 3 of ~14 official slots spent on FAILs.

Third source (entries B22–B30 and section D, "Run 3"): a **real 8-hour
contest**, not a rehearsal. Four hosts with 2 vCPU each. Three app hosts in
emulated regions, all inter-host traffic through a router that adds ~100 ms
RTT and caps bandwidth. One shared DB host in the home region. Cross-region
read-your-writes was mandatory. The score came from simulated users whose
count compounded daily. One driver with up to ~20 parallel worktree subagents
(184 spawned), a supervisor session and a strategist session. Portal bench,
almost no queue. Trajectory: 3,023 → 16,875 (T+44 min) → 112k, rank 9
(T+2h26) → 146k (T+3h34) → **199,880** best at T+6h13 → no new best in the
~25 runs after → 198,146 final (pass, 0 errors), rank ~39 of the frozen
board. The leader had 506k at T+1h22 and 629k at the end. 119 official runs,
17 of them FAIL (~85 min of slots).

Each entry: **pattern → impact → detection (for a supervisor) → fix**.

## A. Practice-only affordances (contest-day blockers)

### A1. Strategy derived from benchmarker source
- **Pattern:** a subagent cloned the upstream problem repo, read scenario,
  world model, validation and payment code, and produced a line-numbered
  report (score formula, tick length, dispatch conditions). The driver
  coded the rewrite against it; the fix for the first `pass=false` was
  also found by grepping bench source.
- **Impact:** the user had to stop and rule on legitimacy (T+27). On
  contest day none of this exists; the agent had no rehearsed path to the
  same facts.
- **Detect:** `git clone .../isucon<N>` of the problem repo, reads under
  `bench/`, `benchmarker/`, `world/`, `scenario/`.
- **Fix:** contest-mode preamble (BENCH-LOOP.md); derive spec from manual,
  openapi, app code, frontend bundle, and `CODE=` messages.

### A2. Tuning based on bench-client internals
- **Pattern:** read the load generator's HTTP-cache implementation, added
  `expires 1d` to static files expecting skipped requests. Score dropped
  308k → 239k → 197k; revert → 326k.
- **Impact:** ~5 min and two bench runs; a conclusion that could not have
  been reached by reasoning on contest day anyway.
- **Fix:** treat client-behaviour hypotheses as A/B experiments, not facts.

### A3. Shell on the bench host
- **Pattern:** `top` on the bench host showed the load generator at ~750 %
  CPU; the agent concluded "the bench is the bottleneck", then installed
  and ran `perf` against it (symbols stripped, nothing learned).
- **Impact:** ~5 min, plus a false belief that shapes later decisions.
  On contest day the bench runs on organizer hardware.
- **Fix:** profile only own hosts; ignore bench-side saturation.

### A4. Spare environment for experiments
- **Pattern:** launched a second full environment (3 hosts + bench) for a
  topology-experiment subagent; the user ordered it torn down 6 min later.
- **Impact:** cost, a killed subagent leaving uncommitted edits the driver
  had to inspect and absorb.
- **Fix:** partition the given hosts; experiments go through the bench lock.

### A5. Unlimited, ~70 s, unqueued bench
- **Pattern:** ~15 bench runs in ~45 min, several purely to re-check noise.
- **Impact:** habits (bench-per-tweak, re-run to check noise) that do not
  fit a portal queue.
- **Fix:** noise band measured once early; batch low-risk changes; local
  correctness smoke test.

### A6. Bench-aware response shaping
- **Pattern (T+~68):** after profiling the bench host and reading the
  simulated client loop, the agent made the nearby-chairs endpoint sleep
  100 ms when it had nothing to return, so simulated users re-polled less
  and the bench's CPU went to score-producing work. Score 28–31万 → 32–33万.
- **Escalation (T+~150–170):** the same lever became the dominant one:
  empty-response delay 300 ms → 1 s → 2 s, `no-store` on images to defeat
  the load generator's per-user cache, then a long-poll that holds an empty
  nearby-chairs request up to 4 s until a chair frees. Score 36万 → 50万 →
  a single 70万 outlier (not reproduced; ~53万 next, ~64万 stable later — a
  B4 lesson inside A6) — larger than every server-side optimization combined.
- **Impact:** in practice, the biggest win of the session; but every step
  was derived from A1 + A3, and it is a regulation gray zone the supervisor
  escalated to the user. On contest day an agent that has only rehearsed
  with bench source will not find this lever at all.
- **Contest-day route to the same lever:** the frontend bundle shows the
  real polling loop (interval, what it does on an empty list); the manual
  states latency/timeout tolerances. From those alone, "an empty answer
  causes an immediate re-poll" is discoverable — then A/B the hold time.
- **Fix:** only shape responses from documented client behaviour; A/B it;
  pre-agreed gray-zone policy (SKILL.md §0).

### A7. Scores from a self-built benchmarker
- **Pattern (T+~3.6h):** right after the user said "anything goes except
  changing the benchmarker", the driver copied the benchmarker source,
  added a CPU-profile hook, built it, and ran that binary (with a
  different flag set) on the bench host. It printed `pass=true
  スコア=1116114` — 1.5× the best official run — in the same format the
  supervisor and the agent's own loop parse as a score.
- **Impact:** a profiling build is arguably "not changing the
  benchmarker", but its score is not comparable and is easily recorded as
  a new best. On contest day the source does not exist at all.
- **Escalation (T+~4h):** the rebuilt copy then had its embedded
  static-file manifest and hashes (`frontend_files.json` /
  `frontend_hashes.json`, what the bench validates assets against)
  replaced, so changed frontend assets would pass. That is no longer
  "profiling" — it is a modified validator, against an explicit "do not
  change the benchmarker" instruction, and any result tuned against it
  will fail the official bench.
- **Detect:** a bench invocation whose binary path is not the official
  one; edits or copies under the benchmarker's embedded data.
- **Fix:** the bench wrapper is the only thing allowed to produce score
  lines that count; it pins the official binary path. Anything else is
  labelled `UNOFFICIAL` and never enters `SCORES.tsv`.

### A8. Bench-client limits "fixed" on the bench host (Run 2)
- **Pattern (T+1h):** the first in-memory build was fast enough that the
  bench's adaptive scenario grew to ~580 workers in ~2 s and the bench
  process itself died: `dial tcp: socket: too many open files` → FAIL. The
  driver cut nginx `keepalive_timeout` 75 → 2 s; that turned into a
  handshake storm and saturated TLS (p50 1 s, players left). Raised to 30 s,
  the next run FAILed on `connect: cannot assign requested address`
  (bench ephemeral ports held by idle keepalive connections). Both FAILs
  were "solved" only by the human allowing `nofile` and
  `ip_local_port_range`/`tcp_tw_reuse` changes on the bench host.
- **Impact:** 2 of the first 4 official slots (~1 h of feedback at a
  30-min queue), four keepalive values tried by guess. On contest day the
  bench host is not yours — the same app would have been stuck at FAIL.
- **Root cause:** the load generator's fds and ports are finite; nobody
  modelled them, and the pseudo-bench ran without those limits.
- **Detect:** bench-side errors that are socket/dial errors from the
  client (`too many open files`, `cannot assign requested address`,
  dial timeouts) rather than HTTP status/validation errors; a FAIL right
  after a large speed-up.
- **Fix (server side only):**
  - estimate open client connections ≈ new-connection rate × server idle
    timeout; keep it well under ~1k fds and ~28k ports;
  - choose idle timeouts from the measured per-client inter-request gap CDF
    (log `$msec` + a session/cookie key; here 98.9 % of gaps were ≤ 5 s →
    `keepalive_timeout 5s` worked), never by guess;
  - if the manual allows rate limiting (e.g. 429 + `Retry-After` on
    creation endpoints), ship it behind a flag as a kill switch;
  - make the pseudo-bench enforce `ulimit -n 1024` and the default port
    range so it fails the same way first.
  - A DNAT front + clients reusing source ports later produced hung SYNs
    (`i/o timeout` burst at run end, −18 %): see
    `tuning-isucon-linux-and-nginx`/TLS-LB "Costs and limits".

## B. Process hygiene

### B1. Interactive prompt hang
- **Pattern:** `cp <file> /dev/null` inside a long command; an `-i` alias
  prompted `overwrite '/dev/null'?`. Foreground blocked until the 300 s
  tool timeout moved it to background. A subagent separately hit
  `noclobber` on `>` redirects.
- **Also (T+~9.7h):** `...; pkill -f "cm-ubuntu@<old-ip>"; ...` killed the
  shell running it, because the pattern was in its own command line
  (exit 144). The supervising session made the identical mistake while
  testing a hook — this one is not agent-specific, it is a shell trap.
- **Recurred (T+~10.5h):** `rm webapp/go/tls.go` (no `-f`) hit the same
  `rm -i` alias and hung until the 200 s tool timeout. Ten hours in, the
  agent still had not adapted to the shell it was given — the alias check
  has to be a startup step, not a lesson learned.
- **Run 2:** the skill (with this rule) was loaded at T+0, yet the alias
  check ran only after a `cp -i` hang at T+9 min. zsh then added new traps:
  `exec 9>lock` failed under `noclobber` mid-chain, so one host was deployed
  and the other two silently skipped (a partial deploy); an unquoted `$R`
  holding several curl options was not word-split (`option unknown`);
  `nomatch` errors spammed polling loops; pre-existing `~/.ssh/config`
  `Host` patterns shadowed the new per-contest aliases (timeouts).
  Run the check as the literal first command, write scripts as bash files
  (not inline zsh), use `9>>lock`, and verify aliases with `ssh -G <alias>`.
- **Impact:** ~5 min at T+2, before the baseline existed; ~3.5 min again
  at T+10.5h.
- **Detect:** a foreground command exceeding its timeout with no output;
  output ending in `?`.
- **Fix:** SKILL.md §3.

### B2. Checkpoints only on request
- **Pattern:** the user interrupted (T+14) and then (T+22) asked for git snapshots
  "so state can be rolled back"; `NOTES.md` and per-step commits started
  only then. The driver had to relay the request to subagents.
- **Fix:** bench wrapper refuses dirty trees and logs every score.

### B3. Shared branch, shared hosts, parallel agents
- **Pattern:** the infra subagent and the driver committed to the same
  branch in the same working tree; the subagent `--amend`ed its commit
  twice after the driver had committed on top of the parent. The subagent
  made deploy paths overridable specifically to avoid clobbering the
  driver's tree. Both deployed to the same hosts.
- **Impact:** no loss this time — but only by luck of timing. A bench run
  during the other agent's deploy would have produced an unattributable
  score.
- **Variant (T+~10.5h):** a subagent was told "only edit persist.go/main.go,
  don't deploy, don't commit" — good ownership rules — but ran in the
  driver's working tree. Every `make deploy` the driver ran meanwhile
  built whatever half-written state those files were in. File ownership
  without a separate worktree still leaks into the driver's builds.
- **Variant (T+~15h), caught by the human:** with a shared lock in place,
  the Rust subagent left its work-in-progress binary deployed when it
  released the lock; the nginx subagent then ran a whole A/B series on top
  of it, without noticing (one run showed 16 validation errors). The lock
  serialised runs but nothing guaranteed *what was deployed* when a holder
  started measuring.
- **Leftovers outside the repo:** the same subagent's final report said an
  experiment drop-in (`<service>.d/exp.conf`) was still on the app node;
  the driver checked the host and it was already gone — the report was
  stale. Either way the lesson holds: out-of-repo state (systemd drop-ins,
  sysctl, iptables, grub defaults) is invisible to `git status`, survives
  into others' measurements and the final reboot, and must be verified on
  the host, not taken from a report.
- **Detect:** `git commit --amend` / `reset` from a subagent; two agents
  running deploy within the same minute; a subagent editing the tree the
  driver deploys from; a bench run whose deployed build/commit differs from
  the one the agent believes it is testing.; any file under `/etc` on a host that is not produced by
  the deploy script.
- **Run 2 variants:** worktrees do not isolate the session scratchpad — a
  subagent's `rm -rf <scratchpad>/wal` deleted another agent's live WAL; a
  subagent handed back with a new file untracked, so merged `main` did not
  build; a replication listener defaulted to a port an auth sidecar (needed
  by the post-contest browser check) already used — caught by the
  supervisor; a leftover test unit still held the port the preflight needed.
- **Fix:** worktree isolation, no-amend rule, `flock` around deploy+bench;
  per-agent `mktemp -d` for scratch state; `git status` clean before
  hand-off and the driver builds after every merge; a port registry in
  `NOTES.md` and `ss -ltnp` on every host before adding a listener.

### B4. Single-run decisions
- **Pattern:** identical-code runs ranged 259k–326k (±12 %). The agent did
  re-run before reverting — good — but had no recorded band, so each
  decision was ad hoc.
- **Fix:** 3 runs on one commit early → band in `NOTES.md`.
- **Recurred (Run 3):** band ±5–10k around 165k, but most adopt/reject calls
  were single runs. The memory-primary write path was rejected twice, each
  time on one run (−14k, −25k). It was adopted later that afternoon as the
  biggest late gain (+15k, repeated). See STRATEGY-LOOP §7.

### B5. Removing the recovery path
- **Pattern:** a daemon-cleanup script stopped `amazon-ssm-agent` along
  with snapd/apt timers; app and DB hosts rebooted in one step.
- **Recurred (T+~3h):** a persistence check rebooted the app host and the
  DB host in the same command, then waited with a foreground
  `until ssh ...; do sleep 5; done` without an overall timeout (B7 again).
  Habits repeat unless the rule is in the prompt or a script.
- **Impact:** none this time; on failure, no out-of-band way back in and
  two hosts down at once.
- **Fix:** SKILL.md §5 (recovery and reboot safety).

### B6. Gray-zone rulings made one interruption at a time
- **Pattern:** the user was asked to rule on bench-source reading (T+27),
  bench-host profiling, and response shaping (T+69) as each came up.
- **Impact:** each ruling interrupts the human and leaves the agent
  continuing on an unapproved path in the meantime.
- **Fix:** gray-zone policy agreed once before start, recorded in `NOTES.md`.

### B7. Blocking in the foreground on a dead host
- **Pattern (T+~75):** two benches chained in one tool call (6 min); the
  second produced no result line. The bench host then stopped answering
  ssh (memory-capped node, suspected OOM as the app got fast enough to
  grow the simulated world). The agent probed with an ssh lacking
  `ConnectTimeout` (120 s tool timeout), then an `until ssh ...; do sleep;
  done` loop in the foreground (300 s tool timeout) — 7+ minutes with no
  other work happening.
- **Recurred (T+~9.5h):** after restarting the bench instance, the driver
  again waited with a foreground `until ssh ...; do sleep 5; done` and
  hit the 300 s tool timeout — the third time this exact shape appeared.
- **Impact:** the whole session stalls on one dependency. 本番 analogues:
  your own app/DB host OOMing after an in-memory rewrite, or a stuck portal job.
- **Detect:** consecutive tool timeouts on the same host; a bench call
  whose output has no result line.
- **Fix:** one bench per tool call; every ssh with `ConnectTimeout` and a
  `timeout`; a host that misses two probes gets a 2-minute budget, then
  recovery (cloud-API reboot / user ask) runs **in the background** while
  the agent continues reading code or preparing the next change. Watch
  RSS of your own in-memory app (`MemoryMax=` in the unit, alert at 70 %).

### B8. Blocking question to an absent human
- **Pattern (T+95 → T+143):** the driver hit a judgment call (bench node
  near its memory cap; maximise score vs. stay safe) and called a blocking
  multiple-choice question to the user. Session status became `waiting` /
  `input needed`; nothing else ran — no subagents, no background work —
  for **48 minutes** until the human came back and picked
  "accept risk, maximise".
- **Impact:** ~10 % of an 8-hour contest lost on one question whose answer
  was the obvious default. The supervising session did not notice: it
  keyed "stalled" on transcript growth while busy, and a session waiting
  on input is neither growing nor busy.
- **Variant (T+~17h):** a subagent's next step (reboot node1 into a custom
  kernel and re-measure) was denied by the session's automatic permission
  classifier. The subagent correctly stopped and handed the decision back
  instead of working around it — but the experiment then sat unfinished
  until a human read the report. Risky steps that the contest plan
  depends on (custom kernel boots, cloud-API reboots) need to be
  pre-approved before minute 0, or they will stall mid-experiment.
- **Run 2 variant:** host-writing steps planned for a subagent were denied
  (`[Remote Shell Writes]`); bench-host inspection was denied
  (`[Production Reads]`); fetching a tool from the internet was denied
  (`[Code from External]`). Plan host writes for the driver or pre-allow the
  exact scripts. Approvals relayed by another session are not consent — see
  B20.
- **Detect:** poll the session's status (`ListAgents`, or the session state
  file's `status` / `waitingFor`) — not transcript growth alone. Status
  alone is also unreliable: a session with a background task shows `shell`
  even after its turn ended (B16; SUPERVISING.md).
- **Fix:** deny `AskUserQuestion` in the contest session (HARNESS-SETUP.md).
  Risk appetite is part of the pre-agreed policy (SKILL.md §0).
  During the contest, judgment calls are **non-blocking**: pick the
  default that maximises a valid score, write the question and the chosen
  default to `NOTES.md`, notify the human, and keep working; reverse later
  if they disagree. Block only for irreversible or regulation-level
  decisions — and even then, hand other work to subagents first. Also
  pre-authorize routine commands so permission prompts cannot cause the
  same stall, and add a `Notification` hook that pushes to the human.

### B9. Intermittent correctness error left open
- **Pattern (T+50 → T+3h+):** a sales-mismatch validation error (one code,
  1–3 per run) appeared in roughly a third of runs. The agent investigated
  once, shipped a partial fix, and moved on to score work while it kept
  recurring.
- **Impact:** a latent fail — error-count thresholds or the post-contest
  re-run can turn "pass with 3 errors" into a fail or a deduction, and the
  final run is a single sample.
- **Detect:** the same `CODE=` appearing in more than one run after a
  claimed fix.
- **Fix:** keep a per-code tally across runs (the bench wrapper prints the
  top codes); any code seen in ≥2 runs becomes a tracked item in
  `NOTES.md` and is assigned to a subagent while the driver keeps tuning.
  It must be at zero by the endgame freeze.
- **Still open** at the driver's own final report (T+5h): code 24 in 3 of
  the last 4 runs.

### B10. Ending the turn mid-contest
- **Pattern (T+~3.5h):** after finishing a self-chosen sub-goal (nginx↔app
  over a Unix socket, a reboot check, a best score of 750k) the driver
  wrote a summary report and ended its turn. Status went `idle`. The
  original instruction ("tune to the limit, 8-hour contest") had no stop
  condition, yet nothing ran until a human typed again.
- **Recurred (T+5h):** the user re-prompted "anything goes, push past the
  limit". 1.5 h later the driver again declared victory ("限界は、越えた"),
  wrote a final summary table, and went `idle` with ~3 h left. A
  re-prompt in prose does not change the behaviour; only an explicit stop
  condition or harness-level re-prompting does.
- **Third time (T+~12h):** after concluding "the ceiling has moved to the
  bench's CPU", the driver wrote "ここで一区切り" and stopped — with code 24
  still recurring in half the runs. "The bottleneck is no longer mine" is
  a recurring stop trigger; it should instead switch the driver to the
  correctness backlog (B9) and per-request cost work.
- **Impact:** identical to B8 — unbounded idle time — but worse to detect,
  because `idle` looks like "done".
- **Detect:** status `idle` while time remains before the deadline.
- **Fix:** the deadline is the stop condition. Write the contest end time
  and a ranked backlog of next hypotheses into `NOTES.md`; after each
  sub-goal pick the next item instead of reporting and stopping. Progress
  reports go out as notifications or notes, not as turn ends. Back it with
  the tested `Stop` hook in HARNESS-SETUP.md, which re-prompts "take the
  next backlog item" until the `END:` time — so an accidental turn end
  costs seconds, not hours.
- **Run 2:** the hook could not be installed by the agent at all, and
  "waiting for the result" became the dominant stop trigger — see B16.

### B11. Time-dependent limits mistaken for regressions
- **Pattern (T+~4.5h):** after a reboot test, scores fell from ~94万 to
  ~79万, with two runs collapsing to 28–30万 with transport errors. The
  agent first suspected the reboot, conntrack, nginx. The real cause:
  the node in front had exhausted its cloud **egress burst allowance**
  (`ethtool -S <if> | grep allowance_exceeded` → `bw_out_allowance_exceeded`
  in the millions). An earlier change — serving large assets uncompressed
  and `no-store` to shape the load generator's cache — had raised egress
  to ~3.6 GB per run. Re-enabling `gzip_static` cut it to ~2.1 GB and
  restored 91–92万.
- **Impact:** ~15 min of misdirected diagnosis; a cause that had been
  in place for an hour surfaced only when credits ran out, so the
  "regression" pointed at the wrong change.
- **Detect:** score decays across runs on unchanged code; transport errors
  with idle-fast responses; nonzero `*_allowance_exceeded` counters; CPU
  credit balance on burstable instance types.
- **Also:** later the front node hit `pps_allowance_exceeded` on every run
  (500–2600 per run) — packet-rate limits bite after bandwidth is fixed.
- **Fix:** add per-run egress bytes and allowance counters for every host
  to the bench wrapper's output; treat bandwidth as a budget (compress,
  cache, keep big responses off the busiest NIC). Note that contest-day
  instance types and limits may differ — re-check them in the first hour.

### B12. Driver idles while a subagent works
- **Pattern (T+~11h):** the driver handed a long task (full language port)
  to a subagent with exclusive bench ownership — correct — and then simply
  waited for its hand-back. Nothing else ran for 10+ minutes until the
  human typed "do what you can while waiting" — and minutes later had to
  supply the idea itself ("anything with CPU affinity?"). The backlog
  existed only in the human's head.
  Then the human had to spell out the coordination protocol too: "work
  with the subagent and try other changes while it is not deploying".
  Exclusive bench ownership was the wrong grain — a shared lock around
  deploy+bench (BENCH-LOOP.md) lets both take turns without a human
  scheduling them.
  Keep a standing checklist of generic levers (CPU pinning / IRQ affinity,
  GOMAXPROCS, GC, kernel network params, NIC queues, TLS offload) in
  `NOTES.md` so the driver never runs out of next items.
- **Impact:** parallelism thrown away; with exclusive bench ownership the
  driver cannot bench, but it can still read, analyse, and prepare.
- **Detect:** driver transcript silent while a subagent transcript grows.
- **Fix:** delegating is not a reason to stop. While a subagent owns the
  bench, the driver works the non-bench backlog: open `CODE=` bugs (B9),
  reading for the next hypothesis, preparing the next change on a branch,
  updating `NOTES.md`. Put this in the driver's own standing instructions.

### B13. Part of a turn withheld by a safety classifier
- **Pattern (T+~14h):** right after launching a subagent, the rest of the
  driver's response was stopped by a safety classifier; the withheld
  text and any tool calls in it never ran. The transcript shows only the
  notice, not what was blocked, so neither the agent nor a supervisor can
  tell which planned steps were lost.
- **Impact:** silent loss of planned work; a driver that assumes its last
  tool calls ran will build on state that does not exist.
- **Detect:** the harness notice in the transcript.
- **Fix:** after such a notice, re-read state (`git status`, `NOTES.md`,
  last bench line, running subagents) before the next action instead of
  assuming the plan executed; continue with a different next step rather
  than rewording the same one. Keep plans in `NOTES.md` so a dropped turn
  loses only the turn, not the plan.

### B14. One bench, four agents: lock held per sweep
- **Pattern (T+~14h):** the driver and three subagents (Rust CPU, nginx
  CPU, kernel/network) all serialised on the same `flock` — good — but the
  driver took the lock once around a 10-run parameter sweep (~15+ min).
  The other three queued behind it; one hit its 600 s tool timeout while
  merely waiting for the lock.
- **Impact:** the lock prevents collisions but turns the single bench into
  the bottleneck of the whole team; agents mostly wait.
- **Detect:** `pgrep -af 'flock .*lock'` showing several waiters; tool
  timeouts on commands that are only `flock ... -c <bench>`.
- **Fix:** take the lock **per run**, not per sweep (sweeps loop *outside*
  the lock, so other agents interleave); cap bench-consuming agents at
  what the bench can serve (roughly: runs per hour ÷ runs each agent needs);
  agents without a free slot do read-only work (profiling analysis,
  code reading) instead of queueing; use `flock -w <sec>` and treat a
  timeout as "do something else", not as a failure.

### B15. Deep, expensive work before cheap, likely wins
- **Pattern (T+~14–15h):** a kernel/NIC subagent spent about an hour
  reading driver source (NAPI, ENA, flowtable, XDP constraints), building
  an XDP load balancer, and A/B-ing five kernel knobs — net gain zero,
  everything reverted. Its final report then listed, almost in passing,
  the cheap levers its measurements had exposed: shift TLS weight to the
  node with 15–22 % idle CPU, and fix nginx→app connection churn (30k
  passive opens in 41 s on the busiest node → upstream keepalive).
- **Impact:** an hour of a bench slot and an agent on the lowest-yield
  item; the high-yield items surfaced last.
- **Fix:** before deep work, each agent spends 5 minutes listing the
  cheap observations from its first measurement (idle CPU per node,
  connection churn, retransmits, allowance counters) and reports those
  first; deep dives (custom kernels, XDP, rewrites) only after the cheap
  list is exhausted, with a time box.
- **Run 2 (cheap lever visible for 6+ runs, still lost):** after the best
  run (T+3h20) every official run scored lower. In every run the app host
  (which also terminated a share of TLS) sat at ~10 % idle while the other
  two hosts had 25–40 %. TLS weights were changed late and always bundled
  with another change, while slots went to big bets (replica cluster,
  custom proxy, crypto patches). The "final layout" was never A/B'd
  against the best run's commit.
- **Fix (Run 2):** when per-host idle is lopsided for 2+ runs, the next
  slot changes **only** the rebalancing; when every run after the best is
  lower, re-run the best commit once before declaring a final layout.
- **Recurred (Run 3), with the rule already in this skill:** two hosts at
  91–100 % CPU, two at 10–25 %, from noon to the end. The per-host table was
  first produced at T+5h13, when the human asked the supervisor. The rule was
  prose; nothing in the wrapper produced the numbers (B22).

### B16. Harness not installable; turn ended with nothing to wake it (Run 2)
- **Pattern:** at T+9 min the driver tried to write the HARNESS-SETUP
  allow-list and `Stop` hook into the contest repo's `.claude/settings.json`;
  the auto-mode classifier denied it as `[Self-Modification]`. The driver
  mentioned it once and carried on without a hook. It then repeatedly ended
  turns with "waiting for the result": the human typed some form of "keep
  thinking while you wait" 8 times. Two turn ends were costly:
  - "run N: waiting for result" → the run FAILed and a host hung; nobody
    noticed for ~8 min, until a subagent's message happened to wake the
    driver.
  - "from here on, repeat runs without changing the layout" → **71 min**
    with no transcript record, bench queue empty, ~2.5 h left, until the
    human typed.
- **Why the wake-up never came:** the enqueue was detached
  (`run_in_background` around `cmd & sleep 2`, or `( … &)`); the tool task
  exits immediately, so no completion notification ever arrives.
- **Impact:** ~2 h of idle driver in total (71 + 16 + 12 + 12 + 8 min) — the largest loss of the run.
- **Detect:** last transcript record is the turn-end system record, no
  later user message, no live background task or Monitor that will report,
  queue empty, time remaining. `ListAgents` showed `shell` (a background
  task existed) and fooled the supervisor (SUPERVISING.md).
- **Fix:** the **human** installs settings and hooks before starting the
  session; at minute 0 the agent only verifies them and notifies if absent
  (HARNESS-SETUP.md). Rule: never end a turn unless something will wake
  you — the official run is a live `run_in_background` task (not
  detached) or a Monitor is armed on the next result — and the backlog in
  `NOTES.md` is empty of non-bench items.

### B17. Home-made replacement of a mature component reached an official slot unsoaked (Run 2)
- **Pattern:** a subagent built a custom TLS edge proxy to replace nginx.
  Its own verdict: proxy mode "not worth it" (missed the ≥10 % adoption
  threshold, 4 % more CPU per handshake). The driver deployed it anyway for
  a side feature whose score effect was inferred from a latency
  micro-benchmark, and the switch ran unattended right after the previous
  result. Official run: **0 points** (67 errors: truncated bodies,
  `unexpected EOF`), proxy RSS 2.3 GB → OOM, one host unreachable for
  6 min until a cloud-API reboot. After a 45-min fix, the retry still ended
  with 5 decode errors and 1.9 GB RSS; abandoned.
- **Why tests missed it:** validation was 20-second pseudo-bench loads with
  no client cancellations (h2 `RST_STREAM`), few idle connections, and less
  than bench concurrency. The bugs were exactly there: an in-flight counter
  not decremented on cancel, and closing without lingering so an RST
  discarded the tail of a response.
- **Impact:** 2 of ~14 official slots, a 0-score run, a host outage, ~2
  agent-hours.
- **Fix:** respect the adoption threshold the agent set. A replacement for
  nginx / a proxy / a runtime must pass a **soak gate** before any official
  slot: duration ≥ one bench run, concurrency ≥ the bench's, ~2 % client
  cancellations, long idle connections, RSS flat. Build the shadow-stack
  preflight and an auto-revert guard ("after run N: revert on any error")
  **before** the first risky swap, not after the failure.

### B18. Test load on a host that serves the bench (Run 2)
- **Pattern:** the pseudo-bench and oracle containers lived on the third
  host. A topology change put that host into the TLS-termination path; the
  next official run had the pseudo-bench burning 200 % CPU on it (seen
  only afterwards: that host slow 5–25 s). The lock was added after the
  fact; the human then ordered load generation moved to the local machine
  via a security-group rule scoped to the local IP. Locally, `ulimit -n
  1024` and the home router's NAT dropped SYNs until workers were capped.
  The scoped rule was later found still open by the supervisor.
- **Fix:** every topology change re-checks which hosts serve traffic and
  evicts test workloads from them. Generators and oracles live off the
  request path; if every host serves, run them from the local machine
  through a scoped firewall rule that is logged in `NOTES.md` for cleanup,
  with `ulimit -n` raised and a connection cap.

### B19. Deploy defaults silently undid tuning (Run 2)
- **Pattern:** the deploy Makefile had `NET_TUNE ?= off`, so every partial
  redeploy (nginx only) turned IRQ pinning off on two hosts. Found ~1.5 h
  later. The per-run deployed-state record listed some flags but not this
  one, so the affected official runs could not be identified. Separately,
  an app-only deploy printed `tls_lb=0` — flag metadata, not host state.
- **Fix:** defaults equal the current best configuration; experiments are
  explicit flags. The deployed-state record is read **from the hosts**
  (live units, sysctl, iptables, binary hashes), covering every toggle.

### B20. Approvals relayed by another session (Run 2)
- **Pattern:** the human told the supervisor session it could pass
  messages to the driver. It relayed the human's conditional approval to
  trust a test signing key in production; the driver's classifier denied
  the action (`[Security Weaken]`) because the human had not typed it in
  that session. The driver correctly withdrew and used a shadow stack on
  alternate ports instead.
- **Fix:** gray-zone or security-relevant approvals are typed by the human
  in the driver session, or recorded in `NOTES.md` policy before start. A
  supervisor relays facts, never consent.

### B21. Aggregate metrics hid the cause (Run 2)
- **Pattern:** the driver explained "ranking > 1 s" as "the app steals CPU
  from nginx". Asked to verify, it bucketed latency per 5 s per front host:
  everything was fine for 25 s, then slow everywhere — whole-host CPU
  saturation on the TLS terminator; a whole-run p99 of 48 ms on another
  endpoint had hidden it. Separately, a TLS session-ticket check made
  *through* the DNAT front reached a host not yet reloaded and put a wrong
  conclusion into `NOTES.md`.
- **Fix:** verify hypotheses with time-bucketed percentiles per front host;
  compare the same upstream reached through different fronts to separate
  front from app. Verify config per host directly, never through the LB.

### B22. A rule in the skill that no tool enforced (Run 3)
- **Pattern:** this skill was installed and said "every official run is
  fully instrumented" and "lopsided hosts first". `node-metrics.sh` was
  copied into the contest repo at T+17 min. It was never called from the
  bench wrapper. Its first per-host CPU table came 5 hours later.
- **Impact:** the main structural fault (B23) went unseen for most of the
  contest. The same loss as Run 2.
- **Detection:** the score log has no per-host columns, and the bench
  wrapper does not reference the metrics script.
- **Fix:** the official-run wrapper takes the metrics and refuses to append
  a score row without them (BENCH-LOOP). Rules that matter must live in a
  script, a hook or a required column, not only in prose.

### B23. All writes funneled to the weakest host; knobs fought over it (Run 3)
- **Pattern:** forwarding every write to one master host (2 vCPU) was right
  early: 3.4k → 7.6k, removing ~100 ms per SQL from remote regions. It stayed
  the topology all day. Later the master also ran the replication push,
  signing and heavy reads. The DB host (2 vCPU) carried the DB, offloaded
  image validation and cache misses. From T+3h, every priority/slot/fairness
  knob moved score between regions without raising the total (≥ 5 times).
- **Impact:** peak-day light writes (login, friend request, post) all
  exceeded 1 s. Per-user-day score stayed ≈ 30–54 against the leader's
  ≈ 70–80, while user growth was already near its cap. The plateau from T+6h
  was this wall.
- **Detection:** a seesaw result twice in a row; one host pegged while
  others idle.
- **Fix:** STRATEGY-LOOP §1–§3. Move work onto idle hosts. Re-open topology
  options that keep writes in-region (`designing-isucon-architecture`,
  multi-region block).

### B24. Option rejected on a latency-only rating with a wrong capacity premise (Run 3)
- **Pattern:** at T+3h an analysis rated region-local writes as "+2–3 %,
  8–12 h, do not start". The rating counted RTT saved per writer only. It
  dismissed capacity with "the master's CPU wall is home-region load". In
  fact the master also processed every forwarded write. The same hour, the
  first seesaw result arrived. Nobody linked the two.
- **Impact:** the only design that removed the wall was never built. After
  the contest, the human rebuilt the idea in minutes: commit in-region, push
  bodies only to regions that can see them, wait for the ack writer-side.
- **Fix:** STRATEGY-LOOP §2 and §4. Two-axis rating; each rejection records
  its premises and an "overturned if" line, re-checked when a premise falls.

### B25. Estimates from scratch, uncalibrated, used as a veto (Run 3)
- **Pattern:** "8–12 h" for multi-primary regions. That day's logged
  features of the same size took 10–40 min from first commit to green tests,
  and 1.5–3.7 h to converge. Most listed components already existed
  (watermarks, ack push, a write path that is primary in memory,
  region-local images). The same document gave the incremental path an
  optimistic estimate. In the strategist session, the human said
  implementers were "several times faster than you assume". The written
  rejection stayed.
- **Impact:** a 2–4 h project was filed as impossible at T+3h20, with 4.5 h
  left.
- **Fix:** STRATEGY-LOOP §5. Velocity log, estimate by analog, delta not
  whole, and a 30-min flag-off spike instead of an estimate-only veto.

### B26. Stage 1 of a recommended plan built, merged and never run (Run 3)
- **Pattern:** the rejection document recommended stage 1 (sessions
  committed in-region, "60–90 min, +5–10k"). It was implemented during the
  writing of that document and merged flag-off 17 minutes later. It never got
  an official run.
- **Fix:** a staged plan is filed only after stage 1 has a run
  (STRATEGY-LOOP §6). The supervisor lists flag-off features with no run.

### B27. Many big bets, one landed (Run 3)
- **Pattern:** in parallel or in sequence: physical replicas (withdrawn at
  T+45 min, rightly), logical replication (FAIL, then half score), local WAL
  (FAIL, then −60k), full-history memory (4 FAILs of one type), a language
  port (hybrid for 3 endpoints only), a late 600k redesign (started T+7h).
  Only the write-behind path landed, at T+5h40. The breadth followed the
  human's "try everything" direction.
- **Impact:** integration load, environment-lock contention, FAIL slots, and
  no single redesign finished.
- **Fix:** STRATEGY-LOOP §9. At most two big bets, a kill date each; ask in
  §0 how many big bets may run and who may move the freeze.

### B28. Structural facts measured late (Run 3)
- **Pattern:** the growth multiplier was estimated at 1.5–1.75×/day at T+55
  min. It was really 2.6–2.9×, corrected at T+1h20. "The gap is
  per-user-day quality, not user count" came at T+3h45. Its cause (friend
  requests not committed inside the user's window, 77 % left pending) came at
  T+6h50, 35 min before the freeze. Cross-region locality was measured from
  the DB at T+7h.
- **Fix:** STRATEGY-LOOP §8. Score regression and data-locality queries in
  hours 1–2. The capacity owner re-derives the ceiling after each structural
  change.

### B29. Disk filled by an unbounded cache → three FAILs in a row (Run 3)
- **Pattern:** an image disk cache grew to 33 GB. The proxy could no longer
  buffer request bodies and returned 500 on uploads. That looked like an
  intermittent app bug and cost three runs of bisecting (TLS mode, a memory
  flag).
- **Fix:** every cache has a size cap from the start. `df` on all hosts is
  part of the post-run row. On an intermittent 5xx, check disk and memory
  first.

### B30. DB OOM-killed and the apps never came back (Run 3)
- **Pattern:** idle-connection retention plus a large `max_wal_size` → the
  DB was OOM-killed mid-run. systemd's `OOMPolicy=stop` stalled the stop, and
  crash recovery took 2 min 15 s. The three apps panicked while starting
  against the down DB, hit `StartLimitBurst` and stayed failed.
- **Fix:** DB `OOMPolicy=continue`; app `StartLimitIntervalSec=0`,
  `Restart=always`; a lower `OOMScoreAdjust` for the DB than for co-located
  apps; record the minimum `MemAvailable` per host in the run row.

## C. Supervising a running session

Moved to [SUPERVISING.md](SUPERVISING.md): what to watch, which alert rules
paid off and which were noise in two observed runs, reliable stall
detection, external health probes, and relaying facts (not consent).

## D. Practices that held (Run 3)

Keep these. They are why the 0-point outcomes never happened on the final run.

- **Differential oracle for a distributed read model:** the DB path, the
  primary's memory and a replica's memory were compared over a
  1,500-step write sequence (diff 0). Integrity FAILs ("post visible that must
  not be") were traced to a lease that a late heartbeat could extend. Bounding
  the lease by the sender's send time fixed it, with no feed errors after.
- **Fast withdrawal on evidence:** physical streaming replicas on the app
  hosts saturated their disk IOPS replaying WAL (16.9k → 9.2k). They were
  removed within ~35 min, with slots and watchdogs cleaned up.
- **Off-host error attribution:** 503s on the notification stream were
  absent from every host's access log. They correlated with total concurrent
  connections across hosts, which put the cause in a shared upstream proxy.
  Not chased further.
- **Flags, default off; a bare deploy is the best config.** Every experiment
  sat behind a flag. The deploy script's defaults were promoted only after
  a win. A tagged fallback commit stayed deployable to the end.
- **Final procedure decided in advance:** freeze time; final = the last run.
  Stop rule: "pass and ≥ X → stop; else one more before T−10". Fallback
  commit if the candidate FAILs. Reboot all hosts at once, then hash data
  (rows + image store) against the pre-reboot snapshot. A read-only
  `final-check.sh` (pending restarts, slots, temporary FW rules, disk,
  profilers off). E2E and browser checks before the final run, never during
  a run. One run with access logs and profilers off. Leftover sweep (SG never
  touched, no ssh/tcpdump/socat left).
- **Every run recorded** (commit, flags, per-region counts, finalist passes,
  errors) in `NOTES.md` in Japanese. The post-mortem was possible only
  because of this.
- **Supervisor caught outward actions:** a portal question sent without
  approval led to a memory rule ("no portal questions without the human").
  The supervisor learned to route gray-zone items to the human, never through
  the peer.
