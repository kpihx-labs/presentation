# 🛠️ Annexe 1 : Network Watchdog (Auto-Réparation)

**Contexte :** Sur le réseau de l'X, la connexion peut sauter si le câble bouge, si le Radius plante ou si l'adaptateur USB chauffe. Pas question de descendre au local serveur pour rebooter manuellement.

**Objectif :** Un script qui vérifie internet toutes les 5 minutes et applique des réparations graduelles selon la gravité.

---

## 🔍 LE PROTOCOLE DE RÉPARATION (LOGIQUE)

Le script (situé dans [scripts/network_watchdog.sh](https://github.com/kpihx-labs/scripts/blob/main/network_watchdog.sh)) est un véritable "cerveau" capable de s'adapter à votre environnement. Il détecte automatiquement si vous êtes en **WI-FI** (via `wlo1` et le driver `nl80211`) ou en **FILAIRE** (via `nic1/vmbr0` et le driver `wired`) en analysant votre fichier `/etc/network/interfaces`.

Il suit ensuite une escalade de la force :
1. **Action 0 :** Simple réveil des interfaces (`down/up`).
2. **Action 1 :** Relance du couple **WPA Supplicant + DHCP** (le cœur de la connectivité à l'X).
3. **Action 2 :** Redémarrage complet du service `networking` de l'hôte (le bouton "nucléaire").
4. **Vérification Conteneur :** Si l'hôte a internet mais que le Docker-Host (`10.10.10.10`) ne répond pas, le script réveille le pont `vmbr1` et force un reboot du conteneur via `pct stop/start`.

---

## 🚀 MISE EN PLACE

1. **Script :** Le script de production est maintenu dans [scripts/network_watchdog.sh](https://github.com/kpihx-labs/scripts/blob/main/network_watchdog.sh).
2. **Dépendances :** Il utilise un fichier `.env` local pour vos jetons Telegram.
3. **Droits :** `chmod +x /root/network_watchdog.sh` (Copie du script vers root recommandée).
4. **Automatisation :** Ajoutez au crontab de root :
   ```bash
   */5 * * * * /root/network_watchdog.sh
   ```

**Détail Vital :** Le script utilise un **Lockfile** (`/tmp/network_fixing.lock`) pour éviter que deux instances ne se lancent en même temps. Si une réparation dure plus de 15 minutes, le verrou est automatiquement cassé pour permettre une nouvelle tentative.

**Verdict :** Depuis la V3 de ce watchdog, le serveur a une disponibilité de 99.9% même sur un réseau instable. Il vous préviendra même sur Telegram si votre IP publique change ! 🛡️🛰️

---
## 🗺️ Navigation
- [🏠 Accueil](../../README.md)
- [🔭 Vision](../../VISION.md)
- [🏗️ État de l'Art](../../STATE_OF_THE_ART.md)
- [🕒 Évolution](../../EVOLUTION.md)
- [🤖 Agent Mandate](../../AGENT.md)
