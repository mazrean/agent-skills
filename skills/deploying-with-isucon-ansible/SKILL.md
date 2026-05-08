---
name: deploying-with-isucon-ansible
description: Deploys ISUCON contest code and configs to competition servers using the isucon-ansible layout (Ansible playbook for provisioning + Makefile-over-SSH for the per-benchmark loop). The two deploy commands are `make bench` (regular deploy, with instrumentation ON) and `make maji` (final-run deploy, with instrumentation OFF). Use when running benchmarks, deploying app/nginx/MySQL config changes, reassigning roles between servers, or when working in a repo that uses mazrean/isucon-ansible (server.yaml, hosts inventory, .make.env, remote/Makefile).
---

# Deploying with isucon-ansible

ISUCON deployment with this layout is a **two-layer** workflow:

1. **Ansible (`server.yaml`)** — one-shot / occasional. Provisions every
   competition server: installs tools, clones the contest repo, sets kernel
   params, installs systemd units for app/nginx/mysql, enables/disables each
   service based on the host group it belongs to.
2. **Makefile (`Makefile` + `remote/Makefile`)** — every benchmark run. Pulls
   the latest contest-repo commit on the target server, copies app code +
   `nginx`/`mysql` configs into place, toggles instrumentation (access log,
   slow query log, app metrics), rebuilds the binary, and restarts services.

**Use this skill when** you need to push a change and re-benchmark (`make
bench`), do the final scored run (`make maji`), swap which ISU runs which
role (mysql/app/nginx), or read pprof / kataribe / slow query output from a
target server.

**Repo-specific values** (service names, paths, repo URL, host IPs) live in
`group_vars/all/var.yaml`, `.make.env`, `host_vars/isuN`, and `hosts` — never
hard-code them; let the existing variables drive everything.

## The Two Deploy Commands

There are exactly **two** end-to-end deploy commands. Pick one based on what
the next run is for:

| Command                      | Purpose                                            | Instrumentation |
| ---------------------------- | -------------------------------------------------- | --------------- |
| `make bench REMOTE_ID=N`     | **Regular deploy** for iteration / measured runs.  | **ON**          |
| `make maji REMOTE_ID=N`      | **Final-run deploy** for the scored / "本気" run.  | **OFF**         |

- **`bench`** is the default for everyday work: it deploys *and* turns on
  every measurement channel (fluent-bit, app metrics endpoint, nginx
  access_log in kataribe format, MySQL slow_query_log) so the next benchmark
  produces analyzable data.
- **`maji`** ("マジ" = serious / final) is for when you're done iterating and
  want the highest score: same deploy steps, but every measurement channel is
  turned off so logging/profiling overhead doesn't cost you points. Use it
  for the last submitted run.

If in doubt, use `bench`. Only switch to `maji` when you explicitly want to
sacrifice observability for throughput.

## Mental Model

```
local                                        servers (isu1, isu2, isu3, ...)
─────                                        ──────────────────────────────
ansible-playbook server.yaml ──provision──▶ install tools, deploy systemd
                                             units, enable/disable services
                                             per [active] host-group membership

make bench REMOTE_ID=N ──ssh──▶ remote/Makefile on isuN:
                                  git pull → cp configs → instrumentation ON
                                  → build → restart        (regular deploy)

make maji  REMOTE_ID=N ──ssh──▶ remote/Makefile on isuN:
                                  git pull → cp configs → instrumentation OFF
                                  → build → restart        (final deploy)
```

The root `Makefile` does nothing locally except `make -C remote $TARGET`,
where `remote/Makefile` runs with `SHELL=ssh -t -A isu$REMOTE_ID`. Every
recipe in `remote/Makefile` therefore executes **on the target server over
SSH** with agent forwarding (so `git pull` against a private repo works).

## Inventory & Role Assignment

`hosts` defines two kinds of groups:

```ini
[isucon]      # all servers — common provisioning runs here
isu1
isu2

[app]         # which servers run the app
isu1
isu2

[mysql]       # which server runs MySQL
isu1

[nginx]       # which servers terminate HTTP
isu1
isu2

[active:children]
app
mysql
nginx
```

`server.yaml` then uses **`active:!app`**, **`active:!mysql`**, **`active:!nginx`**
patterns to *disable* the role on every active host that isn't in that role
group. So to move MySQL from isu1 to isu2, edit `hosts` (move `isu2` into
`[mysql]`, remove from `[mysql]`) and re-run the playbook — the role swap is
declarative.

