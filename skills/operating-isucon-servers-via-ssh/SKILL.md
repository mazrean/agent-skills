---
name: operating-isucon-servers-via-ssh
description: Operates ISUCON contest servers via the isucon-ansible Makefile-over-SSH workflow. Use when preparing a benchmark run, deploying repo changes, restarting app/nginx/mysql, switching the active remote with REMOTE_ID, profiling with pprof/fgprof, iterating on slow queries, reassigning roles mid-contest, or collecting kataribe/slow-query logs against isu1/isu2/isu3 hosts; or when the user mentions `make bench`, `make maji`, `make pull`, `make replace`, `make kataribe`, REMOTE_ID switching, or ISUCON server operation in general.
---

# Operating ISUCON Servers via SSH

Run server operations against ISUCON contest hosts (`isu1`, `isu2`, `isu3`, …) through the Makefile-driven SSH workflow established by the `isucon-ansible` layout. Bench prep, deploys, restarts, profiling, and log collection are all expressed as `make` targets that execute on the remote host through `ssh -t -A`.

**Use this skill when** preparing servers for a benchmark run, deploying repo changes, restarting services, switching which remote is active, profiling, or pulling logs (kataribe / pt-query-digest) — i.e. any operation that would normally be `ssh isuN '<cmd>'`.

**Supporting files:**
- [USE-CASES.md](references/USE-CASES.md) — step-by-step runbooks for every recurring operational scenario (bootstrap, iterate, profile, slow-query loop, hotfix, role reassignment, cross-host MySQL, etc.).
- [TARGETS.md](references/TARGETS.md) — full catalog of every Makefile target and what it actually executes.
- [SSH-SETUP.md](references/SSH-SETUP.md) — the two prerequisites: `Host isuN` aliases and SSH agent forwarding.

## Prerequisites

1. `ssh isu1` / `isu2` / `isu3` works without prompting AND `ssh isu1 'ssh -T git@github.com'` succeeds (agent forwarding). See [SSH-SETUP.md](references/SSH-SETUP.md).
2. `ansible-playbook -i hosts server.yaml` has been run at least once. That playbook (a) provisions the boxes via the `common` / `tools` / `repo` / `kernel_param` / `fluentbit` roles and (b) renders `.make.env` from `group_vars/all/var.yaml`. **Every variable consumed by the Makefiles below comes from that file.**

## Two-Tier Make Workflow

Two Makefiles, top-level fans out via `make -C remote`:

```
[root] Makefile             ← target dispatcher; sets REMOTE_ID → ADDR=606N
   └─→ [remote/] Makefile   ← SHELL:=ssh, .SHELLFLAGS:=-t -A isu$(REMOTE_ID)
```

When `make bench` runs at the repo root, it forwards to `make -C remote bench`, and every recipe line in `remote/Makefile` is shipped as one `ssh isuN <cmd>` invocation. That is why `SHELL` is set to `ssh` rather than to a real shell.

### Selecting the target host

```bash
make pull                    # default REMOTE_ID=1 → ssh isu1
make REMOTE_ID=2 pull        # ssh isu2
make REMOTE_ID=3 restart     # ssh isu3
```

Always pass `REMOTE_ID=N` from the repo root. Do **not** `cd remote && make …`: `remote/Makefile` includes `../.make.env` and only resolves correctly when invoked from the root.

## Quick Start

```bash
# Pre-bench (logging + metrics ON)
for n in 1 2 3; do make REMOTE_ID=$n bench; done

# Final scoring run (logging + metrics OFF, slow-query off)
for n in 1 2 3; do make REMOTE_ID=$n maji; done
```

`bench` chains: `backup → pull → replace → fluentbit-enable → metrics-on → access-on → build → restart → slow-on`.
`maji`  chains: `backup → pull → replace → fluentbit-disable → metrics-off → access-off → build → restart → slow-off`.

## Common Targets

| Target | What runs on the remote |
|--------|--------------------------|
| `pull` | `git pull` in `$REPO_DIR` |
| `replace` | Sync `app/`, `nginx/`, `mysql/`, and `other/` from the repo to system paths |
| `app-replace` / `nginx-replace` / `mysql-replace` | One component only |
| `restart` | `systemctl restart` for app, nginx, mysql |
| `app-restart` / `nginx-restart` / `mysql-restart` | One service only |
| `build` | Run `$BUILD_CMD` (e.g. `go build`) in `$BUILD_DIR` |
| `nginx-check` | `sudo nginx -t` (auto-run before `nginx-restart`) |
| `log` / `log-cont` | `journalctl -e [-f] -u $APP_SRV_NAME` |
| `kataribe` | `kataribe` over the nginx access log |
| `slow` | `pt-query-digest` over the MySQL slow query log |
| `mysql` / `mysql-root` | Open a MySQL shell as `$DB_USER` / as root |
| `slow-on` / `slow-off` | Toggle MySQL slow query logging at runtime |
| `access-on` / `access-off` | Toggle nginx kataribe-format access log |
| `metrics-on` / `metrics-off` | Toggle `ISUTOOLS_ENABLE` env var in app systemd unit |
| `fluentbit-enable` / `fluentbit-disable` | Toggle fluent-bit shipping |
| `score` | POST a manual score to `localhost:6060/benchmark/score` |
| `backup` | Move nginx & mysql logs to `~/logs/<epoch>/` on the remote |

