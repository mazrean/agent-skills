# Use-Case Workflows

Concrete operational runbooks for the isucon-ansible Makefile-over-SSH workflow. Each scenario lists the trigger, the step-by-step sequence, and how to verify it worked.

All `make` invocations assume the repo root as the working directory. `REMOTE_ID=N` selects which host (`isu1` / `isu2` / `isu3`).

---

## 1. First-time bootstrap of a new contest

**Trigger:** Repo just cloned, `host_vars/isuN` filled in with the contest's IPs, boxes are stock.

**Sequence:**
```bash
ansible-galaxy install -r requirements.yml
ansible-playbook -i hosts server.yaml
```

That single playbook run does, on every host in `[isucon]`:
- `common` — cap journald log size (`SystemMaxUse=200M`), uninstall mlocate, `source ~/.profile` from `.bashrc`.
- `tools` — install pprof / kataribe / pt-query-digest / fluent-bit prerequisites.
- `repo` — clone the contest repo to `$REPO_DIR`.
- `kernel_param` — tune `sysctl` for the contest workload.
- `fluentbit` — install the agent (left disabled until `fluentbit-enable`).
- `makefile` — render `.make.env` on your laptop from `group_vars/all/var.yaml`.

Then the per-role plays run (`app`, `mysql`, `nginx`) only on hosts listed in those groups in `hosts`; the `active:!app` etc. patterns tear those services down on hosts that *don't* own each role.

**Verify:**
```bash
for n in 1 2 3; do
  ssh isu$n 'systemctl is-active nginx mysql || true; uname -r; cat /proc/sys/net/core/somaxconn'
done
make REMOTE_ID=1 log    # safe smoke test — read-only
```

---

## 2. Pre-bench prep

**Trigger:** Before every development bench during the contest.

**Sequence:**
```bash
for n in 1 2 3; do make REMOTE_ID=$n bench; done
```

The `bench` chain ensures: latest code (`pull`), config in sync (`replace`), observability ON (`fluentbit-enable`, `metrics-on`, `access-on`, `slow-on`), service rebuilt and restarted (`build`, `restart`).

Logs from the previous run are auto-rotated to `~/logs/<epoch>/` by the `backup` step that begins the chain.

**Verify:**
```bash
make REMOTE_ID=1 log | tail -30      # app started cleanly?
ssh isu1 'systemctl is-active nginx mysql isuride-go fluent-bit'
```

---

## 3. Maji (final) run

**Trigger:** Last few minutes — you want a clean scoring run with no observability overhead.

**Sequence:**
```bash
for n in 1 2 3; do make REMOTE_ID=$n maji; done
```

`maji` is `bench` with the four observability toggles flipped off (`fluentbit-disable`, `metrics-off`, `access-off`, `slow-off`). It still runs `pull`, `replace`, `build`, `restart`, so the boxes are in a known state.

**Verify:**
```bash
make REMOTE_ID=1 log | tail -10
ssh isu1 'sudo grep -c "^Environment=ISUTOOLS_ENABLE=false" /etc/systemd/system/*.service'
```

After the scoring bench finishes, **do not deploy anything**. If you must, re-run `maji` to make sure observability toggled back off.

---

## 4. Iterative develop / build / test loop

**Trigger:** Coding on your laptop, want a 10–30 second cycle to validate against the real box.

**Sequence (one host):**
```bash
git push                                  # only path that ships code to the remote
make REMOTE_ID=1 pull build app-restart   # narrow chain — skip nginx/mysql restart
```

Use `app-replace` instead of `replace` when you've changed Go sources or assets but not nginx/mysql config; that avoids the heavier sudo-cp work.

**For a tighter loop, follow the journal in another pane:**
```bash
make REMOTE_ID=1 log-cont      # Ctrl+C when done
```

**Smoke test without invoking the bench:**
```bash
ssh isu1 'curl -sS -o /dev/null -w "%{http_code} %{time_total}s\n" http://localhost/api/healthz'
```

---

## 5. Investigate slow endpoints after a bench

**Trigger:** Score plateaued; need to know which endpoint is the bottleneck.

