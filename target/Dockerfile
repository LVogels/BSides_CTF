# ARDUENNA — inner crown-jewel host (internal network only)
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      openssh-server gcc libc6-dev \
 && rm -rf /var/lib/apt/lists/*

# ---- Inner-camp SSH account: eburo (low privilege) ----
RUN useradd -m -s /bin/bash eburo \
 && echo 'eburo:ArduennaShadow' | chpasswd

# ---- The flag: root-only, NOT readable by eburo ----
COPY flag.txt /root/flag.txt
RUN chown root:root /root/flag.txt && chmod 0600 /root/flag.txt

# ---- The vulnerable SUID binary + readable source (signposting) ----
COPY castellum.c /usr/local/src/castellum.c
RUN gcc -o /usr/local/bin/castellum /usr/local/src/castellum.c \
 && chown root:root /usr/local/bin/castellum \
 && chmod 4755 /usr/local/bin/castellum \
 && chmod 0644 /usr/local/src/castellum.c
# gcc stays installed so players can (optionally) compile; harmless in the lab.

# ---- sshd config ----
RUN mkdir -p /run/sshd \
 && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

EXPOSE 22
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD pidof sshd || exit 1

CMD ["/usr/sbin/sshd", "-D", "-e"]
