# Supervising a Running Contest Session

How a second Claude Code session watches the contest (driver) session without
becoming noise. Distilled from a monitor that ran beside an 8-hour practice
run; counts below come from that run. Barrier IDs refer to
[OBSERVED-BARRIERS.md](OBSERVED-BARRIERS.md).

The supervisor's job is narrow: **notice lost time early** (stalls, outages,
denials) and **catch rule breaks** before they become the score. It is not a
second driver.

## 1. What to watch

- Every transcript of the driver session, subagents included:
  - `~/.claude/projects/<project-dir>/<session-id>.jsonl` (driver)
  - `~/.claude/projects/<project-dir>/<session-id>/subagents/*.jsonl`
  - Glob `**/*.jsonl` under the project dir and exclude your own session id;
    new subagents appear mid-run.
- Tail by byte offset, consume only complete lines (up to the last `\n`), and
  **persist offsets to a file** every pass. A `Monitor` watch expires (30 min
  observed; re-armed 23 times in one run) — on re-arm the watcher resumes
  from the saved offsets and loses nothing. First start with no offsets file:
  start at EOF, not at byte 0, or the backlog floods the session.
- Keep a plain activity log (tool calls, texts, user messages, tool errors,
  truncated) next to the offsets. `grep` on it answers "when did X happen"
  faster than re-reading JSONL.
- A side `status` script for on-demand snapshots: commits on all branches in
  the last hours, worktrees, the official score log, and the last assistant
  text per agent (`jq` over each JSONL).

## 2. Signal rules

Observed: ~14 HIGH toasts, **zero** real violations. 44 of 220 supervisor
replies in the session were "no issue". Every false positive trains the human
to ignore the supervisor — in the first observed run that took minutes.

Worth alerting on from the first run (low volume, all real at least once):
status `waiting` / input needed (B8), turn end before the deadline (B10, §3),
practice-only affordance use (A*), amend/reset/force-push, reboot of more than
one host, stopping ssh/cloud agents, `pass=false` without a revert within one
run. Read-only exploration and in-repo edits are noise.

### Match only what executes

- Scan **only** `Bash.command` and `file_path` of `Write`/`Edit`.
- Never scan Agent/SendMessage prompts, handbacks, written file content, or
  tool output. Observed false positives from doing so:

| Rule | Hits | Real | Why it fired |
|---|---|---|---|
| benchmarker-source access | 5 | 0 | a subagent prompt *forbidding* it; the agent's own client code; a log path |
| reboot / network-attribute / `rm -r` | several | 0 | the words inside `NOTES.md`, handbacks, `/tmp` scratch |
| outbound POST | 18 | 0 | all to localhost or the team's own hosts |
| initial-data modification | 16 | 0 | all read-only commands |
| "permission" substring in tool errors | many | — | unrelated errors |
| SPAWN with empty description | many | — | no information |

- Allow-list own hosts and private ranges before flagging network egress;
  require a write verb before flagging protected paths.

### Toast (interrupt the human) only on

1. **Classifier / permission denials** — a `tool_result` with `is_error` whose
   text says the action was denied by the auto-mode classifier. These were the
   only real violations caught. Extract the bracketed reason code. Observed:
   `[Self-Modification]` (agent writing its own `.claude/settings.json` — B16),
   `[Production Reads]` (inspecting the bench host — A3),
   `[Code from External]` (downloading a tool binary),
   `[Remote Shell Writes]` (subagent running a host-writing script outside its
   remit), `[Security Weaken]` (B20).
2. **Official result** — a new FAIL or PASS line in the score log.
3. **External health state change** (§4).
4. **Stall**: turn ended while time remains and the bench queue is empty (§3).

Everything else goes to the supervisor session as a low-priority line or a
15-min digest (tool counts, error count, latest agent text). Dedupe toasts by
(rule, matched text).

### Read by hand instead

Read every Agent prompt and every handback yourself. This caught what no regex
did: a crypto-weakening plan, a plan to add a backdoor key to production auth,
and a port collision between a new component and an existing one. Check each
prompt for: scope creep onto shared hosts (B18), unsoaked replacement of a
mature component on the request path (B17), deploy steps that reset tuning
(B19), and missing deadline / revert rule.

