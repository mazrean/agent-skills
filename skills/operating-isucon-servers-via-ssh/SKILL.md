---
name: operating-isucon-servers-via-ssh
description: Operates ISUCON contest servers via the isucon-ansible Makefile-over-SSH workflow. Use when preparing a benchmark run, deploying repo changes, restarting app/nginx/mysql, switching the active remote with REMOTE_ID, or collecting kataribe/slow-query logs against isu1/isu2/isu3 hosts; or when the user mentions `make bench`, `make maji`, `make pull`, `make replace`, `make kataribe`, or ISUCON server operation in general.
---

# Operating ISUCON Servers via SSH

Run server operations against ISUCON contest hosts (`isu1`, `isu2`, `isu3`, …) through the Makefile-driven SSH workflow established by the `isucon-ansible` layout. Bench prep, deploys, restarts, and log collection are all expressed as `make` targets that execute on the remote host through `ssh -t -A`.

**Use this skill when** preparing servers for a benchmark run, deploying repo changes, restarting services, switching which remote is active, or pulling logs (kataribe / pt-query-digest) — i.e. any operation that would normally be `ssh isuN '<cmd>'`.

**Supporting files:** [TARGETS.md](references/TARGETS.md) for the full target catalog, [SSH-SETUP.md](references/SSH-SETUP.md) for the required `~/.ssh/config` and ssh-agent setup.

## Prerequisites

1. `~/.ssh/config` defines `Host isu1` / `isu2` / `isu3` aliases. See [SSH-SETUP.md](references/SSH-SETUP.md).
2. `ssh-add` has loaded the key referenced by `host_vars/isuN`. Agent forwarding (`ForwardAgent yes`, set in `ansible.cfg` for ansible runs) is mandatory because the remote `pull` target talks to an SSH-only git remote.
3. `ansible-playbook -i hosts server.yaml` has been run at least once to bootstrap. That playbook renders `.make.env` from `group_vars/all/var.yaml` — every variable consumed by the Makefiles below comes from there.

## Two-Tier Make Workflow

The repo has TWO Makefiles, and the top-level one fans out via `make -C remote`:

```
[root] Makefile             ← target dispatcher; sets REMOTE_ID → ADDR=606N
   └─→ [remote/] Makefile   ← SHELL:=ssh, .SHELLFLAGS:=-t -A isu$(REMOTE_ID)
```

When `make bench` runs at the repo root, it forwards to `make -C remote bench`, and every recipe line in `remote/Makefile` executes as one `ssh isuN <cmd>` invocation. This is why `SHELL` is set to `ssh` rather than a real shell.

### Selecting the target host

```bash
make pull                    # default REMOTE_ID=1 → ssh isu1
make REMOTE_ID=2 pull        # ssh isu2
make REMOTE_ID=3 restart     # ssh isu3
```

Always pass `REMOTE_ID=N` from the repo root. Do **not** `cd remote && make …`: `remote/Makefile` includes `../.make.env` and only resolves relative to the repo root invocation.

## Quick Start: Pre-bench Run

```bash
for n in 1 2 3; do make REMOTE_ID=$n bench; done
```

`bench` chains: `backup → pull → replace → fluentbit-enable → metrics-on → access-on → build → restart → slow-on`.

For the final maji (real) run, swap to `make maji` — it disables logging/metrics so they don't drag the score:

```bash
for n in 1 2 3; do make REMOTE_ID=$n maji; done
```

`maji` chains: `backup → pull → replace → fluentbit-disable → metrics-off → access-off → build → restart → slow-off`.

## Common Targets

