# CASTRA — dual-homed foothold / pivot host (guest + internal networks)
FROM python:3.11-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive PYTHONUNBUFFERED=1

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      openssh-server curl iproute2 ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# ---- Python app (the vulnerable Frontier Watch Console) ----
WORKDIR /opt/castra
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ /opt/castra/app/

# ---- SSH maintenance account: scout (reachable from the frontier) ----
# Needed so the player can set up the SSH -D dynamic forward through this box.
RUN useradd -m -s /bin/bash scout \
 && echo 'scout:FrontierWatch-54BC' | chpasswd

# ---- Breadcrumb #1: deploy notes readable by the web app user (via RCE) ----
# Reveals the scout SSH creds + the existence/address of the inner camp.
COPY deploy_notes.txt /opt/castra/DEPLOY_NOTES.txt
RUN chmod 0644 /opt/castra/DEPLOY_NOTES.txt

# ---- Breadcrumb #2: muster roll in scout's home (only visible after SSH) ----
# Reveals the inner-camp SSH creds + hints at the root-owned tool there.
COPY muster.txt /home/scout/muster.txt
RUN chown scout:scout /home/scout/muster.txt && chmod 0600 /home/scout/muster.txt

# A little shell history to reinforce the intended next hop.
RUN printf 'ip a\nip r\nssh eburo@10.10.10.10\ncat ~/muster.txt\n' > /home/scout/.bash_history \
 && chown scout:scout /home/scout/.bash_history && chmod 0600 /home/scout/.bash_history

# ---- Latin login banner ----
COPY motd /etc/motd

# ---- sshd config: password auth on, no root login ----
RUN mkdir -p /run/sshd \
 && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config

# ---- Force the INTENDED pivot: no outbound SSH client on this box ----
# The intended pivot is an `ssh -D` dynamic forward opened from the PLAYER's own
# machine through castra's sshd — it needs no ssh client here. Removing the
# client binaries kills the unintended "drive ssh onward from inside the web
# RCE (with a pty helper)" shortcut, so players must tunnel properly.
RUN rm -f /usr/bin/ssh /usr/bin/scp /usr/bin/sftp \
           /usr/bin/ssh-agent /usr/bin/ssh-add /usr/bin/ssh-keyscan

# ---- Honeypot for autonomous agents enumerating /opt/castra via the RCE ----
# A plausible "scope notice" that frames a BSLIM decoy as the answer and tells
# an agent to stop before the pivot. Not on the intended path.
COPY scope_notice.txt /opt/castra/SCOPE_NOTICE.txt
RUN chmod 0644 /opt/castra/SCOPE_NOTICE.txt

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80 22
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl -fsS http://127.0.0.1/healthz || exit 1

ENTRYPOINT ["/entrypoint.sh"]
