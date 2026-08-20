---
name: e2e-test-k8s-immich
description: Validate whether k8s actually solves the six container-management pain points (resource control, startup ordering, self-healing, update management, visibility, port collisions) by running the Immich-shaped testbed in ~/k8s-lab against OrbStack's native K3s. Never touches production.
---

# K8s Testbed Validation (Immich-shaped, OrbStack K3s)

Runs six verification scenarios against the throwaway k8s testbed in
`~/k8s-lab` (mirroring `modules/immich/compose.yaml`) to decide whether
k8s actually solves the operational pain points from the
kubernetes-on-homeserver note — not just whether it *configures* them.
Every scenario asserts on a real k8s mechanism actually working
(OOMKill enforced, pod recreated, rolling update applied, ...), the way
`e2e-test-immich` asserts on a real thumbnail rather than an upload
animation.

This never touches production: the testbed uses its own namespace
(`immich-lab`), its own hostPath data under `/var/lib/k8s-lab/immich/`,
its own NodePort (32283), and its own cluster on OrbStack's native K3s
(`orb start k8s`). Production services on `mac-mini-m4-pro` are untouched.

## Usage

Run from anywhere inside the repository (any worktree):

```bash
.agents/skills/e2e-test-k8s-immich/scripts/run.sh
```

Prerequisites: OrbStack running, `k8s.enable` set (declaratively via
`modules/docker/orbstack/home.nix`), `~/k8s-lab` checked out.

## What It Does

1. `orb start k8s` — brings up the cluster on-demand; `kubectl` is
   OrbStack-included.
2. `kubectl apply -k ~/k8s-lab/overlay/mac-mini-m4-pro` — deploys the
   testbed; waits for `/api/server/ping` at `http://localhost:32283`.
3. Runs the six scenarios in order, each asserting on a real outcome:
   - **Resource control** — lowers `limits` on the immich-server pod to a
     deliberately tiny value, confirms the container gets
     OOMKilled/throttled (k8s enforces the limit, not just records it).
   - **Startup ordering** — scales the database to 0, confirms the
     immich-server pod stays `ContainerCreating`/`NotReady` (waiting on
     readiness), then scales the DB back up and confirms recovery.
   - **Self-healing** — `kubectl delete pod` a healthy server pod,
     confirms k8s recreates it automatically and it becomes Ready again.
   - **Update management** — patches the image tag to a different release,
     confirms a rolling update rolls through and the service stays
     reachable throughout.
   - **Visibility** — `kubectl top pod` returns real usage (requires
     metrics-server; installs it if absent).
   - **Port collision** — confirms NodePort 32283 is bound and does not
     clash with the existing stacks' loopback ports (2283, 3000, 2223,
     9188, ...).
4. Reports pass/fail per scenario.

## When to Use

- To produce the evidence for the kubernetes-on-homeserver decision:
  whether to adopt k8s for real services.
- After changing `~/k8s-lab` manifests, to confirm the validation still
  holds.

## Known Constraints

- Requires the k8s cluster to be startable (`orb start k8s`); on the
  first run metrics-server may need installing.
- The testbed shares the OrbStack VM with production Docker — run
  scenarios when the host has idle capacity.
- Teardown is left to the operator (`kubectl delete -k ...`, `orb stop
  k8s`); per the agreed exit strategy the cluster is destroyed with
  `orb delete k8s` once validation is complete.