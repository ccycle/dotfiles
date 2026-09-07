---
name: service-ops
description: Restart, inspect, and read logs of the launchd-managed services (docker-compose stacks and native daemons) defined in this dotfiles repo. Use when a service must be restarted or its status/logs checked, and to get the launchctl domain and label right on the first try.
---

# Service Ops

Every service in this repo is a nix-darwin launchd job. `launchd.daemons.<name>`
becomes label `org.nixos.<name>` in the **system** domain; `launchd.user.agents.<name>`
becomes the same label in the **gui/$(id -u)** domain. Getting the domain wrong is the
most common failure — `launchctl kickstart org.nixos.foo` (no domain) and
`launchctl bootout gui/$(id -u)/org.nixos.<daemon>` (wrong domain for a system daemon)
both fail.

## Enumerate services

Derive the list from the code — do not maintain one here:

```bash
grep -rho 'launchd\.daemons\.[a-z0-9-]*' modules --include='*.nix' | sort -u
grep -rho 'launchd\.user\.agents\.[a-zA-Z0-9-]*' modules --include='*.nix' | sort -u
```

## Restart

```bash
# system daemon (all *-compose stacks, caddy, atticd, dnsmasq, ...)
sudo launchctl kickstart -k system/org.nixos.<name>

# user agent (llm-server, mlx-server, opencode-web, ...)
launchctl kickstart -k gui/$(id -u)/org.nixos.<name>
```

`-k` kills the running instance first; without it a running job is left untouched.
If sudo cannot be run from this session, hand the exact command to the user
(they can run it with the `!` prefix) and wait for the result.

## Status

```bash
sudo launchctl print system/org.nixos.<name> | head -20   # state, PID, last exit code
docker ps --filter name=<service>                          # containers of a compose stack
```

Compose project names come from the `name:` field in the module's `compose.yaml`
(or default naming) — confirm with `docker ps` rather than guessing.

## Logs

- launchd job output: `/var/log/<name>.log` (the `StandardOutPath` in the module's
  `options.nix` — check there when the name differs).
- Container logs: `docker logs --tail 100 <container>`.
- For deeper investigation (Prometheus/Loki queries, triage flow), switch to the
  `investigate-service` skill.

## Caveats

- A `*-compose` restart recreates containers; data in named volumes survives,
  bind mounts survive, anything else does not. If in doubt whether state is at
  risk, list the affected volumes and confirm with the user first.
- `darwin-rebuild switch` reloads only the launchd jobs whose definition
  changed; unchanged jobs keep running as-is. Check status before assuming a
  rebuild restarted anything.