Each host is bound to its SSH target via `host_vars/isuN` (`ansible_host`,
`ansible_user`, `ansible_ssh_private_key_file`).

## Provisioning (run on setup or after host-group changes)

```bash
# Install role dependencies once per checkout
ansible-galaxy install -r requirements.yml

# Full provision (all roles, all hosts in [active])
ansible-playbook -i hosts server.yaml

# Re-run a single role only — every role has a tag matching its name
ansible-playbook -i hosts server.yaml --tags nginx
ansible-playbook -i hosts server.yaml --tags mysql,mysql_down
ansible-playbook -i hosts server.yaml --tags repo
```

The `*_down` tags are the disable-on-inactive-hosts side; pair them with the
enable tag when reshuffling roles.

Local-only monitoring stack (Grafana / Loki / etc., on the operator's
machine):

```bash
ansible-playbook -i hosts monitor.yaml
```

## Per-Benchmark Loop

`REMOTE_ID` selects which server to deploy to (`isu$REMOTE_ID`). It defaults
to `1`; set it explicitly when deploying to other ISUs. The two top-level
deploy commands are:

```bash
# Regular deploy (instrumentation ON) — use this for every iteration
make bench REMOTE_ID=1

# Final-run deploy (instrumentation OFF) — use this only for the scored run
make maji REMOTE_ID=1
```

### `bench` (regular) vs. `maji` (final): step-by-step

Both share the same deploy steps; the only difference is whether each
measurement channel is enabled.

| Step                        | `bench` (regular) | `maji` (final) |
| --------------------------- | :---------------: | :------------: |
| `backup` access/slow logs   | ✅                | ✅             |
| `pull` git repo             | ✅                | ✅             |
| `replace` app/nginx/mysql   | ✅                | ✅             |
| fluent-bit log shipper      | enable            | disable        |
| app process metrics env var | on                | off            |
| nginx access_log (kataribe) | on                | off            |
| MySQL slow_query_log        | on                | off            |
| `build` Go binary           | ✅                | ✅             |
| `restart` services          | ✅                | ✅             |

Use `bench` while iterating (you want the data); use `maji` for the final
scored run (you want max throughput, no logging overhead).

### Targeting a Single Subsystem

When you only changed one layer, deploy only that layer:

```bash
make app-replace REMOTE_ID=1     # copy app source from cloned repo
make build       REMOTE_ID=1     # rebuild Go binary in BUILD_DIR
make app-restart REMOTE_ID=1     # systemctl restart $APP_SRV_NAME

make nginx-replace REMOTE_ID=1   # cp nginx.conf, conf.d/, sites-available/
make nginx-restart REMOTE_ID=1   # nginx -t, then restart

make mysql-replace REMOTE_ID=1   # cp my.cnf, conf.d/, mysql.conf.d/
make mysql-restart REMOTE_ID=1   # also greps journal for "ignored" config
```

`replace` always runs from the freshly-pulled `$REPO_DIR`, so always `make
pull` (or `make bench`/`maji`) before `replace` to pick up new commits.

## Inspection & Profiling

Every diagnostic target also runs over SSH against `isu$REMOTE_ID`:

```bash
make log         REMOTE_ID=1   # journalctl -e -u $APP_SRV_NAME
make log-cont    REMOTE_ID=1   # journalctl -e -f -u $APP_SRV_NAME (follow)
make slow        REMOTE_ID=1   # pt-query-digest on $MYSQL_LOG
make kataribe    REMOTE_ID=1   # kataribe over $NGX_LOG
make mysql       REMOTE_ID=1   # MySQL CLI as the app user
make mysql-root  REMOTE_ID=1   # MySQL CLI as root
```

`pprof` / `fgprof` are **local** targets — they call `go tool pprof -http=...`
against `http://localhost:606$REMOTE_ID/debug/pprof/profile` (resp.
`/debug/fgprof`). That URL only resolves if you've SSH-port-forwarded
`606$REMOTE_ID` from the target server, e.g.:

```bash
ssh -L 6061:localhost:6060 isu1     # in another shell, while make pprof runs
make pprof REMOTE_ID=1
```

## Toggling Instrumentation Independently

If you don't want to redeploy just to flip a knob:

```bash
make metrics-on   REMOTE_ID=N   # sed-edits ISUTOOLS_ENABLE in $APP_SRV_FILE + daemon-reload
make metrics-off  REMOTE_ID=N
make access-on    REMOTE_ID=N   # rewrites nginx access_log to kataribe format
make access-off   REMOTE_ID=N   # access_log off;
make slow-on      REMOTE_ID=N   # SET GLOBAL slow_query_log=ON, long_query_time=0
make slow-off     REMOTE_ID=N
make fluentbit-enable  REMOTE_ID=N
make fluentbit-disable REMOTE_ID=N
```

