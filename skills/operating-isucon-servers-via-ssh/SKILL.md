---
name: operating-isucon-servers-via-ssh
description: Run commands directly against ISUCON contest hosts (isu1/isu2/isu3) over plain SSH. Use when the user wants to ssh into a contest box and execute commands — checking app/nginx/mysql status, tailing journalctl, restarting services, opening a MySQL shell, running kataribe or pt-query-digest, profiling with pprof through an SSH tunnel, transferring files, or running anything ad-hoc that doesn't have (or doesn't need) a Makefile target. Covers `~/.ssh/config` + agent-forwarding setup, host inventory, server-side paths and service names, common one-liners by category, and SSH patterns (heredoc, port-forward, multi-host, scp/rsync).
---

# Operating ISUCON Servers via SSH

This skill is for the case where you want to **just SSH into a contest box and run a command**. No Makefile wrapper, no playbook — just `ssh isuN '<cmd>'`.

**Use this skill when** the request is a one-off operation on a contest server: status check, tailing logs, opening a MySQL shell, running kataribe / pt-query-digest, restarting one daemon, copying a file, getting a profile, or any other ad-hoc work over SSH.

**Supporting files:**
- [SSH-SETUP.md](references/SSH-SETUP.md) — the two prerequisites: `Host isuN` aliases and SSH agent forwarding.
- [USE-CASES.md](references/USE-CASES.md) — multi-step runbooks (bootstrap, bench prep, profiling, slow-query loop, hotfix, role reassignment, cross-host MySQL, etc.) expressed as raw `ssh` sequences.

## Prerequisites

1. `ssh isu1` / `isu2` / `isu3` connects without prompting.
2. `ssh isu1 'ssh -T git@github.com'` succeeds (your local agent is loaded *and* forwarded).

Fix both before running anything else: see [SSH-SETUP.md](references/SSH-SETUP.md).

## Inventory

The `isucon-ansible` `hosts` file groups the boxes by role. Default layout:

```
[app]      isu1, isu2          ← app server (Go binary, debug port 6060)
[mysql]    isu1                ← DB
[nginx]    isu1, isu2          ← reverse proxy
[active:children] app, mysql, nginx
```

Use this when deciding which host to ssh into. `host_vars/isuN` carries the IP / user / key for each alias — `~/.ssh/config` should mirror those.

## Server Layout (paths and service names)

The canonical paths used by `group_vars/all/var.yaml` — verify against your contest:

| What | Path / name |
|------|-------------|
| Repo on the remote | `/home/isucon/repo` |
| App working dir | `/home/isucon/webapp/go` |
| App systemd unit | `isuride-go.service` |
| App debug port | `6060` (`/debug/pprof`, `/debug/fgprof`) |
| App env toggle | `Environment=ISUTOOLS_ENABLE=true|false` in the unit file |
| nginx config dir | `/etc/nginx` |
| nginx access log | `/var/log/nginx/access.log` |
| nginx unit | `nginx.service` |
| MySQL config dir | `/etc/mysql` |
| MySQL slow log | `/var/log/mysql/slow-query.log` |
| MySQL unit | `mysql.service` |
| MySQL conn | `127.0.0.1:3306 isucon/isucon → isuride` |
| kataribe config | `/home/isucon/kataribe.toml` |
| fluent-bit unit | `fluent-bit.service` |

For *your contest's* values (different binary name, different DB name, different paths), grep the inventory:

```bash
grep -E 'service|connection|main_conf|log:|directory' group_vars/all/var.yaml
```

## Quick One-Liners

```bash
# Service status
ssh isu1 'systemctl is-active nginx mysql isuride-go'

# Recent app log
ssh isu1 'sudo journalctl -e -u isuride-go --no-pager -n 200'

# Follow app log (Ctrl+C to stop)
ssh isu1 'sudo journalctl -ef -u isuride-go'

# Restart the app
ssh isu1 'sudo systemctl restart isuride-go'

# Validate nginx config, then reload
ssh isu1 'sudo nginx -t && sudo systemctl reload nginx'

# Open a MySQL shell (-t required for the prompt)
ssh -t isu1 'mysql -h127.0.0.1 -uisucon -pisucon isuride'

# Kataribe over the latest access log
ssh isu1 'sudo cat /var/log/nginx/access.log | kataribe -f /home/isucon/kataribe.toml'

# Slow-query summary
ssh isu1 'sudo pt-query-digest /var/log/mysql/slow-query.log | head -100'

# Build & restart the app
ssh isu1 'cd /home/isucon/webapp/go && go build -o isuride -ldflags "-s -w" . && sudo systemctl restart isuride-go'

# Quick health check
ssh isu1 'curl -sS -o /dev/null -w "%{http_code} %{time_total}s\n" http://localhost/api/healthz'
```

