# Initial Setup (First Hour)

A clean initial setup is the difference between losing 90 minutes and gaining 90 minutes. The goal is: **everything reproducible, everything in git, everything measurable** before you write a single optimization.

## Checklist (target: T+60min)

- [ ] All instances reachable via SSH; SSH config in `~/.ssh/config`
- [ ] `/home/isucon` is a git repo, pushed to private remote
- [ ] nginx access log is LTSV, `/var/log/nginx/access.log` exists
- [ ] MySQL slow query log captures everything (`long_query_time = 0`)
- [ ] `pprof` HTTP handler enabled (Go) or equivalent profiler hook
- [ ] `Makefile` with bench/deploy/log-rotation targets
- [ ] One benchmark run completed, baseline score recorded
- [ ] Initial alp + pt-query-digest output reviewed and discussed

## SSH Config

Put this in `~/.ssh/config` so you don't retype IPs:

```
Host isu1
  HostName 192.168.0.11
  User isucon
  IdentityFile ~/.ssh/isucon_key

Host isu2
  HostName 192.168.0.12
  User isucon
  IdentityFile ~/.ssh/isucon_key

Host isu3
  HostName 192.168.0.13
  User isucon
  IdentityFile ~/.ssh/isucon_key
```

## Git Setup

Inside `/home/isucon` on **isu1**:

```bash
cd /home/isucon
git init
git config user.email "team@example.com"
git config user.name "team"
# add a sensible .gitignore (vendor, node_modules, *.log, *.sock)
git add .
git commit -m "initial"
git remote add origin git@github.com:yourorg/isucon14.git
git push -u origin main
```

On isu2/isu3, pull as needed; usually only isu1 has the working tree and you `scp` or `rsync` the built binary.

## nginx Access Log → LTSV

LTSV is what `alp` parses by default. Edit `/etc/nginx/nginx.conf`:

```nginx
log_format ltsv "time:$time_iso8601"
              "\thost:$remote_addr"
              "\tmethod:$request_method"
              "\turi:$request_uri"
              "\tstatus:$status"
              "\tsize:$body_bytes_sent"
              "\treqtime:$request_time"
              "\tupstime:$upstream_response_time"
              "\tua:$http_user_agent";

access_log /var/log/nginx/access.log ltsv;
```

Then:

```bash
sudo systemctl restart nginx
```

## MySQL Slow Query Log

Edit `/etc/mysql/mysql.conf.d/mysqld.cnf` (or `my.cnf`):

```ini
[mysqld]
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 0
log_queries_not_using_indexes = 1
```

Make the file writable:

```bash
sudo touch /var/log/mysql/slow.log
sudo chown mysql:mysql /var/log/mysql/slow.log
sudo systemctl restart mysql
```

Set `long_query_time = 0` for the full run during measurement, then **set it back to a high value (or disable the log) before the final benchmark** — slow log I/O is a real cost.

## Tool Installation

On isu1 (and a measurement-only box if you have one):

```bash
# alp
wget https://github.com/tkuchiki/alp/releases/download/v1.0.21/alp_linux_amd64.tar.gz
tar zxvf alp_linux_amd64.tar.gz && sudo mv alp /usr/local/bin/

# Percona Toolkit (provides pt-query-digest)
sudo apt-get update && sudo apt-get install -y percona-toolkit

# Netdata (one-line install)
bash <(curl -SsL https://my-netdata.io/kickstart.sh) --dont-wait
```

For Go projects, `pprof` is in the standard library — just import `_ "net/http/pprof"` and start the http server, then access `/debug/pprof/`.

## Makefile

Live in `/home/isucon/Makefile`. The point is to make every reproducible action one keystroke away:

```makefile
APP_SERVICE := isuride-go.service
NGINX_LOG := /var/log/nginx/access.log
MYSQL_LOG := /var/log/mysql/slow.log
ALP_SORT := sum
ALP_M := "/api/chair/[a-z0-9]+,/api/app/rides/[a-z0-9]+"

.PHONY: build deploy bench bench-prep alp slow restart-app restart-db rotate

build:
	cd webapp/go && go build -o isuride

deploy: build
	sudo systemctl stop $(APP_SERVICE)
	sudo cp webapp/go/isuride /home/isucon/webapp/go/isuride
	sudo systemctl start $(APP_SERVICE)

bench-prep: rotate restart-app
	@echo "ready for benchmark"

rotate:
	sudo truncate -s 0 $(NGINX_LOG)
	sudo truncate -s 0 $(MYSQL_LOG)

restart-app:
	sudo systemctl restart $(APP_SERVICE)

restart-db:
	sudo systemctl restart mysql

alp:
	sudo cat $(NGINX_LOG) | alp ltsv --sort=$(ALP_SORT) -r -m $(ALP_M)

slow:
	sudo pt-query-digest $(MYSQL_LOG) | head -100
```

After a benchmark run:

```bash
make alp     # nginx hot endpoints
make slow    # MySQL hot queries
```

Before the next run:

```bash
make bench-prep   # truncates logs, restarts app
```

## systemd

The provided unit files live in `/etc/systemd/system/`. Common operations:

```bash
sudo systemctl status isuride-go.service
sudo systemctl restart isuride-go.service
sudo journalctl -u isuride-go.service -f --since "5 min ago"
```

If you switch language, change `ExecStart` in the unit file and `daemon-reload`:

```bash
sudo systemctl daemon-reload
sudo systemctl restart isuride-go.service
```

## Kernel and Limits (typical safe defaults)

`/etc/sysctl.d/99-isucon.conf`:

```
net.core.somaxconn = 32768
net.ipv4.ip_local_port_range = 10000 65535
net.ipv4.tcp_tw_reuse = 1
```

`sudo sysctl --system` to reload.

For systemd services that hit fd limits:

```ini
[Service]
LimitNOFILE=65535
```

(Place inside the `.service` file, then `daemon-reload && restart`.)

## MySQL Connections

`my.cnf`:

```ini
[mysqld]
max_connections = 1024
innodb_buffer_pool_size = 1G   # tune to ~50% of RAM
innodb_flush_log_at_trx_commit = 0   # ISUCON-style; do not use in prod
innodb_log_buffer_size = 64M
```

The `innodb_flush_log_at_trx_commit = 0` is a classic ISUCON tweak — the reboot test still passes because the benchmarker re-seeds and re-runs, but **read the year's regulation to confirm durability is not separately checked**.

## Go Connection Pool

In application code:

```go
db.SetMaxOpenConns(100)
db.SetMaxIdleConns(100)
db.SetConnMaxLifetime(0)  // never close
```

Tune `MaxOpenConns` to roughly `min(MySQL max_connections / num_app_servers, num_cpu_cores * 4)`.
