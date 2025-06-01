# Homelab Git Autopull & Bootstrap (v3)

_Companion to **Baseline Stack & Architecture (v3)**_  
_Data volumes now live in `/srv/homelab-data` outside the repo._

---

## 0 · Prime Directive

Fast‑forward `/srv/homelab` **without touching** `/srv/homelab-data`, restart stack atomically, never overwrite `.env`.

---

## 1 · Responsibility Matrix

| Concern             | File                                      | Behaviour                                  |
| ------------------- | ----------------------------------------- | ------------------------------------------ |
| First‑run bootstrap | `scripts/bootstrap.sh`                    | Clone → label both trees → enable services |
| Scheduled sync      | `systemd/homelab-gitpull.{service,timer}` | Pull every 5 min                           |
| Manual safety       | `.git/hooks/post-merge`                   | Hot‑reload after local `git pull`          |
| Secrets hygiene     | `.env.example`                            | Copied once, never overwritten             |

---

## 2 · Bootstrap Flow (`scripts/bootstrap.sh`)

1. Verify **git** & **sudo**
2. Clone repo _or_ FF‑pull existing clone
3. Create `/srv/homelab-data` if absent
4. Set ownership + SELinux labels on **both** paths
5. Enable & start `homelab-core.service`

> **Note:** script updated—check latest in repo.

---

## 3 · Auto‑Pull Service

```ini
ExecStart     = /usr/bin/git pull --ff-only origin main
ExecStartPost = /usr/bin/docker compose -f stacks/core.yml up -d --pull always
```

Failure leaves running containers intact; unit flagged failed for alerting.

---

## 4 · Timer Cadence

Every **5 min** with **2 min** post‑boot delay.

---

## 5 · Manual Fallback

```bash
docker compose -f stacks/core.yml up -d --pull always
```

---

## 6 · .ENV Contract

`.env` still resides in `/srv/homelab/.env` (inside the repo).  
`rm -rf /srv/homelab` **will delete it**—back it up or store secrets manager‑side if this is a risk.

Sample keys (unchanged):

```bash
TS_AUTHKEY=
CF_TUNNEL_TOKEN=
CF_DOMAIN=
WATCHTOWER_POLL_INTERVAL=300
SHOUTRRR_URL=
DUKAHUB_ADMIN_PW=
```

---

## 7 · Disaster Recovery Cheat‑Sheet

| Scenario                      | Command                                                    | Outcome                                     |
| ----------------------------- | ---------------------------------------------------------- | ------------------------------------------- |
| Force re‑clone (volumes safe) | `bash sudo rm -rf /srv/homelab && bash /tmp/bootstrap.sh ` | Repo rebuilt; `/srv/homelab-data` untouched |
| Repo only mildly corrupted    | Remove `.git` then rerun bootstrap                         | Retains working tree & volumes              |
| Pause auto‑pull               | `systemctl disable --now homelab-gitpull.timer`            | Freeze stack                                |

---

## 8 · Future Enhancements

- Pre‑pull YAML lint guard
- Restic backup of **/srv/homelab-data** keyed to git SHA
- Replace polling with webhook

---

### Quick Start

```bash
curl -sSL https://raw.githubusercontent.com/kisinga/homelab/main/scripts/bootstrap.sh | bash
```

Your ThinkCentre self‑updates; your data stays put. 🥂
