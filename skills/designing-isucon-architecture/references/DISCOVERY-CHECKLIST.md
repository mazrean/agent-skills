# Discovery Checklist

The phase 0 inventory. Skipping any item here means the design will be wrong about an assumption later. Take the 15 minutes.

Output target: `docs/isucon-arch/CONSTRAINTS.md`.

## A. Regulation and manual

- [ ] Year and edition (e.g. ISUCON14, 2024-12-08).
- [ ] Score formula — exact endpoint weights, bonuses, penalties.
- [ ] Request timeout (almost always 10s, but confirm).
- [ ] Allowed languages and which is the *recommended* reference.
- [ ] Reboot-test details — graceful `reboot` vs power-pull, allowed warmup time before the post-reboot benchmark.
- [ ] Asset checksum / DOM-validation rules — which static files are checked, what kind of comparison.
- [ ] `/initialize` time budget — typically ≤30s.
- [ ] Anything explicitly forbidden (external compute, redirecting to CDN, modifying media files, etc.).

## B. Immutable items (the four untouchables)

For each, record absolute path, owning service, what touches it.

- [ ] **API contract** — list every (METHOD, path) pair from the router. Note request body schemas, response body schemas, status codes, headers.
- [ ] **Frontend statics** — directory served (e.g. `/home/isucon/webapp/public/`), URL prefix mounted at, byte-checksum baseline if known.
- [ ] **`isuwari` daemon** — service file (e.g. `/etc/systemd/system/isuwari.service`), executable path, all paths it touches (`find /opt/isuwari /var/lib/isuwari -type f` if those exist).
- [ ] **`isuadmin` user** — `getent passwd isuadmin`, home directory, sudoers entries, SSH keys.

## C. Instances and resources

For each instance (typically 3):

- [ ] Hostname, role in the *current* topology (app / db / nginx / mixed).
- [ ] CPU: `nproc` and `lscpu | grep "Model name"`.
- [ ] Memory: `free -h`.
- [ ] Disk: `df -h /` and `lsblk`.
- [ ] Network: private IP from `ip addr`, `iftop`/`ss -s` baseline.
- [ ] Distro and kernel: `cat /etc/os-release` and `uname -r`.

## D. Process inventory

For each instance:

- [ ] Reference app systemd unit name (e.g. `isuride-go.service`, `isuride-rust.service`). Multiple may be installed — only one is *enabled*.
- [ ] App listen address and port (`ss -ltnp`).
- [ ] DB process — version (`mysql --version` / `mariadb --version` / `psql --version`), config file path, data directory, current size.
- [ ] nginx version, config root, virtual-host file, current `worker_processes` and `worker_connections`.
- [ ] Cache (Redis / Memcached) — installed? running? listening on what port?
- [ ] Any other listeners (`ss -ltnp | grep -v 127.0.0.53`).

## E. Source tree

- [ ] App source directory per language (e.g. `webapp/go/`, `webapp/rust/`, `webapp/node/`).
- [ ] DB schema file (`webapp/sql/init.sql` or similar) — note tables, primary keys, foreign keys.
- [ ] Init script for the DB (`webapp/sql/init.sh` or similar) — note what it does on each invocation.
- [ ] Frontend build output location and whether nginx serves it directly.
- [ ] Existing `Makefile` or `tools/` directory — note what targets already exist.

## F. Endpoints

Produce `docs/isucon-arch/ENDPOINTS-INVENTORY.md`:

| METHOD | Path | Handler file:func | Auth | Tables read | Tables written |
|--------|------|------------------|------|-------------|----------------|
| GET | /api/foo | handlers/foo.go:getFoo | session | foo, user | (none) |
| POST | /api/foo | handlers/foo.go:postFoo | session | (none) | foo |
| ... | | | | | |

This table is the input to phase 2's algorithmic dimension. Generating it now saves 30 minutes later.

## G. Existing measurement state

Before running a fresh benchmark, note what already exists so you do not double-instrument:

- [ ] Is `pprof` already wired into the app? Behind a build tag? On what port?
- [ ] Is `alp` installed? Where? Is there an `alp.yml`?
- [ ] Is `pt-query-digest` installed?
- [ ] Is the slow query log already enabled? At what threshold?
- [ ] Is Netdata installed? Reachable at `:19999`?

If any are missing, set them up before phase 1, not during. See `winning-isucon/INITIAL-SETUP.md`.

## H. Output structure

By the end of phase 0 you should have:

```
docs/isucon-arch/
├── CONSTRAINTS.md           # This checklist's results
├── ENDPOINTS-INVENTORY.md   # Section F's table
└── (BASELINE.md and DESIGN.md come from phases 1 and 2)
```

If `docs/isucon-arch/` does not exist, create it now.
