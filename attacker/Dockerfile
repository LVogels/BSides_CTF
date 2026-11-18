# ATTACKER — the player's foothold box on the guest ("frontier") network.
# Attach to it with:  docker compose exec attacker bash
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      nmap proxychains4 openssh-client sshpass curl \
      iproute2 iputils-ping dnsutils netcat-openbsd \
      python3 less vim-tiny ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Pre-configured proxychains: SOCKS5 via the SSH -D tunnel on 127.0.0.1:1080.
COPY proxychains.conf /etc/proxychains4.conf

# A short brief so a player who just exec's in knows where to start.
COPY brief.txt /root/brief.txt
RUN echo 'cat /root/brief.txt' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
