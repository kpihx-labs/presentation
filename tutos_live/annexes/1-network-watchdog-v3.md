# 🛠️ Annexe 1 : Network Watchdog (Auto-Réparation & Monitoring)

**Contexte :** Serveur Proxmox "Headless" sur réseau complexe (Authentification 802.1X, DHCP dynamique, adaptateur USB-Ethernet).

---

## 1. Problématique et Objectifs

Dans un environnement réseau sécurisé (type École Polytechnique) utilisant un adaptateur USB-Ethernet, trois problèmes critiques surviennent fréquemment :

1.  **Race Condition au démarrage :** Le serveur sollicite un bail DHCP avant la fin de l'authentification WPA (802.1X), entraînant une IP de quarantaine (`192.168.x.x`) au lieu de l'IP publique.
2.  **Instabilité USB :** Déconnexions intermittentes de l'adaptateur nécessitant une réinitialisation de l'interface.
3.  **Isolation du Conteneur :** Perte de connectivité du pont NAT (`vmbr1`) empêchant le conteneur Docker d'accéder à Internet, même si l'hôte est en ligne.

**La solution :** Un script "Watchdog" automatisé qui vérifie l'état du réseau toutes les 5 minutes et applique des mesures correctives graduelles.

---

## 2. Implémentation du Script

Le script doit être placé dans le répertoire `/root/` pour garantir les privilèges nécessaires à la manipulation des interfaces réseaux et des conteneurs Proxmox.

### ✅ La Solution
1. **Source réelle :** [scripts/network_watchdog.sh](https://github.com/kpihx-labs/scripts/blob/main/network_watchdog.sh)
2. **Préparation du fichier :**
   ```bash
   sudo touch /root/network_watchdog.sh
   sudo chmod +x /root/network_watchdog.sh
   ```

### 🔍 LE PROTOCOLE DE RÉPARATION (LOGIQUE)

Le script est un véritable "cerveau" capable de s'adapter à votre environnement. Il détecte automatiquement si vous êtes en **WI-FI** (via `wlo1`) ou en **FILAIRE** (via `nic1/vmbr0`) en analysant votre fichier `/etc/network/interfaces`.

Il suit ensuite une escalade de la force :
1.  **Action 0 :** Simple réveil des interfaces (`down/up`).
2.  **Action 1 :** Relance du couple **WPA Supplicant + DHCP**.
3.  **Action 2 :** Redémarrage complet du service `networking` de l'hôte (le bouton "nucléaire").
4.  **Vérification Conteneur :** Si l'hôte a internet mais que le Docker-Host (`10.10.10.10`) ne répond pas, le script réveille le pont `vmbr1` et force un reboot du conteneur via `pct stop/start`.

---

## 3. Automatisation avec Cron

Pour que la surveillance soit constante, nous programmons le script pour s'exécuter toutes les 5 minutes.

1.  Ouvrez le crontab de **root** :
    ```bash
    sudo crontab -e
    ```
2.  Ajoutez la ligne suivante à la fin du fichier :
    ```text
    */5 * * * * /root/network_watchdog.sh >> /var/log/cron_watchdog_debug.log 2>&1
    ```
    *Note : La redirection vers le fichier `.log` permet de capturer d'éventuelles erreurs de syntaxe.*

---

## 4. Surveillance et Diagnostics

*   **Vérifier l'activité du script :**
    ```bash
    sudo journalctl -u cron -n 20 --no-pager | grep watchdog
    ```
*   **Consulter les logs métier (pannes et réparations) :**
    ```bash
    sudo tail -f /var/log/network_watchdog.log
    ```
*   **Vérifier la persistance de l'IP :**
    ```bash
    cat /var/lib/homelab_watchdog/last_ip
    ```

---

## 🚨 5. Crash Test (Validation)

Il est recommandé de tester le watchdog pour valider son bon fonctionnement :

1.  **Simuler une panne conteneur :** 
    ```bash
    sudo ip link set vmbr1 down
    ```
2.  **Observer la réaction :**
    *   Suivez les logs : `tail -f /var/log/network_watchdog.log`.
    *   Attendez maximum 5 minutes.
3.  **Résultat attendu :**
    *   Le script détecte la coupure.
    *   Une notification Telegram est envoyée.
    *   L'interface `vmbr1` repasse en `UP` et le conteneur est redémarré.

**Verdict :** Depuis la V3 de ce watchdog, le serveur a une disponibilité de 99.9% même sur un réseau instable. Il vous préviendra même sur Telegram si votre IP publique change ! 🛡️🛰️

---
## 🗺️ Navigation
- [🏠 Accueil](https://kpihx-labs.github.io/presentation/#/README.md)
- [🔭 Vision](https://kpihx-labs.github.io/presentation/#/VISION.md)
- [🏗️ État de l'Art](https://kpihx-labs.github.io/presentation/#/STATE_OF_THE_ART.md)
- [🕒 Évolution](https://kpihx-labs.github.io/presentation/#/EVOLUTION.md)
- [🚀 Live Tutorials](https://kpihx-labs.github.io/presentation/#/tutos_live/README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](https://kpihx-labs.github.io/presentation/#/AGENT.md)
