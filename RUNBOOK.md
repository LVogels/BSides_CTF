# RUNBOOK — "Ambiorix" (organiser ops)

Operational notes for deploying, resetting, and health-checking the challenge
at the con.

## Deploy

Default deploy (recommended for a public CTF — **Model A**): only the pivot and
target run; the pivot's web + SSH are published; players attack from their own
machines.

```bash
docker compose up -d --build
docker compose ps          # castra + arduenna should be "Up" / healthy
```

Published on the host:

| Host | → container | What |
|---|---|---|
| `:8080` | `castra:80` | the web console (foothold surface) |
| `:2022` | `castra:22` | pivot SSH (for the `ssh -D` dynamic forward) |

The target (`arduenna`) is **never** published — it's reachable only by
tunnelling through the pivot. Because each player's `ssh -D` SOCKS proxy binds on
*their own* machine, many players can play the shared lab at once without
colliding on `:1080`.

### Optional in-lab attacker box

For players without their own tooling (and to run `test/solve.sh`), start the
ready-made frontier box behind the `attacker` profile:

```bash
docker compose --profile attacker up -d --build
ssh scout@<lab-host> -p 2222        # password: ambiorix  (host :2222 -> attacker :22)
```

The `scout` player account there has passwordless `sudo` (its own box, so raw
`nmap` scans work). Fallback: `docker compose exec attacker bash`.

### Concurrency & scaling

- **Model A (default):** one shared lab, players bring their own box. Nothing to
  scale — this is the normal CTF model. The flag is static, so everyone submits
  the same string.
- **Per-team isolation:** run one stack per team with a distinct project name and
  host-port offsets, e.g.
  ```bash
  docker compose -p team07 up -d          # edit the ports: lines per stack
  ```
  Note: the subnets (`172.20.0.0/24`, `10.10.10.0/24`) are currently fixed, so
  two stacks can't share a host without parametrising them. For many isolated
  stacks, ask the author for the hostname-based variant + a launcher script.
- **Scaling to head-count** is an orchestration concern (event infra), not
  something compose does by itself.

> **Language:** all in-environment player-facing text (web console, login banners,
> deploy notes, muster roll, the SUID tool's output, the attacker brief) is in
> **Latin** by design — an extra translation layer. See `WALKTHROUGH.md` for a
> full Latin→English glossary of every clue. Credentials/IPs are literal ASCII.

## Reset between solvers

The challenge is effectively stateless; the only mutable state is the in-memory
web board on `castra`, which players can only append flavour text to.

```bash
# fast reset (clears web board + any dropped files, keeps images):
docker compose restart

# full clean rebuild:
docker compose down -v && docker compose up -d --build
```

The flag, all credentials, the SUID binary, and the breadcrumbs are baked into
the images at build time, so a restart always returns to a known-good state —
even after a player `rm -rf`'s things inside a container.

## Healthcheck

Compose defines container healthchecks:
- **castra (pivot):** `curl -fsS http://127.0.0.1/healthz` (the web console).
- **arduenna (target):** `pidof sshd`.

Manual checks (from the host, using the published ports):

```bash
# web console alive?
curl -fsS http://127.0.0.1:8080/healthz                 # -> ok

# pivot SSH reachable?
nc -z 127.0.0.1 2022 && echo "pivot ssh open"

# full end-to-end solvability (needs the attacker profile):
docker compose --profile attacker up -d --build
./test/solve.sh            # -> "==== PASS ====" and the flag
```

`solve.sh` also re-checks the **isolation invariant** (attacker must NOT reach
`10.10.10.10` directly) as its first stage.

> `test/solve.sh` runs its steps inside the attacker container, so bring that
> profile up first. It defaults to `docker compose`; on a podman host use
> `COMPOSE="podman-compose --profile attacker" ./test/solve.sh`.

## Credentials (private — organiser reference)

| Where | User | Secret | How the player gets it |
|---|---|---|---|
| attacker box (SSH `:2222`) | `scout` | `ambiorix` | handed out to players (their own box) |
| web console (`castra`) | `tiro` | `AveLegioXIV-54` | HTML comment on `/login` |
| SSH (`castra`) | `scout` | `FrontierWatch-54BC` | SSTI RCE → `/opt/castra/DEPLOY_NOTES.txt` |
| SSH (`arduenna`) | `eburo` | `ArduennaShadow` | `~scout/muster.txt` (after SSH) |
| root (`arduenna`) | — | — | SUID PATH-hijack of `/usr/local/bin/castellum` |

Flag: **`flag{atuatuca_ambush_54bc}`** at `/root/flag.txt` on `arduenna`.

## Resource use

- 2 containers by default (castra + arduenna), or 3 with the attacker profile.
  Base images: `python:3.11-slim`, `debian:bookworm-slim`.
- Idle footprint is light: roughly **~200–400 MB RAM** total and negligible CPU
  (gunicorn with 2 workers + the `sshd`s). One shared lab (Model A) comfortably
  serves many players at once; run one stack per team only if you want hard
  per-team isolation.
- Disk: a few hundred MB of images after build.

## Troubleshooting

- **Player can reach `10.10.10.10` directly** → the `internal: true` flag on the
  `internal` network is missing/overridden. Re-check `docker-compose.yml` and
  rebuild. The isolation check above must fail.
- **SSH `-D` tunnel refused on the in-lab attacker box** → a previous tunnel is
  still bound to `:1080`; `pkill -f 'ssh.*-D 1080'` or
  `docker compose restart attacker`. (Players on their own machines never hit
  this — their tunnel binds locally.)
- **Web console 502/down** → `docker compose restart pivot`; healthcheck will go
  green within ~30 s.
