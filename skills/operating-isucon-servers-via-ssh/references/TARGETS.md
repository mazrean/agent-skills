# Target Catalog

Full list of `make` targets exposed by the isucon-ansible workflow. Targets without a host are local; all others execute on `isu$(REMOTE_ID)` via `ssh -t -A`.

## Composite Targets

| Target | Chain |
|--------|-------|
| `bench` | `backup → pull → replace → fluentbit-enable → metrics-on → access-on → build → restart → slow-on` |
| `maji`  | `backup → pull → replace → fluentbit-disable → metrics-off → access-off → build → restart → slow-off` |
| `replace` | `app-replace → nginx-replace → mysql-replace → other-replace` |
| `restart` | `app-restart → nginx-restart → mysql-restart` |

`bench` is for measurement runs (logging + metrics ON). `maji` is for the final scoring run (logging + metrics OFF so they don't drag the score).

## Repo Sync

| Target | Effect |
|--------|--------|
| `pull` | `cd $REPO_DIR && git pull origin $REPO_BRANCH` |
| `app-replace` | For each path in `$APP_LIST`, `cp -r -T $REPO_DIR/$REPO_APP_PATH/<p> $APP_BASE/<p>` |
| `nginx-replace` | Same shape, syncs nginx config dir from `$REPO_NGX_PATH` to `$NGX_CFG_DIR` (`sudo`) |
| `mysql-replace` | Same shape for MySQL config; also `chown -R $MYSQL_USER:$MYSQL_USER $MYSQL_CFG_DIR` |
| `other-replace` | For each absolute path in `$OTHER_LIST`, copy from `$REPO_DIR/$REPO_OTHER_PATH/<basename>` |
| `backup` | `mkdir ~/logs/<epoch>` and `mv` `$NGX_LOG`, `$MYSQL_LOG` into it |

## Service Control

| Target | Effect |
|--------|--------|
| `app-restart` | `sudo systemctl restart $APP_SRV_NAME` (errors ignored) |
| `nginx-restart` | Depends on `nginx-check`; then `systemctl restart $NGX_SRV_NAME` |
| `mysql-restart` | `systemctl restart $MYSQL_SRV_NAME`; then journal-greps for `ignored` and fails if any line in the last 4 mentions a rejected config |
| `nginx-check` | `sudo nginx -t` |
| `fluentbit-enable` | `enable` + `start` `$FB_SRV_NAME` |
| `fluentbit-disable` | `stop` + `disable` `$FB_SRV_NAME` |

## Build & Run

| Target | Effect |
|--------|--------|
| `build` | `source ~/.profile && cd $BUILD_DIR && $BUILD_CMD` |
| `score` | Prompt for a number, POST `score=<n>` to `http://localhost:6060/benchmark/score` |

## Logs & Diagnostics

| Target | Effect |
|--------|--------|
| `log` | `sudo journalctl -e -u $APP_SRV_NAME` |
| `log-cont` | `sudo journalctl -e -f -u $APP_SRV_NAME` (follow) |
| `kataribe` | `sudo cat $NGX_LOG \| kataribe -f $KATARIBE_CFG` |
| `slow` | `sudo pt-query-digest $MYSQL_LOG` |
| `mysql` | `mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASS $DB_NAME` |
| `mysql-root` | `sudo mysql` |

## Runtime Toggles

| Target | Effect |
|--------|--------|
| `slow-on` | `set global slow_query_log=ON; slow_query_log_file=$MYSQL_LOG; long_query_time=0` |
| `slow-off` | `set global slow_query_log=OFF` |
| `access-on` | `sed` `nginx.conf` to `access_log $NGX_LOG kataribe;` |
| `access-off` | `sed` `nginx.conf` to `access_log off;` |
| `metrics-on` | `sed` the app unit's `Environment=ISUTOOLS_ENABLE=...` to `true`; `systemctl daemon-reload` |
| `metrics-off` | Same, sets `false` |

`access-*` and `metrics-*` need a follow-up service restart (`nginx-restart` / `app-restart`) for the change to take effect at the daemon level. The `bench` / `maji` chains already include the restart.

## Local-Only (no SSH)

| Target | Effect |
|--------|--------|
| `pprof` | `go tool pprof -http=:8889 http://localhost:$(606${REMOTE_ID})/debug/pprof/profile` |
| `fgprof` | `go tool pprof -http=:8888 http://localhost:$(606${REMOTE_ID})/debug/fgprof` |

Both assume an SSH tunnel forwards `606${REMOTE_ID}` on the laptop to the app's debug endpoint on the remote.

## Variables (from `.make.env`)

All target behavior is parameterised. The values come from `group_vars/all/var.yaml` via the `roles/makefile/templates/.make.env.j2` template. Most-used:

| Var | Source |
|-----|--------|
| `REPO_DIR`, `REPO_BRANCH` | `repository.directory`, `repository.branch` |
| `APP_LIST`, `APP_BASE`, `BUILD_DIR`, `BUILD_CMD`, `APP_SRV_NAME`, `APP_SRV_FILE` | `app.*` |
| `NGX_LOG`, `NGX_MAIN_CFG`, `NGX_CFG_DIR`, `NGX_CFG_LIST`, `NGX_SRV_NAME` | `nginx.*` |
| `MYSQL_LOG`, `MYSQL_MAIN_CFG`, `MYSQL_CFG_DIR`, `MYSQL_CFG_LIST`, `MYSQL_SRV_NAME`, `DB_HOST`/`DB_PORT`/`DB_USER`/`DB_PASS`/`DB_NAME` | `mysql.*` |
| `OTHER_LIST` | `repository.sync_list` |

To change a path or service name: edit `group_vars/all/var.yaml`, then re-run `ansible-playbook -i hosts server.yaml -t makefile` to regenerate `.make.env`.
