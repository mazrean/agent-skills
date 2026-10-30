# Harness Setup: Make Stalls Impossible, Not Discouraged

The two largest observed losses — a blocking question that waited 48 min
for an absent human (B8), and the driver declaring victory and ending its
turn with hours left, twice, the second time *after* the user re-prompted
"push past the limit" (B10) — were not fixed by prose. Enforce them in the
Claude Code harness of the contest session, before minute 0 — **installed by
the human**. Under auto mode the agent's own write to `.claude/settings.json`
is denied as `[Self-Modification]`; in the second observed run the agent hit
that denial at minute 9, carried on without a hook, and lost ~2 h to turn
ends (OBSERVED-BARRIERS B16).

## Project `.claude/settings.json` for the contest repo

```json
{
  "permissions": {
    "deny": ["AskUserQuestion"],
    "allow": [
      "Bash(ssh *)", "Bash(scp *)", "Bash(rsync *)",
      "Bash(make *)", "Bash(git *)", "Bash(go *)",
      "Bash(curl *)", "Bash(jq *)",
      "Bash(scripts/env-run.sh *)", "Bash(scripts/official-run.sh *)",
      "Bash(scripts/portal-bench.sh *)", "Bash(scripts/node-metrics.sh *)",
      "Read", "Edit", "Write"
    ]
  },
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command",
                     "command": "$CLAUDE_PROJECT_DIR/scripts/contest-stop-hook.sh" } ] }
    ],
    "Notification": [
      { "matcher": "permission_prompt|idle_prompt",
        "hooks": [ { "type": "command",
                     "command": "notify-send 'ISUCON agent' 'needs input'" } ] }
    ]
  }
}
```

- `deny: ["AskUserQuestion"]` removes the tool from the agent's context, so
  it *cannot* block on a multiple-choice question; it has to pick a default
  and continue (SKILL.md §0). Questions go into `NOTES.md` instead.
- Tighten or widen `allow` to the contest's actual tools (cloud CLI for
  reboots, etc.). Anything not allowed will still raise a prompt — the
  Notification hook is the backstop for that.
- Replace `notify-send` with whatever reaches the human (a phone push
  service, a chat webhook, a WSL → Windows toast). `Notification` hooks
  cannot block; they are side effects only.

## Stop hook: `scripts/contest-stop-hook.sh`

Copy [`../scripts/contest-stop-hook.sh`](../scripts/contest-stop-hook.sh)
into the contest repo. Behaviour:

- Reads the end time from `$ISUCON_END` or a line `END: <time>` in
  `NOTES.md` (anything `date -d` parses, e.g. `END: 2026-12-07 18:00`).
- While time remains, prints `{"decision":"block","reason":"…N min
  left… take the next backlog item…"}` so the turn continues.
- Allows the stop after the end time, when no end time is set, or when a
  `STOP_OK` file exists in the project root (the escape hatch the human,
  or the agent on the human's explicit instruction, creates).

Verified in a throwaway headless session: told "do backlog item 1 only,
then stop", the agent was re-prompted by the hook and continued through
the backlog. When the backlog ran out it invented busywork — so keep
`NOTES.md` stocked with a ranked hypothesis backlog, and the reason text
tells it to re-measure and add items rather than stop.

Notes:

- The hook input carries `stop_hook_active` (true when the previous stop
  was already blocked). This hook deliberately ignores it: in a contest,
  repeated re-prompting is the point. Per the Claude Code docs the harness
  stops honouring a Stop hook after a run of consecutive blocks with no
  work in between, so a truly stuck agent still surfaces.
- Pair it with a supervisor or the Notification hook: the hook keeps the
  agent busy, it does not make the work good.

## Pre-approving the plan's risky steps

The auto-mode classifier enforces its own rules; in the observed runs it
denied, among others: `[Self-Modification]` (editing the session's own
settings), `[Production Reads]` (inspecting the bench host),
`[Code from External]` (downloading a tool), `[Remote Shell Writes]` (a
subagent running host-writing scripts), `[Security Weaken]` (trusting a test
signing key in production). Anything the plan needs goes into `allow` as an
exact script path, or is planned for the driver; an approval relayed by
another session does not count.

## Session start checklist

1. `NOTES.md` has `END:`, the gray-zone policy answers, and a backlog.
2. **The human** has put `.claude/settings.json` above in place and restarted
   the session so it loads. The agent verifies by reading the settings
   file and, if anything is missing, notifies the human instead of writing it.
3. Send a test notification (`echo '{}' | <your notify command>`) and
   confirm it arrives.
4. Run `echo '{"cwd":"'$PWD'"}' | scripts/contest-stop-hook.sh` — it must
   print a `block` decision while the contest is running.
