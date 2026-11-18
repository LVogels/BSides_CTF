# ATTACKER — the player's foothold box on the guest ("frontier") network.
# Players connect over SSH:   ssh scout@<host> -p 2222      (password: ambiorix)
# (or, as a fallback:         docker compose exec attacker bash )
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      nmap proxychains4 openssh-client openssh-server sshpass sudo curl \
      iproute2 iputils-ping dnsutils netcat-openbsd \
      python3 less vim-tiny ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Pre-configured proxychains: SOCKS5 via the SSH -D tunnel on 127.0.0.1:1080.
COPY proxychains.conf /etc/proxychains4.conf

# ---- Player account: scout (passwordless sudo so nmap raw scans work) ----
ARG PLAYER_USER=scout
ARG PLAYER_PASS=ambiorix
RUN useradd -m -s /bin/bash "$PLAYER_USER" \
 && echo "$PLAYER_USER:$PLAYER_PASS" | chpasswd \
 && echo "$PLAYER_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/player \
 && chmod 0440 /etc/sudoers.d/player

# A short brief shown on login so a player knows where to start.
COPY brief.txt /etc/ambiorix-brief.txt
COPY motd /etc/motd
RUN printf '\ncat /etc/ambiorix-brief.txt\n' | tee -a /home/${PLAYER_USER}/.bashrc /root/.bashrc >/dev/null \
 && chown ${PLAYER_USER}:${PLAYER_USER} /home/${PLAYER_USER}/.bashrc

# ---- sshd: password auth, no root login (players use the scout account) ----
RUN mkdir -p /run/sshd \
 && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D", "-e"]
