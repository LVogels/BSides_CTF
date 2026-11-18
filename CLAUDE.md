# CLAUDE.md — BSides Limburg CTF Challenge

Project context for Claude Code sessions working in this directory.

## What this project is

A single, original **Capture The Flag challenge** designed to run at the
**BSides Limburg** community CTF (CORDA Campus, Hasselt). This is the EXT1
learning-goal deliverable for the Ethical Hacking track at Thomas More (Geel).

- **Bloom level:** Create
- **Author:** Len (3rd-year Ethical Hacking student)
- **Audience:** CTF players at a community security conference — assume competent
  but time-boxed. They should feel clever, not stuck.

### Required deliverables (grade depends on all three)

1. **The challenge itself** — a fully working, self-contained, deployable lab.
2. **`docker-compose.yml`** — one command spins the whole thing up.
3. **`WALKTHROUGH.md`** — complete intended solution path, step by step, with
   the exact commands, outputs, and the flag at the end. An unambiguous
   "golden path" an organiser can reproduce.

## The challenge concept

A **multi-stage network-pivoting challenge**, Linux-based, in the spirit of the
"nuclear reactor" OT lab (two-VLAN pivot) but **entirely original** — new theme,
new services, new vulns, no reused infrastructure or write-ups.

### Theme: Ambiorix

Named for **Ambiorix**, chieftain of the **Eburones**, who in 54 BC ambushed and
destroyed a Roman legion in the territory that is now Limburg — a local hero with
his statue on the Grote Markt in Tongeren. Lean into the narrative: the player is
a scout breaching the Roman frontier. The **guest network is the Roman frontier
camp** (the exposed, defended edge); the **pivot** is slipping past the
patrol/supply line into the woods; the **inner network is the Eburones' hidden
war camp**, where the objective waits. Flavour text, hostnames, service names,
and creds can all ride the theme (`castra`, `legion`, `eburones`, `ambiorix`,
`arduenna`, `caesar`). Keep it tasteful and historical — it's a hook, not a
history exam.

### Player journey (the three beats)

1. **Foothold (guest network).** The player lands on a "guest"/edge segment.
   Only one box is reachable: a dual-homed **pivot host** running a deliberately
   vulnerable, *beginner-to-intermediate* entry service. Player enumerates it,
   exploits it, and gets a shell / foothold.
2. **Pivot (discover + route to the inner subnet).** From the foothold the
   player discovers a **second subnet** they could not see before (second NIC,
   `ip a` / `ip r`, ARP, `/etc/hosts`, routing hints). The inner target is
   **not routable directly** — the player must tunnel/route through the pivot
   host (SSH dynamic forward + proxychains, `sshuttle`, chisel, or manually
   added `ip route`s through the pivot). *Learning the pivot is the point of the
   challenge* — make this beat unmissable but fair.
3. **The objective (inner network).** On the inner subnet sits the **crown-jewel
   host** with the flag behind a **moderately difficult** challenge (see
   difficulty calibration). Solving it reveals the flag.

Keep it to **two stages of real difficulty max** (foothold + inner objective),
with the pivot as the connective tissue. Three full hard stages is too much for
a conference time slot.

## Topology (docker-compose networks)

Model the two segments as two Docker networks. Container reachability enforces
the pivot — players can't shortcut the routing.

```
                 ┌────────────────────┐
  player  ─────► │  guest  (frontend) │  172.20.0.0/24
                 └─────────┬──────────┘
                           │
                   ┌───────▼────────┐   dual-homed
                   │   pivot host   │   (joins BOTH networks)
                   └───────┬────────┘
                           │
                 ┌─────────▼──────────┐
                 │ internal (backend) │  10.10.10.0/24   internal: true
                 └─────────┬──────────┘
                           │
                   ┌───────▼────────┐
                   │  target host   │  (flag lives here)
                   └────────────────┘
```

- `guest` network: player entry. Pivot host is attached here.
- `internal` network: set `internal: true` in compose so Docker gives it **no
  route to the outside** — the only way in is through the pivot container.
