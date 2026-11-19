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
has exactly one machine you can see from where you stand — **castra**, its web
console:

```
http://<lab-host>:8080      # the web console (your foothold surface)
ssh scout@<lab-host> -p 2022   # castra's maintenance SSH — once you find the creds
```

Beyond castra lies the Eburones' hidden camp. You **cannot** reach it directly
from the frontier — find a way through castra.

**You play from your own machine.** No in-lab box is handed out: everything you
need runs on your own laptop (Kali or similar). Make sure you have the usual
tools installed:

```bash
# Debian/Kali:  sudo apt install -y nmap curl openssh-client proxychains4
# Fedora:       sudo dnf install -y nmap curl openssh-clients proxychains-ng
```

You'll use `curl` for the web stage, `ssh` to pivot, and `proxychains4` (or any
equivalent SOCKS client) to reach the hidden camp through the tunnel you open.

## Rules of engagement

- Everything you need is inside the lab. Attack **only** the lab host you were
  given — not the conference network, the organisers' infrastructure, or other
  players.
- No brute-forcing is needed. If you find yourself guessing, step back and
  read what the lab is telling you — *lege quod castra tibi dicunt.*
- Don't break things for others: no DoS, no deleting what you don't need to.

*Venare. Perrumpe. Transi. Cape.*
