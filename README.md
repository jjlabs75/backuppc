# BackupPC Docker

[![Docker](https://img.shields.io/badge/docker-ready-blue?logo=docker)](https://www.docker.com/)
[![Podman](https://img.shields.io/badge/podman-compatible-purple?logo=podman)](https://podman.io/)
[![Debian](https://img.shields.io/badge/debian-12--slim-red?logo=debian)](https://www.debian.org/)
[![BackupPC](https://img.shields.io/badge/BackupPC-4.4.0-green)](https://backuppc.github.io/backuppc/)

Containerized [BackupPC](https://backuppc.github.io/backuppc/) backup solution based on `debian:12-slim`.  
Installed from the official Debian repository. Compatible with Docker, Podman, and rootless runtimes.

---

<br>

## Project Structure

```
.
├── build/
│   ├── apache/
│   │   └── backuppc.conf                # Apache configuration for BackupPC
│   ├── Dockerfile                       # Dockerfile to build the image
│   └── entrypoint.sh                    # Container startup script
├── docker-compose.override.yml.example  # Rootless runtime override (Podman / Docker rootless)
├── docker-compose.yml                   # Main service definition
├── .env.example                         # Environment variable template
└── README.md
```

---

<br>

## Quick Start

### Clone the repo

```bash
git clone https://github.com/jjlabs75/backuppc.git
```

```bash
cd backuppc
```

<br>

### Build the image from source

```bash
sudo docker build -t backuppc:4.4.0 ./build
```

<br>

### Create the environment file

Create a `.env` file:

```bash
cp .env.example .env
```

<br>

### Start the container

```bash
sudo docker compose up -d
```

```bash
sudo docker compose logs
```

<br>

Required variables:

| Variable | Default | Description |
|---|---|---|
| `WEBUI_USER` | `backuppc` | Username for the BackupPC WebUI |
| `WEBUI_PASSWORD` | `backuppc` | Password for the BackupPC WebUI |
| `HTTP_PORT` | `80` | Host port mapped to the WebUI |
| `TZ` | `Europe/Paris` | Timezone |
| `ROOTLESS_RUNTIME` | `false` | Set to `true` for Podman or Docker rootless — enables `ping` for non-root users |

<br>

Persistent paths:

| Variable | Example | Description |
|----------|---------|-------------|
| `BACKUPPC_CONFIG_VOL` | `./data/backuppc/config` | Named volume or host path for BackupPC configuration (`/etc/backuppc`) |
| `BACKUPPC_DATA_VOL` | `./data/backuppc/data` | Named volume or host path for backup data (`/var/lib/backuppc`) — **back this up!** |
| `BACKUPPC_LOGS_VOL` | `./data/backuppc/logs` | Named volume or host path for logs (`/var/log/backuppc`) |

> **⚠️ Never delete the `BACKUPPC_DATA_VOL` volume** — it contains all your backups and SSH keys.

<br>

### For rootless container runtime like podman or docker in rootless mode
If you encounter the following errors while running the container in rootless mode (Podman, Docker rootless, etc.):

- `no ping response from srv-target1`
- `can't ping srv-target1 (client = srv-target1); exiting`

Please enable the provided Docker Compose override file for rootless environments.

```bash
cp docker-compose.override.yml.example docker-compose.override.yml
```

The override file adds the `NET_RAW` capability to the container.<br><br>

Also set `ROOTLESS_RUNTIME=true` in the `.env` file.<br>

Restart the container

```bash
sudo docker compose up -d
```

---

<br>

## SSH Key Management

BackupPC uses passwordless SSH to connect to backup targets. An **ED25519 key pair** is automatically generated for the `backuppc` user on first startup, stored in `/var/lib/backuppc/.ssh/id_ed25519` (persisted in the `BACKUPPC_DATA_VOL` volume).

<br>

**Retrieve the public key** to deploy on target hosts:

```bash
sudo docker compose exec backuppc cat /var/lib/backuppc/.ssh/id_ed25519.pub
```

The public key is also printed in the container logs at first boot:

```bash
sudo docker compose logs backuppc | grep -A5 "Public key"
```

<br>

**Deploy the key to a target host:**
```bash
sudo docker compose exec -it backuppc su - backuppc -c "ssh-copy-id target-user@target-server"
```

Or manually copy the public SSH server key `id_ed25519.pub` to the target host at `/home/{userName}/.ssh/authorized_keys.

<br>

### First Connection to a Host

On the first SSH connection to a new target, SSH refuses to connect until the host fingerprint is added to `known_hosts`. Run this command **once per new target**:

```bash
sudo docker compose exec -it backuppc su - backuppc -c "ssh -o StrictHostKeyChecking=accept-new target-user@target-server"
```

This connects as the `backuppc` user and automatically accepts and stores the remote host's fingerprint. BackupPC will then be able to back up that host without further intervention.

<br>

### Host Key Changed

If a target server is rebuilt or its SSH host key rotates, BackupPC backups will fail with:

```
Host key verification failed.
```

**Step 1 — Remove the stale fingerprint:**

```bash
sudo docker compose exec -it backuppc su - backuppc -c "ssh-keygen -R target-server"
```

**Step 2 — Accept the new fingerprint:**

```bash
sudo docker compose exec -it backuppc su - backuppc -c "ssh -o StrictHostKeyChecking=accept-new target-user@target-server"
```

---

<br>

## Upgrade

```bash
# Pull the new image
sudo docker compose pull

# Recreate the container (volumes are preserved)
sudo docker compose up -d
```

> Configuration and backup data live in volumes and are never touched by image upgrades.

---

<br>

## Troubleshooting

**Container status and health:**
```bash
sudo docker compose ps
```

```bash
sudo docker inspect backuppc-backuppc-1 --format '{{json .State.Health}}' | python3 -m json.tool
```

**Live logs:**
```bash
sudo docker compose logs -f backuppc
```

**Shell in the container:**
```bash
sudo docker compose exec -it backuppc bash
```

**Test WebUI reachability:**
```bash
echo $(sudo docker compose exec backuppc curl -s -o /dev/null -w "%{http_code}" http://localhost/backuppc)
```
401 = Apache is running and authentication is active (expected)<br>
000 = Apache is not responding

**Apache daemon status:**
```bash
sudo docker compose exec backuppc service apache2 status
```

**Reset the WebUI password:**  
Update `WEBUI_PASSWORD` in `.env` — the password is applied at every container start.
```bash
sudo docker compose up -d
```