- **pivot** container: attached to BOTH networks. This is the dual-homed box
  that makes the pivot necessary and possible.
- **target** container: attached to `internal` ONLY. Not reachable from the
  player until they route through the pivot.

> Note: Docker `internal: true` blocks egress but inter-container traffic on the
> same network still flows. Confirm during testing that the player's host truly
> cannot reach `target` directly and *must* go via `pivot`.

## Difficulty calibration ("moderately difficult")

Aim for a team of two to clear it in **30–75 minutes**.

- **Foothold:** easy→medium. Something enumerable and unambiguous — a web app
  with a classic, discoverable bug (command injection, SSTI, auth bypass, an
  exposed `.git`, weak creds behind a login) or a misconfigured service. The
  player should *recognise* the class of bug, not brute a needle from a
  haystack.
- **Pivot:** not "difficult", but **signposted**. Leave breadcrumbs on the
  foothold box (a second interface, a config file naming the inner host, a
  `known_hosts` entry, shell history). Players who've never pivoted should be
  able to figure it out from the clues.
- **Inner objective:** medium. A crackable hash + privesc, a SUID/`sudo`
  misconfig (`GTFOBins`-style), a readable backup, a locally exploitable service,
  or a small bespoke puzzle. One clear intended path.

### Design principles (CTF quality bar)

- **One obvious intended path.** Minimise unintended solutions — they frustrate
  authors and warp scoring.
- **No guessing / no rabbit holes.** Every rabbit hole costs the player time
  they don't have at a con. If it's not on the path, don't put it there.
- **No real-world collateral.** Everything self-contained; no callbacks to real
  hosts, no bundled live malware, no exploits against anything but this lab.
- **Original content only.** New theme, new flavour text, your own vulnerable
  code. Don't clone an existing HTB/THM box.
- **Deterministic flag.** Static flag string baked in at build; same every run.
- **Robust.** Survives a player `rm -rf`-ing things, fuzzing inputs, or spamming
  the service. Consider a healthcheck / auto-restart so one careless player
  doesn't brick it for the next.

## Flag format

```
flag{...}       # undefined length — no fixed character count
```

- The contents are free-form; don't pad to a fixed length or telegraph the
  length in hints. e.g. `flag{ambush_in_the_arduenna}`.
- One flag at the end by default. Optionally a second "foothold" flag on the
  pivot host to reward partial progress and give organisers a scoring tier
  (same `flag{...}` format).

## Repository layout (target)

```
.
├── CLAUDE.md                 # this file
├── README.md                 # player-facing brief + how to deploy
├── docker-compose.yml        # the whole lab, one command
├── WALKTHROUGH.md            # complete intended solution (keep PRIVATE at the con)
├── pivot/                    # dual-homed foothold box
│   ├── Dockerfile
│   └── app/ ...              # the vulnerable entry service + breadcrumbs
├── target/                   # inner crown-jewel box
│   ├── Dockerfile
│   └── ...                   # the inner vuln + the flag
└── test/
    └── solve.sh             # automated check: runs the golden path, asserts flag
```

## Build / run / test

```bash
# bring the lab up
docker compose up -d --build

# confirm the isolation invariant: player CANNOT reach target directly,
# CAN reach pivot. (Run from the host playing the guest role.)
docker compose ps
# ... manual reachability checks against pivot vs target ...

# verify the challenge is solvable end-to-end
./test/solve.sh            # should pivot, exploit, and print the flag

# tear down
docker compose down -v
```

- `solve.sh` is the regression test: if a change breaks the intended path, this
  catches it. Keep it in sync with `WALKTHROUGH.md`.

## Conventions for Claude in this repo

- When adding a vulnerability, **write a one-line comment** in the code tagging
  it (`# VULN: command injection via `name` param`) so the walkthrough and the
  code stay in lockstep. Strip or keep these deliberately — decide per file.