A `metrics-*` or `slow-*` flip on its own doesn't restart the app/MySQL —
follow with `app-restart` / `mysql-restart` if the change must take effect
immediately. The `bench`/`maji` macros already do this in the right order.

## Typical Workflows

### "I changed Go code" — regular deploy

```bash
make bench REMOTE_ID=1     # regular deploy: pull, replace, instrumentation ON, build, restart
# run benchmark
make kataribe REMOTE_ID=1  # nginx breakdown
make slow     REMOTE_ID=1  # slow query digest
```

### "I changed only nginx config"

```bash
# commit + push nginx/ in the contest repo first
make pull          REMOTE_ID=1
make nginx-replace REMOTE_ID=1
make nginx-restart REMOTE_ID=1
```

### "Move MySQL from isu1 to isu2"

1. Edit `hosts`: move `isu2` into `[mysql]`, remove `isu1` from it.
2. `ansible-playbook -i hosts server.yaml --tags mysql,mysql_down`
3. Update app DB host wherever it's configured (commonly `group_vars/all/var.yaml`'s
   `mysql.connection.host`, plus the contest app's env/config), commit, push,
   then `make bench REMOTE_ID=<app-host>`.

### "Final scoring run" — final deploy

```bash
make maji REMOTE_ID=1      # final deploy: same as bench, but instrumentation OFF
make maji REMOTE_ID=2
make maji REMOTE_ID=3
# trigger benchmark
```

Run `maji` against **every** active host so logs/metrics are off everywhere.
After the scored run finishes, switch back to `make bench` for the next
iteration so measurements come back on.

## Pre-flight Checklist

Before the first deploy in a fresh checkout:

- [ ] `ansible-galaxy install -r requirements.yml` ran cleanly
- [ ] `host_vars/isuN` has the right `ansible_host` / SSH key for each ISU
- [ ] `hosts` `[app]`/`[mysql]`/`[nginx]` reflects the intended topology
- [ ] `.make.env` `GIT_REPO` / `REPO_BRANCH` point at the contest repo
- [ ] `group_vars/all/var.yaml` service names + `BUILD_CMD` match the
      contest's app (e.g., `isuride-go.service` for ISUCON14)
- [ ] SSH agent forwarding works end-to-end (`ssh -A isu1 'ssh -T git@github.com'`)
- [ ] `ansible-playbook -i hosts server.yaml` completed at least once

## Gotchas

- **`bench` is regular; `maji` is final-only.** Don't run `maji` while
  iterating — you'll lose the kataribe / slow-query / metrics data you need
  to decide what to optimize next. Conversely, don't submit a `bench`-prepped
  run as the scored run — instrumentation overhead is non-trivial.
- **`REMOTE_ID` is per-invocation, not sticky.** `make bench` / `make maji`
  deploys to exactly one server; run it once per active app host.
- **`replace` is destructive on the server side** — it `cp -r -T`'s repo
  contents over `/etc/nginx`, `/etc/mysql`, `$APP_BASE`. Hand-edits on the
  server are lost on the next deploy. Always edit in the contest repo.
- **`mysql-restart` greps `journalctl` for `ignored`** to catch silent
  config-rejection (wrong perms / unknown options). If it fails after a
  config change, look for `chmod`/`chown` issues in `$MYSQL_CFG_DIR`.
- **`bench`/`maji` always run `backup` first**, moving the previous
  access_log + slow_query_log into `~/logs/<unix-timestamp>/` on the server.
  Pull old logs from there if you need to compare runs.
- **`active:!role` patterns require the host to be in `[active]`.** If you
  add a new ISU, add it to `[isucon]` *and* to at least one of
  `[app]`/`[mysql]`/`[nginx]`, otherwise the disable side won't run on it.
- **`make pprof`/`fgprof` need port forwarding.** They're local-only and hit
  `localhost:606$REMOTE_ID`; without an SSH tunnel they'll fail with a
  connection refused.

## Resources

- Ansible inventory patterns (`group:!other`): https://docs.ansible.com/ansible/latest/inventory_guide/intro_patterns.html
- kataribe (nginx access_log analyzer): https://github.com/matsuu/kataribe
- pt-query-digest (slow query analyzer): https://docs.percona.com/percona-toolkit/pt-query-digest.html
