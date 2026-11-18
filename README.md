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

## Player brief

You land on the **frontier (guest) network** with one box in sight: the Roman
**Castra Legionis** watch console. Only that box is reachable. Somewhere beyond
it lies the Eburones' hidden war-camp — but there is no direct road to it. Find
the way through the camp and take the flag.

> **Scope / rules of engagement:** everything you need is inside this lab. No
> callbacks to the internet, no brute-forcing required, exactly one intended
> path. If you find yourself guessing, step back and read what the box is
> telling you.

## How to play

```bash
# organiser brings the lab up
docker compose up -d --build

# player attaches to their frontier box (the "attacker" container)
docker compose exec attacker bash
```

You start as `scout` on `172.20.0.5`. Your target box on the frontier is
`castra` at `172.20.0.10`. Tools provided: `nmap`, `curl`, `ssh`,
`proxychains4` (pre-configured), `sshpass`, `netcat`, `python3`.

Hunt. Breach. Pivot. Capture.

## Topology

```
          guest (frontier) 172.20.0.0/24            internal (war-camp) 10.10.10.0/24
                                                     internal: true  (no outside route)
 ┌────────────┐        ┌──────────────────┐         ┌──────────────────┐
 │  attacker  │────────│   castra (pivot) │─────────│ arduenna (target)│
 │ 172.20.0.5 │        │ .10  /  10.10.10.5│         │   10.10.10.10    │
 └────────────┘        └──────────────────┘         └──────────────────┘
      you            web console + SSH (dual-homed)     flag lives here
```

The target is only reachable **through** the pivot — that's the whole point.

## Files

| Path | What it is |
|---|---|
| `docker-compose.yml` | one-command deploy of the whole lab |
| `attacker/` | the player's frontier box (tools + brief) |
| `pivot/` | `castra` — vulnerable web console + SSH (dual-homed) |
| `target/` | `arduenna` — the inner box with the flag |
| `WALKTHROUGH.md` | **private** — full intended solution (organisers only) |
| `RUNBOOK.md` | deploy / reset / healthcheck / resource notes |
| `flag.txt` | **private** — the flag + format |
| `test/solve.sh` | automated golden-path check |

## Suggested scoring

Single flag, **medium** → suggested **300 pts** (or per your event's curve).
