# Ambiorix — BSides Limburg CTF Challenge

> *54 BC. The Eburones, led by the chieftain **Ambiorix**, lured a Roman legion
> into the forests of the Arduenna and destroyed it. You are a scout at the
> Roman frontier. Breach the camp, slip past the patrol line, and reach the
> hidden war-camp in the woods.*

| | |
|---|---|
| **Category** | Web / Network Pivoting / Linux privesc (multi-stage) |
| **Difficulty** | Medium |
| **Est. solve time** | 30–75 min (team of two) |
| **Flag format** | `flag{...}` |
| **Author** | Len — Ethical Hacking, Thomas More (Geel) |

## Mandata exploratori (player brief)

> *Explorator es ad limitem Romanum. Una statio tibi patet: **Castra Legionis**.
> Ultra eam latet castra occulta Eburonum, quo nulla via recta ducit. Castra
> perrumpe, viam per ea inveni, et signum cape.*

Everything the lab shows you is **in Latin** — reading the clues is part of the
challenge. (The structure is always clear: credentials appear as
`nomen / tessera`, hosts as plain addresses. No Latin degree required, a
dictionary and some nerve are enough.)

> **Scope / rules of engagement:** everything you need is inside this lab. No
> callbacks to the internet, no brute-forcing required, exactly one intended
> path. If you find yourself guessing, step back and read what the box is
> telling you — *lege quod castra tibi dicunt.*

## How to play

**Default — bring your own machine (Kali, etc.):** the organiser runs the lab
and gives you the host address. The frontier camp exposes two things:

```bash
#  http://<lab-host>:8080        the watch console (your foothold)
#  ssh ...@<lab-host> -p 2022    the camp's SSH (once you've found who & what)
```

Work from your own box with your own tools. (Your SSH `-D` tunnel binds on your
machine, so lots of players can play at once without stepping on each other.)

**Optional — use the provided frontier box** (if you don't have your own kit):
the organiser can start a ready-made attacker container with `nmap`, `curl`,
`ssh`, `proxychains4`, `sshpass` already installed:

```bash
ssh scout@<lab-host> -p 2222        # password: ambiorix
```

Hunt. Breach. Pivot. Capture. — *Venare. Perrumpe. Transi. Cape.*

## Topology

```
          guest (frontier) 172.20.0.0/24            internal (war-camp) 10.10.10.0/24
                                                     internal: true  (no outside route)
 ┌────────────┐        ┌──────────────────┐         ┌──────────────────┐
 │  your box  │────────│   castra (pivot) │─────────│ arduenna (target)│
 │ (or opt.   │        │ .10  /  10.10.10.5│         │   10.10.10.10    │
 │  attacker) │        │  :8080 web :2022 ssh        │   flag lives here│
 └────────────┘        └──────────────────┘         └──────────────────┘
                     web console + SSH (dual-homed)
```

The target is only reachable **through** the pivot — that's the whole point.

## Deploy (organiser)

```bash
docker compose up -d --build                      # default: pivot + target only
# optionally also start the ready-made attacker box:
docker compose --profile attacker up -d --build
```

See `RUNBOOK.md` for reset, healthcheck, scaling and per-team isolation notes.

## Files

| Path | What it is |
|---|---|
| `docker-compose.yml` | one-command deploy of the whole lab |
| `attacker/` | optional ready-made frontier box (tools + brief); `--profile attacker` |
| `pivot/` | `castra` — vulnerable web console + SSH (dual-homed) |
| `target/` | `arduenna` — the inner box with the flag |
| `WALKTHROUGH.md` | **private** — full intended solution (organisers only) |
| `RUNBOOK.md` | deploy / reset / healthcheck / resource notes |
| `flag.txt` | **private** — the flag + format |
| `test/solve.sh` | automated golden-path check |

## Suggested scoring

Single flag, **medium** → suggested **300 pts** (or per your event's curve).
