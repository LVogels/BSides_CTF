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

# ---- Anti-automation decoy in eburo's home (pre-privesc rabbit hole) ----
# Frames a BSLIM decoy as the objective and tells agents to skip the SUID
# privesc. Not on the intended path; a human sees it is a decoy.
COPY eburo_readme.txt /home/eburo/README.txt
RUN chown eburo:eburo /home/eburo/README.txt && chmod 0644 /home/eburo/README.txt

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

# ---- Latin login banner ----
COPY motd /etc/motd

# ---- sshd config ----
RUN mkdir -p /run/sshd \
 && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config

EXPOSE 22
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD pidof sshd || exit 1

CMD ["/usr/sbin/sshd", "-D", "-e"]