## 3. Stall detection

What failed: a 15-min "no transcript growth" alert fired, `ListAgents` showed
status `shell` (a background enqueue task existed), so the supervisor ruled
"not stopped". It toasted only 15 min later; the human acted ~33 min after the
first alert. Both `shell` and `idle` mislead: a live background task may never
wake the turn, and `idle` looks like "done" (B10, B16).

Declare a stall only when **all** hold:

- The driver's last transcript record is the turn-end record
  (`"type":"system","subtype":"turn_duration"`; it also carries
  `pendingBackgroundAgentCount`).
- No later `user` record (human message, hook re-prompt, task notification).
- No live background task or subagent that will wake the turn on completion.
- Bench queue is empty (nothing will return a result).
- Time remains before `END:`.

Toast once on entry; clear when a new user record appears. Separately, alert
when the deploy+measure lock is held longer than 2× a normal run (a run that
hung on a broken build).

**Attribute causes only from transcript evidence.** The supervisor blamed a
cloud-credential expiry; the expiry error first appeared *after* the human
resumed the session. The real cause was a plain turn end. State the last
record and its timestamp; let the human infer.

## 4. External health and bench-host load

Start a health probe at **minute 0**, not after the first outage (the first
outage in the observed run preceded the probe by over an hour).

- Every 30 s: N requests to a cheap authenticated or static endpoint through
  the **public front IP** (`curl --resolve <host>:443:<front-ip>`), plus
  `ssh -o BatchMode=yes -o ConnectTimeout=8 <host> true` per host, each under
  `timeout`, stdin from `/dev/null`.
- Emit only on **state change** (`external=8/8 h1:ok h2:ok h3:ok` →
  `external=6/8 … h3:NG`). Toast on any degradation.
- Check the deployed build at run start, not at enqueue: a delayed queue ran
  the official bench on an experimental build left on the hosts.
- Bench-host load (A3, A8): read it from cloud metrics (e.g. CloudWatch
  `CPUUtilization`, NIC allowance-exceeded counters) — never `ssh` to the bench
  host. One check showed the client was not the ceiling without touching it.

## 5. Relaying

- **A supervisor relays facts, never consent.** The human told the supervisor
  "you may tell the driver via SendMessage". A relayed port-conflict warning
  was acted on. A relayed *approval* to enable a test key in production auth
  was denied by the driver's classifier as `[Security Weaken]`: the human had
  not typed it in the driver session (B20). The driver routed around it on a
  shadow stack.
- Approvals for gray-zone or security-weakening steps are typed by the human in
  the driver session, or pre-approved in `NOTES.md` before minute 0. When one
  is needed, toast the human with the exact sentence to type.
- Relayed messages: one fact, one suggested action, the evidence (timestamp,
  command). No style feedback, no "looks good".
- **Never route outward actions through the peer.** In Run 3 the supervisor
  suggested the driver "ask the organizers" about a gray zone. The driver
  submitted a portal question on its own, and the human objected. Phrase
  gray-zone findings as "ask the human". Toast the human a draft question.
- **Tag hypotheses; verify before relaying.** The supervisor relayed
  "reaction/comment volume is the biggest quality gap". A DB analysis then
  showed that volume is fixed by the bench's internal rate. Relay facts
  untagged and guesses tagged, with the check that would settle them.