| Target | What runs on the remote |
|--------|--------------------------|
| `pull` | `git pull` in `$REPO_DIR` |
| `replace` | Sync `app/`, `nginx/`, `mysql/`, and `other/` from the repo to the system paths |
| `app-replace` / `nginx-replace` / `mysql-replace` | Targeted sync of one component |
| `restart` | `systemctl restart` for app, nginx, mysql |
| `app-restart` / `nginx-restart` / `mysql-restart` | One service only |
| `build` | Run `$BUILD_CMD` (e.g. `go build`) in `$BUILD_DIR` |
| `nginx-check` | `sudo nginx -t` (auto-run before `nginx-restart`) |
| `log` / `log-cont` | `journalctl -e [-f] -u $APP_SRV_NAME` |
| `kataribe` | Run `kataribe` over the nginx access log |
| `slow` | `pt-query-digest` over the MySQL slow query log |
| `mysql` / `mysql-root` | Open a MySQL shell as `$DB_USER` / as root |
| `slow-on` / `slow-off` | Toggle MySQL slow query logging at runtime |
| `access-on` / `access-off` | Toggle nginx kataribe-format access log |
| `metrics-on` / `metrics-off` | Toggle the `ISUTOOLS_ENABLE` env var in the app systemd unit |
| `fluentbit-enable` / `fluentbit-disable` | Toggle fluent-bit shipping |
| `score` | POST a manual score to `localhost:6060/benchmark/score` |
| `backup` | Move nginx & mysql logs to `~/logs/<epoch>/` on the remote |

Full list with chains and dependencies: [TARGETS.md](references/TARGETS.md).

## Local-Only Targets

These run on your laptop, not via SSH:

```bash
make pprof          # opens go tool pprof against http://localhost:606${REMOTE_ID}/debug/pprof/profile
make fgprof         # same shape, fgprof endpoint, port 8888
```

The expected port is `606${REMOTE_ID}`, so set up an SSH tunnel before invoking, e.g.:

```bash
ssh -N -L 6061:localhost:6060 isu1 &
make REMOTE_ID=1 pprof
```

## Recommended Workflows

### Deploy a code change to all hosts

```bash
git push                              # push to the branch the remote pulls
for n in 1 2 3; do
  make REMOTE_ID=$n pull replace build restart
done
```

### Investigate slow endpoints / queries after a bench

```bash
make REMOTE_ID=1 kataribe   # nginx access-log breakdown
make REMOTE_ID=1 slow       # MySQL slow-query summary
make REMOTE_ID=1 log        # latest app journal
```

### Reassign which host runs which role

Edit `hosts` (the `[app]`, `[mysql]`, `[nginx]` groups) and re-run the playbook:

```bash
ansible-playbook -i hosts server.yaml -t app,mysql,nginx
```

The `active:!app` / `active:!mysql` / `active:!nginx` patterns automatically tear down services on hosts that no longer own that role.

## Tips & Gotchas

- **Agent forwarding is mandatory.** `pull` invokes `git` against an SSH-only repo on the remote; without `-A` (or a deploy key on the box), it hangs.
- **`SHELL:=ssh` quoting.** Every recipe line is shipped as a single `ssh` command. Multi-line shell logic uses `.ONESHELL:` plus an explicit `bash -c "…"` (see how `backup` is written) — when adding new targets, follow that pattern instead of relying on shell continuation.
- **`mysql-restart` post-checks the journal.** It greps for `ignored` after restart to catch permission/syntax mistakes; a non-zero exit means your `my.cnf` was rejected and the previous config is still running.
- **`access-on` / `access-off` rewrite `nginx.conf` in place** with `sed`. Re-run `nginx-replace` to restore the canonical version from the repo.
- **`metrics-on` toggles a systemd `Environment=` line.** It runs `daemon-reload`, but you still need `app-restart` afterwards for the change to take effect.
- **`REMOTE_ID` is numeric only** (`1`, `2`, `3`). It is interpolated into both `isu$(REMOTE_ID)` and `606$(REMOTE_ID)`.
- **`replace` is destructive.** It overwrites system config (`/etc/nginx`, `/etc/mysql`, etc.) from the repo. Run `backup` first if the remote has uncommitted manual edits you want to preserve.

## Resources

- Full target catalog: [TARGETS.md](references/TARGETS.md)
- SSH config / agent setup: [SSH-SETUP.md](references/SSH-SETUP.md)
