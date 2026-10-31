# Strategy Loop: Capacity, Estimates, Rejections

The bench loop (§2) decides *whether a change won*. This loop decides *which
change to build next*. It comes from a real 8-hour contest (Run 3 in
[OBSERVED-BARRIERS.md](OBSERVED-BARRIERS.md)). The agent there implemented
fast and kept the final run safe. It still finished at a third of the
leader's score, because of five decision habits:

| Habit | What it cost |
|---|---|
| Architecture options rated by latency only | Region sharding was rejected at T+3h ("+2–3 %"). Its real value was moving writes off the one saturated host. |
| No per-host capacity view until T+5h | Two hosts were at 91–100 % CPU and two at 10–25 %, all day. The cause was unseen. |
| Zero-sum knob results read as noise | Five priority/slot experiments traded score between regions, and the agent kept tuning knobs. |
| Estimates written from scratch, never calibrated | "8–12 h" for work whose parts took 10–40 min each. That estimate was the reason for the rejection. |
| Single-run adopt/reject in a ±5–10 % band | The write-behind path was rejected twice on single runs, then became the best late gain (+15k). |

Everything below is mechanics. Put them in `NOTES.md` and the wrappers, not in
memory.

## 1. Capacity ledger (every official run)

One row per run in the score log, next to the score:

```
job  score  host1_idle  host2_idle  host3_idle  host4_idle  busiest_proc(host)  egress/allowance
```

- Take it from `node-metrics.sh start|stop` around the run (see
  `tuning-isucon-linux-and-nginx`). The official-run wrapper must refuse to
  log a score without these columns ([BENCH-LOOP.md](BENCH-LOOP.md)). In
  Run 3 the script was copied in at T+17 min and never called. The first
  per-host table appeared at T+5h13, on the human's question.
- **Lopsided for 2 runs** (one host < 10 % idle, another > 50 %) → the next
  design step moves work onto the idle host. Do not tune the saturated host
  further.
- Name the busiest process per host (app / proxy / DB / softirq). "App 94 %,
  nginx 33 % (sys 25), softirq 10 %" told more than the score did.

## 2. Rate every design option on two axes

| Axis | Question |
|---|---|
| Latency | How many RTTs and how much queueing does the critical request pay? |
| **Capacity** | Which host's CPU / IOPS / NIC does this work land on, and how much headroom does that host have? |

Write both axes, with the capacity ledger attached, into any document that
rejects an option. Run 3's sharding analysis did consider capacity. It
dismissed it with a wrong premise: "the write master's load is home-region
users". The master was also processing every forwarded write from the other
regions, plus the replication push to them. Check each capacity premise
against the ledger before relying on it.

## 3. Seesaw rule

Sometimes a knob that prioritizes one class (region, request type, slot pool)
raises it and lowers another by about the same amount. That is a
fixed-capacity signature, not noise.

- **Two seesaw results → stop the knob family.** Next: a design that moves
  work off the shared resource (§1, §2).
- Run 3 saw it at least 5 times between T+3h and T+7h (priority forwarding,
  local slot size, post slots, a fairness gate). The grand-final passes summed
  to ~1,000–1,200 whichever way the capacity was split.

## 4. Rejection log with overturn conditions

Each rejected option gets one line in `NOTES.md`:

```
option | rejected at | reason (premise) | overturned if ... | re-checked at
```

- Write premises as falsifiable facts: "write latency is dominated by
  implementation stalls, not architecture"; "capacity wall is home-region load".
- When a ledger row or experiment falsifies a premise, re-open the option in
  the same hour. Run 3's premises were falsified by later work (pipelining
  removed the stalls; the CPU table showed idle hosts). The rejection was never
  revisited.
- A rejection whose only reason is **time** is not a rejection: do §5's spike.

## 5. Velocity log and estimates by analog

Log every substantial feature:

```
feature | dispatched | first commit | tests green | first official run | decided (adopt/reject)
```

Observed in Run 3 (spans are first commit → tests, not dispatch → tests):

