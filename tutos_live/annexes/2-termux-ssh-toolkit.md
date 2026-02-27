# 🛠️ Annexe 2 : Termux SSH Homelab Toolkit

**Contexte : Accès SSH mobile fiable à un homelab sur réseau complexe (DHCP dynamique, absence de DNS local, services exposés via tunnels).**

---

## 1. Contexte & Objectifs

L’usage de Termux sur Android permet de transformer un smartphone en **véritable terminal Linux**, capable de :
*   se connecter en SSH à un homelab ou un serveur distant,
*   exécuter des scripts automatisés,
*   gérer des tunnels locaux (Proxmox, Portainer, Traefik…),
*   compenser l’absence de DNS local (mDNS/Avahi impossible sur Android),
*   maintenir une configuration SSH stable malgré les changements d’IP.

Cependant, trois contraintes majeures apparaissent immédiatement :
1.  **Absence de DNS local :** Android ne supporte pas Avahi/mDNS ➔ impossible d’utiliser `homelab.local`.
2.  **IP dynamique (DHCP) :** Le serveur peut changer d’IP ➔ les connexions SSH cassent.
3.  **Besoin d’un environnement Linux cohérent sur Android :** Termux n’est pas un simple terminal : c’est un **Linux userland complet**.

**Objectif final :** Créer un environnement Termux capable de se connecter en SSH, exposer des services via tunnels, détecter automatiquement les changements d’IP, et envoyer des notifications Telegram.

---

## 2. Installation & Configuration de Termux

### A. Installation propre (F-Droid recommandé)
Téléchargez Termux depuis F-Droid : [https://f-droid.org/en/packages/com.termux/](https://f-droid.org/en/packages/com.termux/)
*(Le Play Store est obsolète).*

### B. Mise à jour de l’environnement
```bash
pkg update && pkg upgrade
```

### C. Installation d’OpenSSH
```bash
pkg install openssh
```

### D. Génération d’une clé SSH dédiée à Termux
```bash
ssh-keygen -t ed25519 -C "termux-homelab" -f ~/.ssh/id_ed25519_termux
# Affichez la clé publique pour la copier
cat ~/.ssh/id_ed25519_termux.pub
```

### E. Ajouter la clé publique sur les serveurs
Ajoutez cette clé dans le fichier `~/.ssh/authorized_keys` de votre **homelab** et de votre **docker-host**.

---

## 3. Configuration SSH optimisée

Créez le fichier `~/.ssh/config` dans Termux :

```text
Host homelab
    HostName 129.104.232.118
    User ivann
    Port 2222
    ServerAliveInterval 60
    IdentityFile ~/.ssh/id_ed25519_termux

Host homelab-ui
    HostName 129.104.232.118
    User ivann
    Port 2222
    ServerAliveInterval 60
    LocalForward 8006 localhost:8006
    LocalForward 9443 10.10.10.10:9443
    LocalForward 8443 10.10.10.10:443
    LocalForward 8080 10.10.10.10:80
    IdentityFile ~/.ssh/id_ed25519_termux

Host docker-host
    HostName 10.10.10.10
    User root
    ProxyJump homelab
    IdentityFile ~/.ssh/id_ed25519_termux
```

**Accès aux services depuis le téléphone :**
*   **Proxmox :** `http://localhost:8006`
*   **Portainer :** `http://localhost:9443`
*   **Traefik / Apps :** ❌ ne fonctionnera pas sans DNS interne (car route selon les hostnames).

---

## 4. Problème : IP dynamique & absence de DNS

### 🛰️ Solution : Script `homelab_finder.sh`
Comme Android ne supporte pas Avahi/mDNS, et que l’IP du homelab change régulièrement, il faut :
*   scanner une plage d’IP autour de la dernière connue,
*   vérifier le fingerprint SSH,
*   mettre à jour automatiquement `~/.ssh/config`,
*   envoyer une notification Telegram.

---

## 5. Installation du Script d’Auto‑Découverte

1.  **Template complet :** [templates/homelab_finder.sh](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/homelab_finder.sh)
2.  Rendez le script exécutable : `chmod +x ~/homelab/homelab_finder.sh`
3.  Exécutez : `~/homelab/homelab_finder.sh`

---

## 6. Logs & Notifications

*   **Logs :** `tail -f ~/homelab/homelab_finder.log`
*   **Telegram :** Chaque fois qu’une IP est trouvée, vous recevez une notification stylée :
    `🔧 homelab 🔧`
    `✅ homelab trouvé à 129.104.232.118`

---

## 7. Pourquoi `homelab-ui` est essentiel

`homelab-ui` expose des tunnels locaux permettant d’accéder depuis le téléphone à :
*   Proxmox ➔ `localhost:8006`
*   Portainer ➔ `localhost:9443`
*   Services Docker internes ➔ `localhost:8080`, `localhost:8443`

---

## 🎯 Conclusion

Avec Termux + SSH + tunnels + `homelab_finder.sh`, vous obtenez :
*   un terminal Linux complet sur Android
*   un accès SSH fiable au homelab
*   des tunnels locaux pour Proxmox & Portainer
*   une auto‑réparation en cas de changement d’IP
*   des notifications Telegram stylées


