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
- **Fix:** worktree isolation, no-amend rule, `flock` around deploy+bench.

### B4. Single-run decisions
- **Pattern:** identical-code runs ranged 259k–326k (±12 %). The agent did
  re-run before reverting — good — but had no recorded band, so each
  decision was ad hoc.
- **Fix:** 3 runs on one commit early → band in `NOTES.md`.

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
- **Detect:** poll the session's status (`ListAgents`, or the session state
  file's `status` / `waitingFor`) — not transcript growth alone.
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

## C. Supervising a running session

When watching another agent session (e.g. tailing its transcript JSONL),
alert only on: session status `idle` before the deadline (B10), `waiting` / `input needed` (B8 — check the
status itself, transcript silence alone misses it), practice-only affordance use (A*), amend/reset/force-push,
reboot of more than one host, stopping ssh/cloud agents, `pass=false`
without a revert within one run, no transcript growth for 5+ min while
busy. Read-only exploration and in-repo edits are noise — reporting them
trained the user to ignore the supervisor within minutes.
