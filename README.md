# Ambiorix — BSides Limburg CTF

> *54 BC. In the forests of the Arduenna, the Eburones under their chieftain
> **Ambiorix** stood against the might of Rome. You are a scout at the Roman
> frontier. Somewhere out there is the prize — go and take it.*

| | |
|---|---|
| **Category** | Misc (multi-stage) |
| **Difficulty** | Medium |
| **Est. solve time** | 30–75 min (team of two) |
| **Flag format** | `flag{...}` |
| **Author** | Len — Ethical Hacking, Thomas More (Geel) |

## Mandata exploratori

> *Castra limitis Romana unam machinam habent quam videre potes: **castra**,
> stationem interretialem. Ultra eam latet castra occulta Eburonum. Eo recta
> ex limite pervenire non potes. Castra perrumpe, viam per ea inveni, et signum
> cape.*

Everything the lab shows you is **in Latin** — reading carefully is part of the
challenge. No Latin degree required; a dictionary and some nerve are enough.

## Getting started

The organisers will give you a **lab host address**. The Roman frontier camp
has exactly one machine you can see from where you stand:

| Where you play from | castra's web console |
|---|---|
| your own machine | `http://<lab-host>:8080` |
| the scout box (below) | `http://172.20.0.10` (port 80) — you are `172.20.0.5` on the frontier net `172.20.0.0/24` |

Beyond castra lies the Eburones' hidden camp. You **cannot** reach it directly
from the frontier — find a way through.

**Bring your own machine** (Kali or similar) with the usual tools: `nmap`,
`curl`, `ssh`, `proxychains4`.

**No kit with you?** Ask the organisers for the ready-made scout box. It has
`nmap`, `curl`, `ssh` and `proxychains4` (pre-configured for a SOCKS5 proxy on
`127.0.0.1:1080`) installed:

```bash
ssh scout@<lab-host> -p 2222        # password: ambiorix
cat /etc/ambiorix-brief.txt         # your orders, once logged in
```

## Rules of engagement

- Everything you need is inside the lab. Attack **only** the lab host you were
  given — not the conference network, the organisers' infrastructure, or other
  players.
- No brute-forcing is needed. If you find yourself guessing, step back and
  read what the lab is telling you — *lege quod castra tibi dicunt.*
- Don't break things for others: no DoS, no deleting what you don't need to.

*Venare. Perrumpe. Transi. Cape.*
