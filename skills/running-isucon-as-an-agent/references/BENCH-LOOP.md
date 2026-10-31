# Environment Lock, Official Runs, and the Subagent Preamble

Two scripts for the contest repo. Both share one lock over the **environment**
(the 2–3 contest hosts): whoever holds it owns what is deployed.

- `scripts/env-run.sh` — any agent: deploy *its own* commit, run one local
  measurement (synthetic load, profiler, smoke test), release. Per run, never
  per sweep.
- `scripts/official-run.sh` — **driver only**: deploy, enqueue on the portal,
  wait for the result with per-host counters, log the score.

Copy `assets/net/node-metrics.sh` from `tuning-isucon-linux-and-nginx` to
`scripts/node-metrics.sh` and `export HOSTS="isu1 isu2 isu3"` (ssh aliases)
before using `official-run.sh`.

The environment stays locked while an official job waits in the portal queue
(the deployed state must not change under the benchmark), so enqueue only
when a batch is ready and let subagents do non-environment work meanwhile.

With a long queue (30 min was emulated in the second run) that rule freezes
the environment for most of the day. The amendment that worked, if the portal
allows a pending job: keep one job pending; the lock protects the **candidate
state**, and only the driver redeploys it, each redeploy preflighted (shadow
stack check + short load) so whatever is live when the job starts is
coherent; record the deployed state when the portal status flips to running,
not at enqueue; other agents' `env-run.sh` is forbidden while a job is pending
unless the portal exposes an ETA with ample margin. The candidate was the
unsoaked proxy in the one 0-point run of that day — preflight is the part that
cannot be skipped. A practice emulator must mirror the real portal (usually one
job per team, no exact start time), or this habit will not transfer.

## `scripts/env-run.sh`

```bash
#!/usr/bin/env bash
# usage: scripts/env-run.sh "<note>" <measure command...>
#   Deploys this worktree's HEAD, runs the command, logs, releases. Exit 75 = lock busy.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
NOTE=$1; shift
LOCK=${LOCK:-/tmp/isucon/env.lock}
RUNS=${RUNS:-/tmp/isucon/RUNS.tsv}          # shared by all worktrees
LOCK_WAIT=${LOCK_WAIT:-120}                 # seconds; on timeout do other work
DEPLOY_CMD=${DEPLOY_CMD:-make deploy}
BUILD_ID_CMD=${BUILD_ID_CMD:-"ssh -o BatchMode=yes isu2 sha1sum /home/isucon/webapp/app </dev/null | cut -c1-12"}
mkdir -p "${LOCK%/*}" "${RUNS%/*}"

[[ -z $(git status --porcelain --untracked-files=no) ]] || { echo "dirty tree: commit first" >&2; exit 2; }
exec 9>"$LOCK"
flock -w "$LOCK_WAIT" 9 || { echo "env busy (held by: $(cat "$LOCK.owner" 2>/dev/null))" >&2; exit 75; }
echo "$(date +%T) $(git rev-parse --short HEAD) $NOTE" >| "$LOCK.owner"

dlog="${RUNS%/*}/deploy.$$.log"
$DEPLOY_CMD >"$dlog" 2>&1 || { tail -20 "$dlog"; exit 4; }
build=$(bash -c "$BUILD_ID_CMD" 2>/dev/null || echo "?")
out=$(timeout "${RUN_TIMEOUT:-600}" "$@" 2>&1 || true)
printf '%s\t%s\t%s\t%s\t%s\n' "$(date +%T)" "$(git rev-parse --short HEAD)" "$build" "$NOTE" \
  "$(tr '\n' ' ' <<<"$out" | cut -c1-400)" >>"$RUNS"
echo "$out"
```

The deploy script must reset **all** host state it owns (binaries, configs,
systemd drop-ins, sysctl, iptables) so the next holder measures exactly its
own commit. Anything an experiment changes outside the deploy script is undone
in the experiment's own `trap ... EXIT` before the lock is released.

## `scripts/official-run.sh` (driver only)

