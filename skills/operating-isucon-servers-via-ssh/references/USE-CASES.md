# Use-Case Runbooks

Multi-step operational scenarios expressed as raw `ssh` commands. Each runbook lists the trigger, the sequence, and how to verify it worked.

`isuN` aliases come from `~/.ssh/config` (see [SSH-SETUP.md](SSH-SETUP.md)). Replace service / path names with whatever your contest uses — the values shown match the canonical `group_vars/all/var.yaml` defaults.

---

## 1. First-time bootstrap of a new contest

**Trigger:** Repo just cloned, `host_vars/isuN` filled in, boxes are stock.

**Sequence:**
```bash
# Fill ~/.ssh/config Host entries from host_vars
grep -E 'ansible_host|ansible_user|ansible_ssh_private_key_file' host_vars/isu*

# Verify the prerequisites
for n in 1 2 3; do ssh isu$n 'hostname && whoami'; done
ssh isu1 'ssh -T git@github.com'    # agent forwarding

# Provision via ansible (one playbook does common/tools/repo/kernel_param/fluentbit + per-role)
ansible-galaxy install -r requirements.yml
ansible-playbook -i hosts server.yaml
```

**Verify:**
```bash
for n in 1 2 3; do
  ssh isu$n 'systemctl is-active isuride-go nginx mysql || true; uname -r'
done
```

---

## 2. Pre-bench prep (manual chain)

**Trigger:** Before each development bench during the contest.

**Sequence (per host):**
```bash
ssh isu1 'bash -s' <<'EOF'
set -e
# Backup last run's logs
when=$(date +%s); sudo mkdir -p ~/logs/$when
sudo mv -f /var/log/nginx/access.log ~/logs/$when/ 2>/dev/null || true
sudo mv -f /var/log/mysql/slow-query.log ~/logs/$when/ 2>/dev/null || true

# Pull latest code + sync to system paths
cd /home/isucon/repo && git pull origin main
for p in payment_mock/ public/ go/ sql/; do
  cp -r -T app/$p /home/isucon/webapp/$p
done

# Build
cd /home/isucon/webapp/go && go build -o isuride -ldflags "-s -w" .

# Observability ON
sudo systemctl enable --now fluent-bit
sudo sed -i 's/^Environment=ISUTOOLS_ENABLE=.*/Environment=ISUTOOLS_ENABLE=true/' /etc/systemd/system/isuride-go.service
sudo systemctl daemon-reload
sudo sed -i 's|^.*access_log .*|  access_log /var/log/nginx/access.log kataribe;|' /etc/nginx/nginx.conf
sudo mysql -e "set global slow_query_log=ON; set global slow_query_log_file='/var/log/mysql/slow-query.log'; set global long_query_time=0;"

# Restart services
sudo systemctl restart isuride-go
sudo nginx -t && sudo systemctl reload nginx
sudo systemctl restart mysql
EOF
```

Repeat for `isu2`, `isu3`. Or use `make REMOTE_ID=N bench` if you want the wrapper.

**Verify:**
```bash
ssh isu1 'systemctl is-active isuride-go nginx mysql fluent-bit'
ssh isu1 'sudo journalctl -e -u isuride-go --no-pager -n 30'
```

---

## 3. Maji (final scoring) run

**Trigger:** Last benches — you want a clean scoring run with no observability overhead.

**Sequence:** same as §2 but flip every observability toggle off:
```bash
ssh isu1 'bash -s' <<'EOF'
set -e
sudo systemctl disable --now fluent-bit
sudo sed -i 's/^Environment=ISUTOOLS_ENABLE=.*/Environment=ISUTOOLS_ENABLE=false/' /etc/systemd/system/isuride-go.service
sudo systemctl daemon-reload
sudo sed -i 's|^.*access_log .*|  access_log off;|' /etc/nginx/nginx.conf
sudo mysql -e "set global slow_query_log=OFF;"
sudo systemctl restart isuride-go
sudo systemctl reload nginx
EOF
```

After the scoring bench, **don't deploy anything**. If you must, repeat the full off-toggle sequence so observability stays off.

---

## 4. Iterative develop / build / test loop

**Trigger:** Tight 10–30 second cycle while coding.

**Sequence:**
```bash
git push                                # only path code reaches the remote
ssh isu1 'cd /home/isucon/repo && git pull origin main \
  && cp -r -T app/go/ /home/isucon/webapp/go/ \
  && cd /home/isucon/webapp/go && go build -o isuride -ldflags "-s -w" . \
  && sudo systemctl restart isuride-go'
ssh isu1 'sudo journalctl -e -u isuride-go --no-pager -n 50'
```

Follow logs in another pane: `ssh isu1 'sudo journalctl -ef -u isuride-go'`.

