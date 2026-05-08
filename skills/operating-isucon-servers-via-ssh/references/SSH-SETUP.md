# SSH Setup

Two prerequisites for the Makefile-over-SSH workflow:

1. `ssh isu1` / `isu2` / `isu3` connects without prompting.
2. SSH agent forwarding works end-to-end so the remote can `git pull` from the private repo.

## `~/.ssh/config`

Define one alias per host. Hostnames and identity file mirror `host_vars/isuN`:

```sshconfig
Host isu1 isu2 isu3
    User isucon
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes

Host isu1
    HostName <host_vars/isu1.ansible_host>
Host isu2
    HostName <host_vars/isu2.ansible_host>
Host isu3
    HostName <host_vars/isu3.ansible_host>
```

The Makefile invokes raw `ssh isuN` with no extra args, so `ForwardAgent yes` MUST live in `~/.ssh/config`. The `ssh_args` in `ansible.cfg` only applies to ansible runs, not to `make`.

## ssh-agent

Agent forwarding only works if your local agent has the key loaded:

```bash
ssh-add -l                        # is the key listed?
ssh-add ~/.ssh/id_ed25519         # if not, add it
```

Verify the chain end-to-end — from your laptop, through the remote, out to GitHub:

```bash
ssh isu1 'ssh -T git@github.com'
# Expect: Hi <user>! You've successfully authenticated…
```

If that command prompts for a password or fails, fix it before running anything else: `make pull` will hang forever otherwise.