Full list with chains: [TARGETS.md](references/TARGETS.md).

## Local-Only Targets

These run on your laptop, not via SSH:

```bash
make pprof          # go tool pprof against http://localhost:606${REMOTE_ID}/debug/pprof/profile  (port 8889 UI)
make fgprof         # go tool pprof against the fgprof endpoint                                   (port 8888 UI)
```

Both assume an SSH tunnel is forwarding `606${REMOTE_ID}` from your laptop to the app's debug port on the remote. See [USE-CASES.md § Profile a hot endpoint](references/USE-CASES.md#3-profile-a-hot-endpoint-with-pprof).

## Use-Case Workflows

Pick the runbook that matches the situation. Each one is a sequence of `make` calls plus the verification step. Detailed steps are in [USE-CASES.md](references/USE-CASES.md).

| When you want to… | Runbook |
|----------------------|---------|
| Bring a fresh contest's boxes online | [§1 First-time bootstrap](references/USE-CASES.md#1-first-time-bootstrap-of-a-new-contest) |
| Run the prep chain before every measurement bench | [§2 Pre-bench prep](references/USE-CASES.md#2-pre-bench-prep) |
| Run the official scoring bench | [§3 Maji (final) run](references/USE-CASES.md#3-maji-final-run) |
| Iterate on a code change in a tight loop | [§4 Develop / build / test loop](references/USE-CASES.md#4-iterative-develop-build-test-loop) |
| Find which endpoint is the bottleneck | [§5 Investigate slow endpoints](references/USE-CASES.md#5-investigate-slow-endpoints-after-a-bench) |
| Get a flame graph for a hot endpoint | [§6 Profile with pprof](references/USE-CASES.md#6-profile-a-hot-endpoint-with-pprof) |
| Optimise a slow query iteratively | [§7 Slow-query optimisation cycle](references/USE-CASES.md#7-slow-query-optimisation-cycle) |
| Recover from a broken deploy | [§8 Hotfix a broken deploy](references/USE-CASES.md#8-hotfix-when-a-deploy-broke-the-bench) |
| Move a role (e.g. MySQL) to a different host | [§9 Mid-contest role reassignment](references/USE-CASES.md#9-mid-contest-role-reassignment) |
| Allow the app on isu1 to reach MySQL on isu2 | [§10 Cross-host MySQL access](references/USE-CASES.md#10-cross-host-mysql-access) |
| Pre-gzip static assets for `gzip_static on` | [§11 Static asset gzip prep](references/USE-CASES.md#11-static-asset-gzip-prep) |
| Run an ad-hoc command across all hosts | [§12 Ad-hoc commands & parallel ops](references/USE-CASES.md#12-ad-hoc-commands--parallel-ops) |
| Tail logs while a bench is running | [§13 Live log tailing during a bench](references/USE-CASES.md#13-live-log-tailing-during-a-bench) |
| Backport a hand-edit on the remote into the repo | [§14 Backport a hand-edit into the repo](references/USE-CASES.md#14-backport-a-hand-edit-into-the-repo) |
| Diagnose a rejected my.cnf | [§15 Detect a rejected MySQL config](references/USE-CASES.md#15-detect-a-rejected-mysql-config) |

## Tips & Gotchas

- **Agent forwarding is mandatory.** `pull` invokes `git` against an SSH-only repo on the remote; without `-A` (or a deploy key on the box), it hangs.
- **`SHELL:=ssh` quoting.** Each recipe line ships as a single `ssh` invocation. Multi-line shell logic uses `.ONESHELL:` plus an explicit `bash -c "…"` (see how `backup` is written) — follow that pattern when adding new targets.
- **`mysql-restart` post-checks the journal.** It greps for `ignored` and fails if any of the last few lines mention a rejected config; treat a non-zero exit as "my.cnf was rejected, the previous good config is still running".
- **`access-on` / `access-off` rewrite `nginx.conf` in place** with `sed`. Re-run `nginx-replace` to restore the canonical version from the repo.
- **`metrics-on` toggles a systemd `Environment=` line.** It runs `daemon-reload`, but you still need `app-restart` afterwards for the change to take effect. (`bench` already includes the restart.)
- **`REMOTE_ID` is numeric only** (`1`, `2`, `3`). It is interpolated into both `isu$(REMOTE_ID)` and `606$(REMOTE_ID)`.
- **`replace` is destructive.** It overwrites system config (`/etc/nginx`, `/etc/mysql`, etc.) from the repo. Run `backup` first if the remote has uncommitted manual edits you want to preserve, or backport them first ([§14](references/USE-CASES.md#14-backport-a-hand-edit-into-the-repo)).
- **Don't run `bench` and `maji` against the same host back-to-back without thinking.** They flip the observability toggles in opposite directions; whichever ran last wins.

## Resources

- Use-case runbooks: [USE-CASES.md](references/USE-CASES.md)
- Full target catalog: [TARGETS.md](references/TARGETS.md)
- SSH config / agent setup: [SSH-SETUP.md](references/SSH-SETUP.md)