**Sequence:**
```bash
make REMOTE_ID=1 kataribe > /tmp/kataribe-$(date +%s).txt   # nginx access-log breakdown by endpoint
make REMOTE_ID=1 slow > /tmp/slow-$(date +%s).txt           # MySQL slow-query summary
make REMOTE_ID=1 log | tail -200                             # app journal for errors / panics
```

Kataribe sorts by total time consumed; the first three rows are usually where the wins are. If MySQL is the suspect, jump to §7.

---

## 6. Profile a hot endpoint with pprof

**Trigger:** Kataribe shows one endpoint dominating; you want a flame graph.

**Sequence:**
```bash
# 1. Make sure the app exposes its debug endpoint (/debug/pprof, /debug/fgprof) on port 6060.
make REMOTE_ID=1 metrics-on app-restart
# 2. Open an SSH tunnel from your laptop to the app's debug port.
ssh -N -L 6061:localhost:6060 isu1 &
# 3. Drive load (run the official bench), then while load is in flight:
make REMOTE_ID=1 pprof    # opens browser at :8889 with the CPU profile
make REMOTE_ID=1 fgprof   # opens browser at :8888 with the fgprof flame graph
```

The local Makefile computes the profile URL as `http://localhost:606${REMOTE_ID}` — the tunnel target port must match.

**Cleanup before maji:** kill the tunnel and `make REMOTE_ID=1 metrics-off app-restart`.

---

## 7. Slow-query optimisation cycle

**Trigger:** You suspect MySQL is the bottleneck.

**Sequence:**
```bash
make REMOTE_ID=1 slow-on              # log every query (already on after `bench`)
# (run the bench)
make REMOTE_ID=1 slow > /tmp/slow-before.txt

# Edit indexes / queries on your laptop, push, deploy.
git push
for n in 1 2 3; do make REMOTE_ID=$n pull replace build restart; done

# Re-measure.
# (rebench)
make REMOTE_ID=1 slow > /tmp/slow-after.txt
diff <(head -50 /tmp/slow-before.txt) <(head -50 /tmp/slow-after.txt)
```

Always `slow-off` (or run `maji`) before the official scoring bench. MySQL writing every query at `long_query_time=0` is non-trivial overhead.

---

## 8. Hotfix when a deploy broke the bench

**Trigger:** `make bench` reported success but the bench score is 0, or the app journal shows panics.

**Sequence:**
```bash
make REMOTE_ID=1 log | tail -100      # confirm what blew up
```

**Option A — revert at the source (preferred):**
```bash
git revert <bad-sha> && git push
for n in 1 2 3; do make REMOTE_ID=$n pull replace build restart; done
```

**Option B — emergency direct edit on the remote (last resort):**
```bash
ssh isu1
  # vim /etc/nginx/conf.d/...    # or whatever
  sudo nginx -t && sudo systemctl reload nginx
  exit
```

The moment things stabilise, mirror the change back into the repo (§14) so the next `pull` doesn't undo it.

---

## 9. Mid-contest role reassignment

**Trigger:** You decide isu1 should stop running MySQL so isu2 can host it alone (or any similar move).

**Sequence:**
1. Edit `hosts` so `[mysql]` lists only isu2:
   ```
   [mysql]
   isu2
   ```
2. Re-run the role plays — both up and down apply automatically thanks to the `active:!mysql` pattern in `server.yaml`:
   ```bash
   ansible-playbook -i hosts server.yaml -t mysql,mysql_down
   ```
3. Update the app config so `DB_HOST` points at isu2's private IP, push, deploy:
   ```bash
   git push
   for n in 1 2 3; do make REMOTE_ID=$n pull app-replace build app-restart; done
   ```
4. Grant cross-host MySQL access — see §10.

**Verify:**
```bash
ssh isu1 'systemctl is-active mysql'   # should say inactive
ssh isu2 'systemctl is-active mysql'   # should say active
```

---

## 10. Cross-host MySQL access

**Trigger:** App on isu1 needs to talk to MySQL on isu2.