**Smoke test without firing the bench:**
```bash
ssh isu1 'curl -sS -o /dev/null -w "%{http_code} %{time_total}s\n" http://localhost/api/healthz'
```

---

## 5. Investigate slow endpoints after a bench

**Trigger:** Score plateaued; need to know which endpoint or query is to blame.

**Sequence:**
```bash
ts=$(date +%s)
ssh isu1 'sudo cat /var/log/nginx/access.log | kataribe -f /home/isucon/kataribe.toml' > /tmp/kataribe-$ts.txt
ssh isu1 'sudo pt-query-digest /var/log/mysql/slow-query.log' > /tmp/slow-$ts.txt
ssh isu1 'sudo journalctl -u isuride-go --since "10 minutes ago" --no-pager' > /tmp/applog-$ts.txt
head -40 /tmp/kataribe-$ts.txt
head -80 /tmp/slow-$ts.txt
```

The top 3 rows of each output usually point at where the wins are.

---

## 6. Profile a hot endpoint with pprof

**Trigger:** Kataribe shows one endpoint dominating; you want a flame graph.

**Sequence:**
```bash
# 1. Make sure the app exposes its debug endpoint
ssh isu1 'sudo sed -i "s/^Environment=ISUTOOLS_ENABLE=.*/Environment=ISUTOOLS_ENABLE=true/" /etc/systemd/system/isuride-go.service \
  && sudo systemctl daemon-reload && sudo systemctl restart isuride-go'

# 2. Tunnel laptop:6061 → isu1:6060
ssh -fN -L 6061:localhost:6060 isu1

# 3. Drive load (run the official bench), then while load is in flight:
go tool pprof -http=:8889 'http://localhost:6061/debug/pprof/profile?seconds=30'
go tool pprof -http=:8888 'http://localhost:6061/debug/fgprof?seconds=30'
go tool pprof -http=:8890 'http://localhost:6061/debug/pprof/heap'   # memory

# 4. Close the tunnel
pkill -f 'ssh -fN -L 6061'
```

**Cleanup before maji:** flip `ISUTOOLS_ENABLE=false` and restart the app.

---

## 7. Slow-query optimisation cycle

**Trigger:** MySQL is the suspected bottleneck.

**Sequence:**
```bash
# Capture
ssh isu1 'sudo mysql -e "set global slow_query_log=ON; set global slow_query_log_file=\"/var/log/mysql/slow-query.log\"; set global long_query_time=0;"'
# (run the bench)
ssh isu1 'sudo pt-query-digest /var/log/mysql/slow-query.log' > /tmp/slow-before.txt

# Edit indexes / queries on your laptop, push, deploy.
git push
for n in 1 2 3; do
  ssh isu$n 'cd /home/isucon/repo && git pull origin main \
    && cp -r -T app/go/ /home/isucon/webapp/go/ \
    && cd /home/isucon/webapp/go && go build -o isuride -ldflags "-s -w" . \
    && sudo systemctl restart isuride-go'
done

# Re-measure
ssh isu1 'sudo truncate -s 0 /var/log/mysql/slow-query.log'
# (rebench)
ssh isu1 'sudo pt-query-digest /var/log/mysql/slow-query.log' > /tmp/slow-after.txt
diff <(head -50 /tmp/slow-before.txt) <(head -50 /tmp/slow-after.txt)
```

Always turn slow-query off before maji:
```bash
ssh isu1 'sudo mysql -e "set global slow_query_log=OFF;"'
```

---

## 8. Hotfix when a deploy broke the bench

**Trigger:** Bench score is 0, or the app journal shows panics.

**Diagnose:**
```bash
ssh isu1 'sudo journalctl -e -u isuride-go --no-pager -n 200'
```

**Option A — revert at the source (preferred):**
```bash
git revert <bad-sha> && git push
for n in 1 2 3; do
  ssh isu$n 'cd /home/isucon/repo && git pull origin main \
    && cp -r -T app/go/ /home/isucon/webapp/go/ \
    && cd /home/isucon/webapp/go && go build -o isuride -ldflags "-s -w" . \
    && sudo systemctl restart isuride-go'
done
```

**Option B — emergency direct edit on the remote (last resort):**
```bash
ssh isu1
  # vim /etc/nginx/conf.d/...    # or whatever
  sudo nginx -t && sudo systemctl reload nginx
  exit
```

Then mirror the change back into the repo (§14) so the next pull doesn't undo it.

---

## 9. Mid-contest role reassignment

**Trigger:** Move a service — e.g. dedicate isu2 to MySQL only.

**Sequence:**
1. On the host that will *stop* hosting the role:
   ```bash
   ssh isu1 'sudo systemctl disable --now mysql'
   ```
