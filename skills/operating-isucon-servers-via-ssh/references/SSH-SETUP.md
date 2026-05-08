# SSH Setup

The Makefile workflow assumes you can `ssh isuN` (alias) without typing a hostname or password, and that the remote can reach your private git repo via the forwarded agent.

## `~/.ssh/config`

Define one `Host` entry per ISUCON server. Hostnames and the identity file should match `host_vars/isuN`:

```sshconfig
Host isu1
    HostName <public ip from host_vars/isu1>
    User isucon
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes

Host isu2
    HostName <public ip from host_vars/isu2>
    User isucon
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes

Host isu3
    HostName <public ip from host_vars/isu3>
    User isucon
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes
```

The `User`, `IdentityFile`, and host IPs come from `host_vars/isuN` (`ansible_user`, `ansible_ssh_private_key_file`, `ansible_host`). Keep them in sync.

The ansible runs themselves don't need `~/.ssh/config` because `ansible.cfg` already sets `ssh_args = -o ForwardAgent=yes -o "ControlMaster auto" -o "ControlPersist 5"` — but the Makefile's `SHELL:=ssh` does, because it runs raw `ssh isuN` with no extra args.

## ssh-agent

The remote `pull` target needs to git-pull from a private SSH repo (`git@github.com:…`). It relies on agent forwarding, so make sure your key is loaded:

```bash
ssh-add -l                       # is the key listed?
ssh-add ~/.ssh/id_ed25519        # if not, add it
```

Verify end-to-end:

```bash
ssh isu1 'ssh -T git@github.com'
# Expect: Hi <user>! You've successfully authenticated…
```

If that fails, `make pull` will hang on git's password prompt.

## Smoke Test

Before relying on the Makefile:

```bash
for n in 1 2 3; do
  ssh isu$n 'hostname && whoami'
done
```

All three should succeed without prompting. After that, `make REMOTE_ID=1 log` is the safest first call — it only reads journalctl and won't change state.

## Common Failures

- **`Permission denied (publickey)`** — agent isn't loaded, or the key isn't in `~/.ssh/authorized_keys` on the remote. The README's `wget -O - https://github.com/<you>.keys >> ~/.ssh/authorized_keys` snippet is the usual fix.
- **`Host key verification failed`** — first connection. Run `ssh isuN` interactively once to accept the host key (or pre-populate `~/.ssh/known_hosts`).
- **`pseudo-terminal will not be allocated because stdin is not a terminal`** — the Makefile uses `-t` precisely to allocate one; don't strip it. If you wrap `make` in a non-interactive context (CI, cron), pass `-tt` instead.
- **`make pull` hangs forever** — agent forwarding broken. Check `ssh -A isuN env | grep SSH_AUTH_SOCK` from the remote; the variable must be set.