- **Leftover sweep** at T−90 and at the end: temporary firewall /
  security-group rules (a rule admitting the local IP for synthetic load was
  still open at the end and was revoked by the supervisor's check), stray
  services and ports from shadow stacks, experiment sysctls, extra instances,
  locks still held. Compare against what the session logged in `NOTES.md`.

## 6. Watcher sketch

Run under `Monitor` (each stdout line is an event); re-arm on expiry. All
names are placeholders.

```python
#!/usr/bin/env python3
import glob, json, os, re, subprocess, time
PROJ  = os.path.expanduser("~/.claude/projects/<project-dir>")
SELF  = "<supervisor-session-id>"
STATE = "<scratch>/offsets.json"
TOAST = "<scratch>/notify.sh"          # title, body -> desktop/phone

RULES = [  # applied to Bash.command and file_path only
  ("HIGH", "destructive git",  r"git push[^|;]*(--force|-f\b)|git reset --hard|--no-verify"),
  ("HIGH", "env up/down",      r"<env-cli> (up|down)|terminate-instances|run-instances"),
  ("HIGH", "multi-host reboot", r"reboot-instances|stop-instances"),
  ("MED",  "bench host shell", r"(ssh|scp|rsync)[^|;]*\b<bench-host>\b"),
]
CRE = [(l, n, re.compile(r, re.I)) for l, n, r in RULES]
DENY = re.compile(r"denied by .*classifier\. Reason: (\[[^\]]+\])")

def toast(t, b): subprocess.Popen([TOAST, t, b[:200]])
def emit(s): print(s, flush=True)

try: off = json.load(open(STATE))
except Exception: off = {}
first, seen, last_main = not off, set(), None

def handle(path, o):
    global last_main
    sub = "/subagents/" in path
    if not sub: last_main = o                     # for stall check
    msg = o.get("message") or {}; c = msg.get("content")
    if o.get("type") == "user" and isinstance(c, list):
        for r in c:
            if r.get("type") == "tool_result" and r.get("is_error"):
                m = DENY.search(json.dumps(r.get("content"), ensure_ascii=False))
                if m: emit(f"DENY {m[1]}"); toast("classifier denial", m[1])
    elif o.get("type") == "assistant" and isinstance(c, list):
        for u in c:
            if u.get("type") != "tool_use": continue
            i = u.get("input") or {}
            if u["name"] in ("Agent", "SendMessage"):
                emit(f"READ-BY-HAND {u['name']}: {i.get('description','')}"); continue
            scan = i.get("command", "") if u["name"] == "Bash" else i.get("file_path", "")
            for lvl, name, rx in CRE:
                if (m := rx.search(scan)):
                    emit(f"{lvl} {name}: {scan[max(0,m.start()-60):m.end()+60]}")
                    if lvl == "HIGH" and (name, m[0]) not in seen:
                        seen.add((name, m[0])); toast(name, m[0])

def bench_queue_empty(): ...   # problem-specific: portal status / lock file
def time_left(): ...           # seconds until END: in NOTES.md

def stalled():  # see §3
    return (last_main and last_main.get("subtype") == "turn_duration"
            and not last_main.get("pendingBackgroundAgentCount")
            and bench_queue_empty() and time_left() > 0)

while True:
    for p in glob.glob(PROJ + "/**/*.jsonl", recursive=True):
        if SELF in p: continue
        sz = os.path.getsize(p); o = off.get(p, sz if first else 0)
        if sz < o: o = 0
        if sz > o:
            with open(p, "rb") as f: f.seek(o); data = f.read()
            nl = data.rfind(b"\n")
            if nl >= 0:
                for ln in data[:nl + 1].splitlines():
                    try: handle(p, json.loads(ln))
                    except Exception: pass
                o += nl + 1
        off[p] = o
    first = False
    json.dump(off, open(STATE, "w"))
    # stall: toast once on entry, reset when a new user record arrives
    time.sleep(3)
```

Add a score-log tail (toast on new FAIL/PASS) and the §4 health loop as
separate `Monitor` watches so one crash does not silence the others.

## 7. Strategic review (Run 3)

Correctness and safety alerts were not the gap in Run 3. Strategy was. In
addition to §1–§5, the supervisor:

- **Asks for the per-host CPU table after every official run** if the score
  log lacks it. In Run 3 the first one came at T+5h13, from a human question
  to the supervisor. It showed two hosts pegged and two at 10–25 %.
- **Reads every rejection document and every estimate.** It checks the
  capacity premises against the ledger. It compares the estimates with the
  velocity log (STRATEGY-LOOP §4–§5). It challenges a "do not start"
  backed by time alone.
- **Lists flag-off features that never had an official run.** A built stage
  1 of the best idea sat merged and unrun for 4.5 hours (B26).
- **Flags seesaw results** (STRATEGY-LOOP §3) as a topology signal, not as
  noise.
- Follows the human's risk policy for alerts. With "only the final score
  matters", mid-contest FAILs are not toast-worthy, and advising a revert
  "to restore the leaderboard" was wrong. Toast only final-run, regulation
  or disqualification risks. Ask for this policy in §0.