```bash
#!/usr/bin/env bash
# usage: scripts/official-run.sh "<what this batch contains>"
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
NOTE=${1:-}
LOCK=${LOCK:-/tmp/isucon/env.lock}
SCORES=${SCORES:-/tmp/isucon/SCORES.tsv}
DEPLOY_CMD=${DEPLOY_CMD:-make deploy}
BENCH_CMD=${BENCH_CMD:-scripts/portal-bench.sh run}     # PORTAL-BENCH.md
METRICS=${METRICS:-scripts/node-metrics.sh}             # from tuning-isucon-linux-and-nginx
HOSTS=${HOSTS:?export HOSTS="isu1 isu2 isu3" (ssh aliases) for node-metrics.sh}
LOG_DIR=${LOG_DIR:-logs}
mkdir -p "${LOCK%/*}" "$LOG_DIR"
[[ -f $SCORES ]] || printf 'time\tcommit\tscore\tpass\terrors\tidle_per_host\tnote\n' >"$SCORES"

parse_idle() { # stdin: node-metrics.sh stop output (host usr% sys% soft% idle% ...) -> "isu1=12.3 isu2=..."
  awk 'NR>1 && NF>=5 {printf "%s=%s ", $1, $5}'
}
parse_result() { # stdin: bench output -> "score<TAB>pass<TAB>errors" (adapt to the contest's format)
  grep -E 'pass=(true|false)' | tail -1 |
    sed -E 's/.*pass=(true|false).*スコア=([0-9]+).*種別エラー数=(map\[[^]]*\]).*/\2\t\1\t\3/'
}

[[ -z $(git status --porcelain --untracked-files=no) ]] || { echo "dirty tree" >&2; exit 2; }
commit=$(git rev-parse --short HEAD)
out="$LOG_DIR/official-$(date +%H%M%S)-$commit.log"

exec 9>"$LOCK"; flock 9   # background children (watchdogs, sleepers) must exec 9>&- or they hold the lock
echo "$(date +%T) $commit OFFICIAL $NOTE" >| "$LOCK.owner"
$DEPLOY_CMD >"$out.deploy" 2>&1 || { echo "deploy failed: $out.deploy" >&2; exit 4; }
$METRICS start || { echo "metrics start failed: fix it, no uninstrumented official runs" >&2; exit 6; }
timeout "${BENCH_TIMEOUT:-3600}" $BENCH_CMD >"$out" 2>&1; rc=$?
$METRICS stop >"$out.metrics" 2>&1; cat "$out.metrics"
[[ $rc == 10 ]] && { echo "PORTAL_AUTH_EXPIRED: ask the human to log in again" >&2; exit 10; }

res=$(parse_result <"$out" || true)
[[ -n $res ]] || { echo "no result line in $out" >&2; exit 5; }
# capacity ledger: one idle% per host is required in the score row (STRATEGY-LOOP §1)
idle=$(parse_idle <"$out.metrics" || true)
[[ $(wc -w <<<"$idle") -ge $(wc -w <<<"$HOSTS") ]] || idle="NO-METRICS"
printf '%s\t%s\t%s\t%s\t%s\n' "$(date +%T)" "$commit" "$res" "$idle" "$NOTE" >>"$SCORES"
[[ $idle == NO-METRICS ]] && echo "WARN: score logged without per-host idle; fix before the next run" >&2
best=$(awk -F'\t' 'NR>1 && $4=="true"{if($3>b)b=$3} END{print b+0}' "$SCORES")
echo "RESULT commit=$commit $(tr '\t' ' ' <<<"$res") best=$best"
{ grep -oE 'CODE=[0-9]+' "$out" || true; } | sort | uniq -c | sort -rn
```

Run it in the background (it can wait a long time in the queue) and keep
working; read the result when the background task reports back.

## Reading results with few runs

- Compare `$out.metrics` (per-host CPU split, egress, allowance drops) with the
  previous official run before the score; it explains *why* the score moved.
- The wrapper, not the agent's memory, collects the metrics. In Run 3 the
  metrics script was in the repo all day but the wrapper never called it.
  Lopsided hosts stayed unseen for 5 hours (OBSERVED-BARRIERS B22). Per-host
  idle is a required score-log column, and `NO-METRICS` rows are a bug to fix
  before the next enqueue.
- Also log per run: the minimum `MemAvailable` and `df` use per host (an
  unbounded cache filled a disk and cost three FAILs; an OOM-killed DB cost
  one).
- A jump is real only after it repeats; a decay on unchanged code points to a
  resource budget (cloud NIC allowance / CPU credits).
- Any `CODE=` in two runs goes to `NOTES.md` as a tracked bug.

## Subagent preamble

Paste at the top of every subagent prompt; fill the brackets.

```text
Contest constraints (hard rules):
- Contest mode: no benchmarker source, no access to the bench host, no extra
  environments, never touch the portal or browser. Only the driver runs
  official benchmarks; ask for one by reporting a commit + the expected effect.
- Work in your own git worktree/branch. New commits only: never amend, reset,
  rebase, force-push, or touch other branches.
- You own: files [paths]; host-level areas [e.g. nginx on isu1]. Read anything.
- Use the environment only via scripts/env-run.sh "<note>" <command> (it deploys
  YOUR commit inside the lock). One run per call, never a whole sweep. Exit 75
  means busy (print that, never fail silently): do read-only work (code reading, profile analysis, preparing the
  next change) and retry later. Never deploy outside it.
- Anything you change on a host outside the deploy script must be undone by a
  trap before the lock is released.
- Load generators and oracles never run on a host that serves the bench
  (re-check after any topology change). Scratch state goes in your own
  mktemp -d, never a shared scratchpad path. New listeners: check the port
  registry in NOTES.md and ss -ltnp first.
- Before hand-off: git status clean (no untracked source files).
- Anything you add to NOTES.md is written in Japanese (commands and
  identifiers as-is).
- First report within 10 minutes: what your first measurement exposed
  (per-host idle%, connection churn, allowance drops) and the cheapest next
  step. Deep work (kernel, XDP, rewrites) only after that, time-boxed.
- Shell: non-interactive only (command cp -f, command rm -f, >|,
  ssh -o BatchMode=yes -o ConnectTimeout=10 ... </dev/null). Anything > 60 s
  runs in the background. Never pkill -f a pattern in your own command line.
- Never stop sshd, cloud agents, or networking; reboot at most one host at a
  time and confirm a new boot_id.
- Deadline: [time]. If your change does not clearly win by then, revert your
  host state and report.
- Finish with: commits (hash + measured numbers), what did not help, next
  hypothesis. ≤ 20 lines.
```
