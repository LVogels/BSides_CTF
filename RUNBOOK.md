# RUNBOOK — "Ambiorix" (organiser ops)

Operational notes for deploying, resetting, and health-checking the challenge
at the con.

## Deploy

```bash
docker compose up -d --build
docker compose ps          # all three should be "Up" (pivot/target: healthy)
```

- **No host ports are published.** Players enter via the attacker container:
  ```bash
  docker compose exec attacker bash
  ```
  This keeps the frontier model clean and means the host itself is never part of
  the attack surface. (If you prefer to hand out shells differently — e.g. one
  attacker container per team, or SSH into it — scale/adjust as needed.)

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

Manual checks:

```bash
# web console alive?
docker compose exec attacker curl -fsS http://172.20.0.10/healthz      # -> ok

# isolation invariant still holds? (this MUST fail / time out)
docker compose exec attacker ping -c1 -W2 10.10.10.10 ; echo "exit=$?"

# full end-to-end solvability:
./test/solve.sh            # -> "==== PASS ====" and the flag
```

> `test/solve.sh` defaults to `docker compose`. On a podman host:
> `COMPOSE="podman-compose" ./test/solve.sh`.

## Credentials (private — organiser reference)

| Where | User | Secret | How the player gets it |
|---|---|---|---|
| web console (`castra`) | `tiro` | `AveLegioXIV-54` | HTML comment on `/login` |
| SSH (`castra`) | `scout` | `FrontierWatch-54BC` | SSTI RCE → `/opt/castra/DEPLOY_NOTES.txt` |
| SSH (`arduenna`) | `eburo` | `ArduennaShadow` | `~scout/muster.txt` (after SSH) |
| root (`arduenna`) | — | — | SUID PATH-hijack of `/usr/local/bin/castellum` |

Flag: **`flag{atuatuca_ambush_54bc}`** at `/root/flag.txt` on `arduenna`.

## Resource use

- 3 small containers. Base images: `python:3.11-slim`, `debian:bookworm-slim`.
- Idle footprint is light: roughly **~250–400 MB RAM** total and negligible CPU
  (gunicorn with 2 workers + two `sshd`s). Comfortable for many concurrent
  teams on one host; scale horizontally (one stack per team) if you expect heavy
  parallel load or want per-team isolation.
- Disk: a few hundred MB of images after build.

## Troubleshooting

- **Player can reach `10.10.10.10` directly** → the `internal: true` flag on the
  `internal` network is missing/overridden. Re-check `docker-compose.yml` and
  rebuild. The isolation check above must fail.
- **SSH `-D` tunnel refused** → a previous tunnel is still bound to `:1080`
  inside the attacker container; `pkill -f 'ssh.*-D 1080'` or
  `docker compose restart attacker`.
- **Web console 502/down** → `docker compose restart pivot`; healthcheck will go
  green within ~30 s.