| Feature class | Code + tests | First run | Converged (adopted or rejected) |
|---|---|---|---|
| Distributed in-memory read model (push, lease, diff test) | ~25 min | +70 min | +1.7 h (lease fix) |
| Memory-primary write path, all writes, crash + parity tests | ~40 min | +1.3 h | **+3.7 h** (adopted, +15k) |
| Logical-replication model + watchdog | ~10 min | +30 min | +1.6 h (rejected) |
| Local fsync'd WAL + read barrier | ~11 min | +30 min | +1.4 h (rejected) |
| Audience-based image pre-push | ~20 min | +20 min | +20 min (adopted) |

- **Code is cheap; convergence is not.** Estimate a new feature from the
  closest logged one. Implementation ≈ analog. Add ×2–3 for the debug/bench
  tail.
- **Estimate the delta, not the whole.** List each component as `new` /
  `extends X` / `reuses X`. Run 3's "8–12 h" for multi-primary regions counted
  per-region WAL, the vector watermark, the ack path and region-local images as
  new work. All four already existed in some form.
- Estimates bias toward the current path. The same document gave the
  incremental path "90–150 min, +50–120k" (it took hours, for about half
  that) and the new topology "8–12 h". Compare both against the velocity log.
- **An estimate never rejects alone.** If time is the only objection, build a
  30-minute flag-off minimal version and spend one run on it.

## 6. Staged plans: run step 1 before filing the plan

A plan with stages ("first sessions in-region, then own posts, then the
rest") is filed only after stage 1 has one official run. In Run 3, stage 1
was recommended as "60–90 min, +5–10k". It was implemented while the plan was
being written and merged flag-off 17 minutes later. It never got a run. That
was the cheapest test of the whole direction.

## 7. Replicates, not single runs

- Measure the band in hour 2: three runs of one commit. Run 3's band: ±5–10k
  around 165k.
- Adopt or reject only when |Δ| > band, or when two runs agree. A change that
  removes a known bottleneck (lock, serialization) gets a second run even if
  the first lost.
- One knob per run. Multi-knob runs (three knobs, −20k) could not be
  attributed and cost a re-run of each knob anyway.
- Four FAILs of the same type in a row on one feature → stop that feature
  after the second, unless the root cause is identified.

## 8. Look for structure early (hour 1–2)

- **Data locality from the seed data**: who reads whose writes, and across
  which partitions (cross-region friendships, visibility modes, follower
  fan-out). Run 3 measured this at T+7h. At T+30 min it would have shown that
  ~90 % of one region's writes have no remote reader.
- **Score model**: fit the score against the per-run counts the bench log
  exposes. In Run 3, `score ≈ a × user-days + b × finalists + c × finalist
  passes` gave R² 0.987. Splitting *count* (growth per day, near the cap) from
  *quality per user-day* (≈30 vs the leader's ≈70–80) shows which one to
  attack.
- **Generalize patterns already in the code.** One kind of data already had
  "push only to regions that can see it". The same shape applied to all
  writes was the missing topology.

## 9. Breadth vs depth

- At most **two concurrent big bets** (topology, persistence redesign,
  language port). Each gets an owner, a velocity-log row, a stage-1 run date
  and a kill date. Finish or kill one before opening a third. Run 3 had about
  six (physical replica, logical replication, WAL, full-history memory,
  language port, a late redesign). One landed.
- Assign one subagent the **capacity/topology owner** role: it owns §1–§3 and
  re-reads the rejection log every hour. Run 3 had many analysts working on
  score limits and none on host resources.
- If the human pushes for "try everything", turn it into a ranked bet list
  with the caps above. Ask in §0 policy how many big bets may run at once and
  who may move the freeze. Run 3 moved its freeze 4 times.

## 10. Counterfactual discipline

When writing the post-mortem or a mid-contest re-plan, tag what is
*hypothesis* ("if write-behind had been the baseline by T+3h and heavy reads
had left the master, the wall would have come later"). Do not attribute
methods to other teams from scoreboard shapes. Run 3's own decomposition of
the leader's score was later refuted by access-log counts.
