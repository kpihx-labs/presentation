# 🛡️ Sécurité 1 : Stratégie de Sauvegarde et Maintenance (3-2-1)

**Contexte :** Infrastructure de production.
**Objectif :** Garantir la pérennité des données et la stabilité à long terme (Règle du 3‑2‑1).

> **Architecture Phoenix v3.1** — Tous les scripts sont maintenant regroupés dans des dossiers portables (`proxmox/` et `docker_host/`) déployés directement dans `/root/` de chaque nœud. Plus aucun script dans `/usr/local/bin/` ou `/root/scripts/`.

---

## 1. 📐 Philosophie : La Règle du 3‑2‑1

En auto‑hébergement (Homelab), la panne matérielle ou l'erreur humaine n'est pas une question de *si*, mais de *quand*. Nous appliquons la stratégie industrielle **3‑2‑1**, adaptée à nos contraintes :

### 🔢 Rappel de la règle
1. **3 copies de vos données**
    *   Copie A : Production (SSD du serveur)
    *   Copie B : Locale (HDD externe)
    *   Copie C : Distante (Google Drive)
2. **2 supports différents**  
    *   SSD vs disque mécanique (HDD)
3. **1 copie hors‑site**  
    *   Cloud (protection contre le vol ou l'incendie)

---

## 2. 🛠️ Maintenance Préventive (Sur le Serveur)

Un **script hebdomadaire** automatise les mises à jour, le nettoyage Docker et le redémarrage.

**📜 Script :**
- **Local :** [`sh/proxmox/maintenance.sh`](https://gitlab.com/kpihx-labs/scripts/-/blob/main/proxmox/maintenance.sh)
- **Déployé à :** `/root/proxmox/maintenance.sh` sur `kpihx-labs`
- **Log :** `/var/log/maintenance.log`

Ce script réalise :
1. Mise à jour APT (`update`, `upgrade`, `autoremove`)
2. Nettoyage Docker (`docker system prune` via `pct exec 100`)
3. Notification Telegram avant/après.
4. Reboot propre.

**⏱️ Automatisation (Cron Root sur `kpihx-labs`) :**
```cron
0 4 * * 6 /root/proxmox/maintenance.sh
```
Planification : **Samedi à 04h00** (après le backup Proxmox de 03:00).

---

## 🧩 3. Sauvegarde Niveau 1 : Snapshot Local (Proxmox)

C'est la **première ligne de défense**. Proxmox crée une image compressée (`.tar.zst`) du conteneur sans interruption de service.

### ✅ Configuration (Interface Web)
*   **Datacenter ➔ Backup ➔ Add**
*   **Node :** `kpihx-labs`
*   **Schedule :** `03:00` le samedi
*   **Sélection :** Conteneur `100` (docker‑host)
*   **Mode :** Snapshot / Compression ZSTD
*   **Rétention :** Keep Last 2

---

## 🛰️ 4. Sauvegarde Niveau 2 & 3 : Exfiltration (PC Client)

Le PC Ubuntu sert de **hub de sauvegarde** :
1. Récupère les backups depuis le serveur (pull via `rsync` over SSH).
2. Les copie sur le HDD externe (Rétention : 2 derniers).
3. Envoie la dernière version sur Google Drive via `rclone` (Rétention : 1 dernier).

**📜 Script :**
- **Local :** [`sh/proxmox/backup_docker_host/backup_docker_host_local.sh`](https://gitlab.com/kpihx-labs/scripts/-/blob/main/proxmox/backup_docker_host/backup_docker_host_local.sh)
- **Déployé à :** Uniquement sur le PC local (pas sur le serveur)
- **Usage :** `./backup_docker_host_local.sh`
- **Pré-requis :** HDD monté à `/media/kpihx/KpihX-Backup`, alias SSH `homelab` configuré.

**Rétention :**
| Destination | Chemin | Keep |
| :--- | :--- | :--- |
| HDD externe | `KpihX-Backup/Homelab/Backups/Docker_Host/` | 2 derniers |
| Google Drive | `Homelab/Backups/Docker_Host/` | 1 dernier |

---

## 🚨 5. Plan de Reprise d'Activité (PRA)

### 🟦 Scénario A — *Erreur logicielle* (Gravité : Faible)
1. Corrigez le code sur votre PC.
2. `git push` GitLab pour déclencher le CI/CD.

### 🟧 Scénario B — *Erreur système* (Gravité : Moyenne)
**"La maintenance a planté le conteneur"**
1. Accédez à Proxmox WebUI : `https://kpihx-labs:8006`
2. **Stockage local ➔ Backups** — sélectionnez le fichier de 03:00.
3. Cliquez sur **Restore**.
⏱️ *Rétablissement : ~5 minutes*

### 🟥 Scénario C — *Catastrophe totale* (Gravité : Critique)
**"Le SSD du serveur est mort"**
1. Réinstallez Proxmox (ISO USB).
2. Déployez à nouveau `/root/proxmox/` (voir `sh/proxmox/README.md`).
**📜 Script :**
- **Local :** [`sh/proxmox/backup_docker_host/restore_docker_host.sh`](https://gitlab.com/kpihx-labs/scripts/-/blob/main/proxmox/backup_docker_host/restore_docker_host.sh)
- **Déployé à :** `/root/proxmox/backup_docker_host/restore_docker_host.sh` sur `kpihx-labs`

   Ce script télécharge automatiquement la dernière archive depuis `gdrive-x:Homelab/Backups/Docker_Host` vers `/var/lib/vz/dump/`.
4. Restaurez le conteneur :
   ```bash
   pct restore 100 /var/lib/vz/dump/vzdump-lxc-100-YYYY_MM_DD-HH_MM_SS.tar.zst --storage local-lvm
   pct start 100
   ```
⏱️ *Rétablissement complet : ~1 heure*

---

## 🛰️ 6. Sauvegarde Niveau 4 : Hook Automatique (Proxmox → Cloud)

Dès que le backup de 03:00 se termine, Proxmox déclenche automatiquement le script de Cloud Sync via le mécanisme de **hook**.

**📜 Script :**
- **Local :** [`sh/proxmox/backup_docker_host/vzdump-hook.sh`](https://gitlab.com/kpihx-labs/scripts/-/blob/main/proxmox/backup_docker_host/vzdump-hook.sh)
- **Déployé à :** `/root/proxmox/backup_docker_host/vzdump-hook.sh`
- **Activé via :** `/etc/vzdump.conf` → `script: /root/proxmox/backup_docker_host/vzdump-hook.sh`
- **Log :** `/var/log/vzdump-rclone.log`

Le hook :
1. Se déclenche en phase `job-end`.
2. Identifie le fichier `.tar.zst` le plus récent dans `/var/lib/vz/dump/`.
3. L'upload vers `gdrive-x:Homelab/Backups/Docker_Host` (paramètres optimisés).
4. Purge les archives Cloud plus anciennes (garde le 1 plus récent).
5. Envoie une notification Telegram.

---

## 🔐 7. Sauvegarde Souveraine : Vaultwarden

**Architecture Zero-Trust** : La clé de chiffrement est **dérivée de votre Master Password Bitwarden** via `SHA-256 + salt` et n'est **jamais stockée sur disque** (sauf pour le script automatisé serveur qui utilise `/root/.vault_secret`).

### 7a. Backup Automatisé (Serveur)
**📜 Script :**
- **Local :** [`sh/docker_host/backup_vault/backup_vault_server.sh`](https://gitlab.com/kpihx-labs/scripts/-/blob/main/docker_host/backup_vault/backup_vault_server.sh)
- **Déployé à :** `/root/docker_host/backup_vault/backup_vault_server.sh` sur `docker-host`
- **Log :** `/var/log/vault-backup.log`
- **Cron :** `0 2 * * 0 /root/docker_host/backup_vault/backup_vault_server.sh >> /var/log/vault-backup.log 2>&1`

### 7b. Backup Manuel (PC)
**📜 Script :**
- **Local :** [`sh/docker_host/backup_vault/backup_vault_local.sh`](https://gitlab.com/kpihx-labs/scripts/-/blob/main/docker_host/backup_vault/backup_vault_local.sh)
- **Déployé à :** PC local uniquement
- **Usage :** `./backup_vault_local.sh` (demande le Master Password Bitwarden)

### 7c. Restauration (Disaster Recovery)
**📜 Script :**
- **Local :** [`sh/docker_host/backup_vault/restore_vault.sh`](https://gitlab.com/kpihx-labs/scripts/-/blob/main/docker_host/backup_vault/restore_vault.sh)
- **Déployé à :** `/root/docker_host/backup_vault/restore_vault.sh` sur `docker-host`
- **Usage :** `/root/docker_host/backup_vault/restore_vault.sh` (liste les backups Cloud, demande le Master Password Bitwarden)

**Rétention Vault :**
| Destination | Chemin | Keep |
| :--- | :--- | :--- |
| HDD externe | `KpihX-Backup/Homelab/Backups/Vault/` | 3 derniers |
| Google Drive | `Homelab/Backups/Vault/` | 3 derniers |

---

## 📅 8. Planning Complet des Opérations

| Quand | Qui | Quoi | Log |
| :--- | :--- | :--- | :--- |
| **Dim 02:00** | Cron `docker-host` | Dump SQLite + GPG AES-256 + Upload Cloud | `/var/log/vault-backup.log` |
| **Sam 03:00** | Proxmox WebUI | Snapshot LXC 100 local | `/var/log/vzdump-*.log` |
| **Sam ~03:10** | Hook `vzdump-hook.sh` | Sync Cloud du snapshot | `/var/log/vzdump-rclone.log` |
| **Sam 04:00** | Cron `kpihx-labs` | APT + Docker Prune + Reboot | `/var/log/maintenance.log` |
| **Toutes 4 min** | Cron `kpihx-labs` | Watchdog réseau auto-réparant | `/var/log/network_watchdog.log` |
| **À chaque reboot** | Cron `kpihx-labs` | Notification Telegram | `/var/log/boot_notify_debug.log` |
| **Manuel** | PC | Miroir HDD depuis PVE + sync Cloud | — |
| **Manuel** | PC | Backup Vault local chiffré | — |