More by category and longer runbooks: [USE-CASES.md](references/USE-CASES.md).

## SSH Patterns

### Multi-line scripts (heredoc)

When a one-liner gets ugly, ship a script:

```bash
ssh isu1 'bash -s' <<'EOF'
set -euo pipefail
cd /home/isucon/webapp/go
go build -o isuride -ldflags "-s -w" .
sudo systemctl restart isuride-go
sudo journalctl -e -u isuride-go --since "10 seconds ago"
EOF
```

**Quote the heredoc tag** (`'EOF'`, with single quotes) so your laptop doesn't expand `$VARS` before they reach the remote.

### Port forwarding (pprof / debug ports)

```bash
# Background tunnel from laptop:6061 → isu1:6060
ssh -fN -L 6061:localhost:6060 isu1

# CPU profile through the tunnel
go tool pprof -http=:8889 'http://localhost:6061/debug/pprof/profile?seconds=30'

# Close it when done
pkill -f 'ssh -fN -L 6061'
```

### File transfer

```bash
# Pull (e.g. backport a hand-edited config)
scp isu1:/etc/nginx/nginx.conf ./nginx/nginx.conf

# Push to a sudo-owned path — two-step
scp ./nginx.conf isu1:/tmp/nginx.conf
ssh isu1 'sudo install -m 0644 /tmp/nginx.conf /etc/nginx/nginx.conf && sudo nginx -t && sudo systemctl reload nginx'

# Sync a directory
rsync -av ./public/ isu1:/tmp/public-new/
```

### Multi-host

```bash
# Sequential
for n in 1 2 3; do ssh isu$n 'systemctl is-active isuride-go'; done

# Parallel
for n in 1 2 3; do ssh isu$n 'uptime' & done; wait

# Via ansible (better for sudo / templated args / many hosts)
ansible -i hosts active -m shell -a 'sudo journalctl -u nginx --since "5 minutes ago"'
```

### Persistent shell for long ops

```bash
ssh -t isu1 'tmux new -A -s work'
# detach with Ctrl-b d, reattach with the same command later
```

### Connection multiplexing (faster repeated calls)

The `ansible.cfg` ships `ControlMaster auto / ControlPersist 5` for ansible runs only. To get the same behaviour for ad-hoc `ssh` from your laptop, add to `~/.ssh/config`:

```sshconfig
Host isu*
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 60s
```

With that in place, the second `ssh isu1 ...` reuses the first's TCP connection and skips re-authentication.

## Pitfalls

- **Add `-t` for anything interactive.** `mysql`, `tmux`, `vim`, `htop` need a PTY. Without it: "the input device is not a TTY" or weirdly line-buffered output.
- **Quoting traps.** `ssh isu1 "echo $HOME"` expands `$HOME` *on your laptop*. Use single quotes (or escape) when you want the remote shell to evaluate. `ssh isu1 'echo $HOME'` prints `/home/isucon`.
- **Pipes split between local and remote.** `ssh isu1 "sudo cat /var/log/nginx/access.log" | kataribe` runs `kataribe` *locally*; `ssh isu1 'sudo cat /var/log/nginx/access.log | kataribe -f /home/isucon/kataribe.toml'` runs everything on the remote.
- **Redirection direction.** `ssh isu1 'sudo nginx -T' > out.txt` writes on your laptop. `ssh isu1 'sudo nginx -T > /tmp/out.txt'` writes on the remote.
- **`sudo` over SSH** works because the contest user has `NOPASSWD`. If a command unexpectedly hangs, suspect a sudo password prompt — add `-t` so you can type it.
- **Agent forwarding is required for git on the remote.** Anything that does `git pull`/`push` against the private repo from inside the box uses your forwarded agent.
- **`ssh isu1 'cd /foo && bar'`** — `cd` only affects that one ssh invocation; the next call starts in `$HOME` again. State doesn't persist between calls. Use heredocs when you need it to.
- **No `~` expansion in remote-side single-quoted commands** that contain `~/path` *if* the variable is interpolated by your local shell. Prefer absolute paths or `$HOME` (single-quoted, expanded remotely).

## When to reach for the Makefile wrapper

`isucon-ansible` ships a `Makefile` that wraps the same SSH layer:

```bash
make REMOTE_ID=1 log               # ≡ ssh isu1 'sudo journalctl -e -u isuride-go'
make REMOTE_ID=1 pull replace build restart   # multi-step bench prep
```

Use it when the operation is a recurring chain (bench prep, deploy across all hosts). Use raw SSH when the operation is a one-off, an investigation, or doesn't fit any target. The two are interchangeable for individual ops — pick whichever is shorter to type.

## Resources

- Connection setup: [SSH-SETUP.md](references/SSH-SETUP.md)
- Multi-step runbooks (raw SSH): [USE-CASES.md](references/USE-CASES.md)
