# 🛡️ Sécurité 1 : Stratégie de Sauvegarde et Maintenance (3-2-1)

**Contexte :** En auto-hébergement, la panne matérielle n'est pas une question de *"si"*, mais de *"quand"*. Nous appliquons ici une stratégie de classe industrielle pour protéger vos données contre les crashs de SSD ou les erreurs de manipulation.

**Objectifs :**
1. Appliquer la règle du **3-2-1** (3 copies, 2 supports, 1 hors-site).
2. Automatiser la maintenance hebdomadaire (Nettoyage, Mises à jour).
3. Prévoir un **Plan de Reprise d'Activité (PRA)** pour restaurer en moins d'une heure.

---

## 📐 PHASE 1 : LA PHILOSOPHIE DU 3-2-1

*   **Copie A (Production) :** Vos données vivent sur le SSD du serveur.
*   **Copie B (Local) :** Une copie quotidienne sur un HDD externe branché sur votre PC administrateur (pour éviter les instabilités USB du serveur).
*   **Copie C (Cloud) :** Une copie miroir sur Google Drive (protection contre le vol ou l'incendie).

---

## 🛠️ PHASE 2 : MAINTENANCE AUTOMATISÉE

**🤔 Pourquoi faire cela ?**
Un serveur Linux accumule des images Docker inutiles et des logs qui saturent le disque. Une maintenance propre évite les reboots sauvages.

**✅ La Solution :**
1. **Script de Maintenance :** Le script de production est situé dans [live_scripts/maintenance.sh](../../live_scripts/maintenance.sh).
2. **Fonctions :** Il gère les mises à jour APT, le nettoyage Docker (`prune -a`), et vous envoie une notification Telegram avant de déclencher un `reboot` propre pour rafraîchir le noyau et les ports USB.
3. **Automatisation (Cron) :** Programmez l'exécution le samedi à 4h du matin (juste après le snapshot Proxmox) :
   ```bash
   0 4 * * 6 /root/weekly_maintenance.sh
   ```

---

## 🧩 PHASE 3 : SNAPSHOTS PROXMOX (NIVEAU 1)

C'est votre première ligne de défense. Avant toute grosse maintenance, Proxmox crée une image compressée du conteneur.
*   **Réglage :** Samedi à 3h (via l'interface Proxmox > Datacenter > Backup).
*   **Rétention :** Keep Last 2.

---

## 🛰️ PHASE 4 : EXFILTRATION (NIVEAU 2 & 3)

**🤔 Pourquoi sur le PC ?**
Le serveur à l'X est physiquement inaccessible ou instable avec des disques USB. Votre PC Ubuntu sert de "Hub de Sauvegarde".

**✅ La Solution :**
1. **Script d'Exfiltration :** Le script de production est [live_scripts/backup_homelab.sh](../../live_scripts/backup_homelab.sh).
2. **Optimisation RSYNC (Niveau 2) :** Utilisation de l'algorithme `aes128-gcm` (accélération matérielle) et désactivation de la compression SSH (inutile sur du `.zst`) pour une vitesse maximale.
3. **Cloud Direct (Niveau 3) :** Le script n'utilise plus GVFS mais **Rclone** pour un upload direct et robuste vers Google Drive (`gdrive-full`).
4. **Fonctionnement :**
   *   Vérifie la disponibilité SSH.
   *   Synchronise les archives vers votre HDD local (Miroir).
   *   Upload la toute dernière archive vers le dossier `Backup_Homelab` sur Google Drive.
   *   Nettoie le Cloud pour ne garder qu'un seul exemplaire.

**Verdict :** Si votre serveur brûle demain, vos données sont à l'abri sur votre HDD et dans le Cloud. 🛡️🔥