- Any change to a service's behaviour → **update `WALKTHROUGH.md` and
  `test/solve.sh` in the same change.**
- Keep the two networks' addressing (`172.20.0.0/24`, `10.10.10.0/24`) stable;
  the walkthrough references concrete IPs.
- Prefer small, pinned base images (`debian:stable-slim`, `python:3-slim`) for
  fast, reproducible builds at the con.
- This is intentionally vulnerable software **scoped to this lab**. Normal
  secure-coding rules don't apply inside the challenge services — but everything
  outside the attack surface (the compose plumbing, healthchecks, the flag
  handling) should be clean and robust.

## Open decisions (fill these in)

- [ ] **Theme / narrative** (OT/ICS homage? a different flavour?) -> theme is Ambiorix
- [ ] **Foothold vuln** (web? service? which class?)
- [ ] **Pivot technique** expected (SSH -D + proxychains / sshuttle / chisel /
      manual `ip route`)
- [ ] **Inner objective** vuln + privesc
- [ ] **Single flag or foothold + final**
- [ ] **How the player enters the guest network** at the con (OpenVPN profile?
      a dropped-in container they attach to? wifi like the reactor lab?)


## some extra keynotes from the client:

Evidence of accomplishment
BSides Limburg is a community security conference (CORDA Campus, Hasselt). As part of this course, every IT Ninja builds one complete, original CTF challenge that could be run at the conference's CTF. This is your chance to give something back to the community and to prove you understand a vulnerability deeply enough to stage it, not just exploit it.
Your deliverable is a self-contained, deployable challenge: source, hosting setup, flag(s), a solve walkthrough, and, where the challenge runs as a service, a working docker-compose.yml so the organizers can spin it up with a single command. Think of it as forging a trap worthy of the Shogun's own palace: elegant, fair, and solvable by exactly one intended path.
What makes a good challenge

A clear category: web, crypto, reverse engineering, pwn, forensics, OSINT, IoT/hardware, misc.
A single, well-defined intended solution path. No unintended shortcuts, no bruteforce-only wins,...
A flag in a recognizable format, e.g. BSLIM{...}.
A difficulty rating (easy / medium / hard) with an honest estimate of solve time.
Reproducible and stateless where possible, so it can be reset between solvers.

Trials Every Ninja Must Conquer

Concept & approval: Propose your challenge idea (category, vulnerability, learning objective, target difficulty) and get it approved before building.
Build the challenge: Create the vulnerable application/artifact and embed the flag(s). Ensure the intended path works and document any traps or rabbit holes you deliberately included.
Containerize it: Deliver a docker-compose.yml (plus Dockerfile(s) and any needed files) so the challenge can be deployed with docker compose up. For non-service challenges (e.g. a static file, a crypto puzzle), deliver the artifact(s) plus clear hosting instructions instead.
Harden the box: The challenge container must expose only what the challenge needs. No flag readable outside the intended path, no default credentials on the host, no way to pivot off the challenge into the infrastructure.
Flag & scoring info: Provide the flag(s), the flag format, and suggested point value.
Walkthrough: Write a complete step-by-step author walkthrough (shared only with the instructors/organizers) proving the challenge is solvable exactly as intended.
Playtest: Have at least one fellow IT Ninja attempt your challenge and record their feedback (was it fair? unintended solutions? too easy/hard?).
Ops readiness: Include a short "run book": how to deploy, how to reset, expected resource use, and how to healthcheck it.
Deadline: Semester 1.

Deliverable checklist (what you submit)
your-challenge/
├── README.md               # title, category, difficulty, author, description shown to players
├── docker-compose.yml      # one-command deploy (for service challenges)
├── Dockerfile(s)           # build instructions
├── challenge/              # source of the vulnerable app / artifacts
├── flag.txt                # the flag(s) + format (kept private)
├── WALKTHROUGH.md          # author's intended solution (private, for organizers)
└── RUNBOOK.md              # deploy / reset / healthcheck / resource notes
