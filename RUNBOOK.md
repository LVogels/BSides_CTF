# RUNBOOK — "Ambiorix" (organiser ops)

Operational notes for deploying, resetting, and health-checking the challenge
at the con.

## Deploy

Only the pivot and target run; the pivot's web + SSH are published; **players
attack from their own machines**. There is no in-lab attacker box.

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

Players need the usual tools on their own machine (`nmap`, `curl`,
`openssh-client`, `proxychains4`); the README lists the install one-liners.

### Concurrency & scaling

- **Default:** one shared lab, players bring their own box. Nothing to
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
> deploy notes, muster roll, the SUID tool's output) is in
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

# full end-to-end solvability (golden path):
docker compose up -d --build
./test/solve.sh            # -> "==== PASS ====" and the flag
```

`solve.sh` also re-checks the **isolation invariant** (the target must NOT be
reachable directly from the host) as its first stage.

> `test/solve.sh` runs on the **host** against the published ports — exactly as a
> player would. It needs `curl`, `ssh`, `ncat` and `setsid` on the host (no
> `sshpass` or `proxychains` required). Override `WEB` / `SSH_PORT` if you
> published the pivot on non-default ports.

## Credentials (private — organiser reference)

| Where | User | Secret | How the player gets it |
|---|---|---|---|
| web console (`castra`) | `tiro` | `AveLegioXIV-54` | HTML comment on `/login` |
| SSH (`castra`) | `scout` | `FrontierWatch-54BC` | SSTI RCE → `/opt/castra/DEPLOY_NOTES.txt` |
| SSH (`arduenna`) | `eburo` | `ArduennaShadow` | `~scout/muster.txt` (after SSH) |
| root (`arduenna`) | — | — | SUID PATH-hijack of `/usr/local/bin/castellum` |

Flag: **`flag{atuatuca_ambush_54bc}`** at `/root/flag.txt` on `arduenna`.

## Resource use

- 2 containers (castra + arduenna).
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
- **SSH `-D` tunnel refused (`:1080` in use)** → a previous tunnel is still bound
  locally on the player's machine; `pkill -f 'ssh.*-D 1080'` and reopen it. (This
  is purely local to each player — it never affects the shared lab.)
- **Web console 502/down** → `docker compose restart pivot`; healthcheck will go
  green within ~30 s.

## Topology (private — organiser reference)

`README.md` is the player handout. It gives players only castra's address and
web console and that a hidden camp lies beyond it — nothing about the inner
network. For organisers:

```
          frontier 172.20.0.0/24                    internal (war-camp) 10.10.10.0/24
                                                     internal: true  (no outside route)
 ┌────────────┐        ┌──────────────────┐         ┌──────────────────┐
 │ player's   │────────│   castra (pivot) │─────────│ arduenna (target)│
 │ own machine│ host   │ .10  /  10.10.10.5│         │   10.10.10.10    │
 │            │ ports  │  :8080 web :2022 ssh        │   flag lives here│
 └────────────┘        └──────────────────┘         └──────────────────┘
```

Published on the lab host: `:8080` (castra web console) and `:2022` (castra SSH).
The target is never published.

## Repository files

| Path | What it is |
|---|---|
| `README.md` | **player-facing** brief — safe to distribute |
| `docker-compose.yml` | one-command deploy of the whole lab |
| `pivot/` | `castra` — vulnerable web console + SSH (dual-homed) |
| `target/` | `arduenna` — the inner box with the flag |
| `WALKTHROUGH.md` | **private** — full intended solution |
| `RUNBOOK.md` | **private** — this file |
| `flag.txt` | **private** — the flag + format |
| `test/solve.sh` | automated golden-path check |

## Suggested scoring

Single flag, **medium** → suggested **300 pts** (or per your event's curve).
Category for the scoreboard: Web / Network Pivoting / Linux privesc.