2. On the new host — ensure the role is provisioned (re-run ansible if it isn't):
   ```bash
   ansible-playbook -i hosts server.yaml -t mysql,mysql_down
   ```
3. Update the app config so `DB_HOST` points at the new host's private IP, push, deploy.
4. Grant cross-host MySQL access — see §10.

**Verify:**
```bash
ssh isu1 'systemctl is-active mysql'   # inactive
ssh isu2 'systemctl is-active mysql'   # active
ssh isu1 'mysql -h<isu2 priv ip> -uisucon -pisucon -e "SELECT 1"'
```

---

## 10. Cross-host MySQL access

**Trigger:** App on isu1 needs to reach MySQL on isu2.

**Sequence:**
```bash
ssh -t isu2 'sudo mysql' <<'SQL'
CREATE USER 'isucon'@'<isu1 priv ip>' IDENTIFIED BY 'isucon';
GRANT ALL PRIVILEGES ON *.* TO 'isucon'@'<isu1 priv ip>';
FLUSH PRIVILEGES;
SQL
```

If `mysqld` only binds to 127.0.0.1, edit `bind-address` to `0.0.0.0` (or the private IP), commit it to the repo, then on isu2:
```bash
ssh isu2 'cd /home/isucon/repo && git pull origin main \
  && sudo cp -r -T mysql/conf.d/ /etc/mysql/conf.d/ \
  && sudo chown -R mysql:mysql /etc/mysql && sudo systemctl restart mysql'
```

**Verify from the app host:**
```bash
ssh isu1 'mysql -h<isu2 priv ip> -uisucon -pisucon -e "SELECT 1"'
```

---

## 11. Static asset gzip prep

**Trigger:** nginx serves large static files; you want pre-compressed `.gz` siblings for `gzip_static on`.

```bash
ssh isu1 'cd /home/isucon/webapp/public && sudo find . -type f ! -name "*.gz" \
  -exec sh -c "gzip -9 -k -N -f {}" \;'
```

Then enable in nginx:
```nginx
gzip_static on;
```
Validate and reload:
```bash
ssh isu1 'sudo nginx -t && sudo systemctl reload nginx'
```

---

## 12. Ad-hoc commands & parallel ops

```bash
# One host, one command
ssh isu1 'sudo journalctl -u nginx --since "5 minutes ago"'

# All active hosts, sequential
for n in 1 2 3; do ssh isu$n 'uptime'; done

# All active hosts, parallel — collect output per host
for n in 1 2 3; do (ssh isu$n 'uptime' | sed "s/^/isu$n: /") & done; wait

# Via ansible (templated args, sudo prompt handling, idempotency)
ansible -i hosts active -m shell -a 'sudo journalctl -u nginx --since "5 minutes ago"'
ansible -i hosts mysql -m shell -a 'sudo mysql -e "SHOW PROCESSLIST"'
```

`active` is the inventory group `[active:children] app, mysql, nginx` — "every host that's actually running something."

---

## 13. Live log tailing during a bench

Two-pane workflow:

- **Pane 1:** `ssh isu1 'sudo journalctl -ef -u isuride-go'`
- **Pane 2:** trigger the official bench.

Add more panes for `nginx` / `mysql`:
```bash
ssh isu1 'sudo tail -F /var/log/nginx/error.log'
ssh isu1 'sudo journalctl -ef -u mysql'
```

For multi-host, one tab per `isuN`.

---

## 14. Backport a hand-edit into the repo

**Trigger:** You SSH'd in, edited a file under config management, validated it works, and need it persisted before the next sync overwrites it.

**Sequence:**
```bash
scp isu1:/etc/nginx/nginx.conf ./nginx/nginx.conf
git add nginx/nginx.conf
git commit -m "tune nginx workers"
git push

# Replicate to the other hosts so they don't drift
for n in 1 2 3; do
  ssh isu$n 'cd /home/isucon/repo && git pull origin main \
    && sudo cp -r -T nginx/nginx.conf /etc/nginx/nginx.conf \
    && sudo nginx -t && sudo systemctl reload nginx'
done
```

Skipping this step is the #1 cause of "it worked yesterday and I have no idea what changed."

---

## 15. Detect a rejected MySQL config

**Trigger:** You changed something under `/etc/mysql/`, restarted, but MySQL still acts like the old config is in force.

**Diagnose:**
```bash
ssh isu1 'sudo systemctl restart mysql; sudo journalctl -e -u mysql --no-pager -n 30'
```

Look for lines like `[Warning] World-writable config file '...' is ignored`. That means MySQL silently dropped the file and is running with its previous good config.

**Recover:**
```bash
ssh isu1 'sudo chown -R mysql:mysql /etc/mysql && sudo find /etc/mysql -type f -exec chmod 644 {} \; && sudo systemctl restart mysql'
ssh isu1 'sudo journalctl -e -u mysql --no-pager -n 30 | grep -v ignored'
```

The permission fix matches what `mysql-replace` already does in the Makefile wrapper — if you keep hitting this, just use that.
