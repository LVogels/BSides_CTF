Target: a Flask/gunicorn app ("Castra Legionis"), a TryHackMe/BSides CTF. Two hosts, one network-pivot between them.

1. Credential disclosure (initial foothold)

The /login page had leaked creds in an HTML comment (tiro / AveLegioXIV-54) — classic view-source enumeration. Logged in, got a Flask session cookie.

2. Server-Side Template Injection → RCE

The watch-report sigil field was passed straight into Flask's render_template_string(). Test payload {{7*7}} rendered as 49 → Jinja2 is evaluating my input. Escalated to code execution with a globals-walk gadget:
{{ cycler.__init__.__globals__.os.popen('id').read() }}
That gave me RCE as www-data on host castra. (The app had a weak if "config" in sigil filter; the cycler gadget reaches os without touching config, so it sailed past.)

3. Local privilege/credential harvesting

www-data was in the root group, so I could read root-group-readable files:
- /opt/castra/DEPLOY_NOTES.txt → scout's SSH password.
- Then su scout (piping the password through the RCE) → read /home/scout/muster.txt, which held eburo / ArduennaShadow and a note: the "inner camp" arduenna (10.10.10.10) is reachable only by pivoting through castra.

4. Network pivot

castra was dual-homed: eth0 on the frontier net, eth1 on 10.10.10.5 (the internal net). 10.10.10.10:22 was reachable from castra but not from outside. No sshpass on the box, so I dropped a tiny Python pty helper and drove it over the web RCE to feed eburo's password to ssh eburo@10.10.10.10. Foothold on arduenna as eburo.

5. SUID PATH-hijack → root

/usr/local/bin/castellum was SUID root, and its source gave it away:
setuid(0); setgid(0);
system("date +\"...\"");      // 'date' invoked with NO absolute path
system() runs via /bin/sh, which resolves date through $PATH. Since the binary explicitly drops to uid/gid 0 first, that date runs as root. So:
echo -e '#!/bin/sh\ncat /root/flag.txt' > /tmp/date
chmod +x /tmp/date
PATH=/tmp:$PATH /usr/local/bin/castellum   # runs my fake 'date' as root
→ uid=0(root).

🏆 flag{atuatuca_ambush_54bc}

Phase mapping: initial-access (leaked creds) → initial-access (SSTI RCE) → cred-access/lateral (su + loot) → lateral (pivot SSH) → privesc (SUID $PATH abuse). Two independent app bugs + two config/dev mistakes, chained.

Remediation, in order of impact: (1) never pass user input to render_template_string — use render_template with context vars; (2) no secrets in HTML comments or world/group-readable deploy notes; (3) don't store lateral creds in readable home files; (4) in SUID programs, call binaries by absolute path and sanitize PATH/env — ideally avoid system() entirely (execve with a fixed path).

---

Two housekeeping calls for you:
- Write-back: I want to add a Privesc/Privesc - SUID PATH hijack.md note (the reusable step-5 lesson), then commit the Castra session's vault additions (the new SSTI note + Privesc note + index updates) to git. OK?
- Cleanup: delete the Active/Castra/ working folder now that the box is done, or keep it around a bit? (No undo on the delete — your call.)
