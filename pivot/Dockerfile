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

# ---- sshd config: password auth on, no root login ----
RUN mkdir -p /run/sshd \
 && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80 22
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl -fsS http://127.0.0.1/healthz || exit 1

ENTRYPOINT ["/entrypoint.sh"]