**Sequence:**
```bash
make REMOTE_ID=2 mysql-root
```
At the prompt:
```sql
CREATE USER 'isucon'@'<isu1 private ip>' IDENTIFIED BY 'isucon';
GRANT ALL PRIVILEGES ON *.* TO 'isucon'@'<isu1 private ip>';
FLUSH PRIVILEGES;
```

If `mysqld` only binds to 127.0.0.1, also edit `bind-address` (`0.0.0.0` or the private IP) in the mysql conf, commit it to the repo, and:
```bash
make REMOTE_ID=2 pull mysql-replace mysql-restart
```

**Verify from the app host:**
```bash
ssh isu1 'mysql -h<isu2 private ip> -uisucon -pisucon -e "SELECT 1"'
```

---

## 11. Static asset gzip prep

**Trigger:** nginx is serving large static files; you want pre-compressed `.gz` versions to enable `gzip_static on`.

**On the remote (one-shot):**
```bash
ssh isu1 'cd /home/isucon/webapp/public && find . -type f ! -name "*.gz" \
  | xargs -I {} sh -c "gzip -9 -k -N -f {}"'
```

For a repeatable pre-deploy step, add the gzip pass to the repo so `replace` ships the `.gz` siblings. Then enable in nginx:
```nginx
gzip_static on;
```

---

## 12. Ad-hoc commands & parallel ops

**One host, one command:**
```bash
ssh isu1 'sudo journalctl -u nginx --since "5 minutes ago"'
```

**All active hosts, in parallel:**
```bash
for n in 1 2 3; do ssh isu$n 'uptime' & done; wait
```

**Via ansible (better when the command is structured / needs sudo / templated args):**
```bash
ansible -i hosts active -a 'uptime'
ansible -i hosts active -m shell -a 'sudo journalctl -u nginx --since "5 minutes ago"'
ansible -i hosts mysql -m shell -a 'mysqladmin -uroot processlist'
```

`active` is the inventory group defined in `hosts` as `[active:children] app, mysql, nginx`. Use it whenever you want "every host that's actually running something" rather than just `[isucon]`.

---

## 13. Live log tailing during a bench

Two-pane workflow:

- **Pane 1:**
  ```bash
  make REMOTE_ID=1 log-cont
  ```
- **Pane 2:** trigger the official bench.

When the bench ends, Ctrl+C the follower and run §5 (kataribe + slow + log) for the post-mortem. For multi-host tail, run one pane per `REMOTE_ID`.

---

## 14. Backport a hand-edit into the repo

**Trigger:** You SSH'd in, edited `nginx.conf` (or any file under config management), validated it works, and need it persisted before the next `pull` overwrites it.

**Sequence:**
```bash
ssh isu1 'sudo cat /etc/nginx/nginx.conf' > nginx/nginx.conf
git add nginx/nginx.conf
git commit -m "tune nginx workers"
git push
for n in 1 2 3; do make REMOTE_ID=$n pull nginx-replace nginx-restart; done
```

Skipping this step is the #1 cause of "it worked yesterday and I have no idea what changed." Any time you do an emergency edit on a remote, write a TODO in your runbook: *backport before the next deploy*.

---

## 15. Detect a rejected MySQL config

**Trigger:** `make mysql-restart` exited non-zero, OR the `mysql-replace` step finished but MySQL still behaves with the old config.

The Makefile's `mysql-restart` post-checks the journal:
```makefile
! sudo journalctl -e -u $(MYSQL_SRV_NAME) | tail -n 4 | grep -q ignored
```

That exit-non-zero is your early warning that some `*.cnf` was rejected for permissions or syntax reasons — the *previous good config* is still running.

**Diagnose:**
```bash
ssh isu1 'sudo journalctl -u mysql --since "2 minutes ago" | tail -50'
```

Look for lines like `[Warning] World-writable config file '...' is ignored`.

**Recover (after fixing the offending file in the repo):**
```bash
git push
make REMOTE_ID=1 pull mysql-replace mysql-restart
```

`mysql-replace` `chown -R mysql:mysql $MYSQL_CFG_DIR` and `chmod 644` the files, which fixes the world-writable case automatically.
