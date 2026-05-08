# ============================================================
# BackupPC - Dockerfile
# Installation with apt from the official Debian repository
# ============================================================

# ── Source image arguments ──────────────────────────────────────────
ARG DEBIAN_VERSION=12
FROM debian:${DEBIAN_VERSION}-slim

# ── Build arguments ─────────────────────────────────────────────────
ARG DEBIAN_VERSION=12

LABEL maintainer="Jj Labs"
LABEL description="BackupPC on Debian ${DEBIAN_VERSION}"

# ── Environment variables ───────────────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive
ENV TEMPLATE_DIR=/opt/app/template

# ── BackupPC OS User ────────────────────────────────────────────────
RUN groupadd -g 5000 backuppc
RUN useradd -u 5000 -g 5000 -d /var/lib/backuppc -s /bin/sh -m backuppc

# ── Package installation ────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    samba \
    smbclient \
    cifs-utils \
    openssh-client \
    rsync \
    curl \
    rrdtool \
    backuppc \
    && rm -rf /var/lib/apt/lists/*

# ── Copy apache default config file ─────────────────────────────────
COPY ./apache/backuppc.conf /etc/backuppc/apache.conf

# ── Entrypoint script ───────────────────────────────────────────────
COPY ./entrypoint.sh /opt/app/entrypoint.sh
RUN chmod +x /opt/app/entrypoint.sh

# ── Template directories ────────────────────────────────────────────
RUN for dir in /etc/backuppc /var/lib/backuppc /var/log/backuppc; do \
        if [ -d "$dir" ]; then \
            mkdir -p "${TEMPLATE_DIR}${dir%/*}" && \
            mv "$dir" "${TEMPLATE_DIR}$dir" && \
            chown -R backuppc:backuppc "${TEMPLATE_DIR}$dir"; \
        fi; \
    done

# ── Volumes ─────────────────────────────────────────────────────────
VOLUME ["/etc/backuppc", "/var/lib/backuppc", "/var/log/backuppc"]

# ── Ports ───────────────────────────────────────────────────────────
EXPOSE 80

# ── Entrypoint ──────────────────────────────────────────────────────
ENTRYPOINT ["/opt/app/entrypoint.sh"]
