# 🛠️ Annexe 2 : Termux SSH Homelab Toolkit

**Contexte :** Accès SSH mobile fiable à un homelab sur réseau complexe (DHCP dynamique, absence de DNS local, services exposés via tunnels).

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
3.  **Environnement restreint :** Termux est un Linux userland complet mais avec des chemins spécifiques (`$HOME` dans `/data/data/...`).

---

## 2. Installation & Configuration de Termux

### A. Installation propre (F-Droid recommandé)
Téléchargez Termux depuis F-Droid : [https://f-droid.org/en/packages/com.termux/](https://f-droid.org/en/packages/com.termux/)
*(Évitez le Play Store, la version est obsolète).*

### B. Mise à jour et OpenSSH
```bash
pkg update && pkg upgrade
pkg install openssh
```

### C. Génération et Déploiement de la Clé SSH
```bash
ssh-keygen -t ed25519 -C "termux-homelab" -f ~/.ssh/id_ed25519_termux
# Affichez la clé pour la copier sur vos serveurs
cat ~/.ssh/id_ed25519_termux.pub
```
Ajoutez cette clé dans le fichier `~/.ssh/authorized_keys` de votre **homelab** et de votre **docker-host**.

---

## 3. Configuration SSH optimisée

Créez le fichier `~/.ssh/config` dans Termux :

```text
Host homelab
    HostName 129.104.232.118 # Sera mis à jour par le script
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

---

## 4. Problème : IP dynamique & absence de DNS

### 🛰️ La Solution : Script `homelab_finder.sh`
Comme Android ne supporte pas mDNS, nous utilisons un script qui scanne une plage d'IP autour de la dernière connue, vérifie le **fingerprint SSH** du serveur, et met à jour automatiquement votre config.

**Mise en place :**
1.  **Template complet :** [templates/homelab_finder.sh](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/homelab_finder.sh)
2.  Rendez-le exécutable : `chmod +x ~/homelab/homelab_finder.sh`
3.  Exécutez : `~/homelab/homelab_finder.sh`

---

## 5. Pourquoi `homelab-ui` est essentiel

`homelab-ui` expose des tunnels locaux permettant d’accéder depuis le téléphone à :
*   **Proxmox** ➔ `http://localhost:8006`
*   **Portainer** ➔ `http://localhost:9443`
*   **Services Docker** ➔ `http://localhost:8080` (Traefik Dashboard)

**Limite actuelle :** Les services derrière Traefik (app.homelab) ne fonctionneront pas sans modification du fichier `hosts` (impossible sans root sur Android).

---

## 🎯 Conclusion

Avec Termux + SSH + tunnels + `homelab_finder.sh`, vous obtenez un terminal mobile complet capable de s'auto-réparer en cas de changement d’IP, avec des notifications Telegram stylées pour chaque reconnexion réussie. 📱🛡️

---
## 🗺️ Navigation
- [🏠 Accueil](../../README.md)
- [🔭 Vision](../../VISION.md)
- [🏗️ État de l'Art](../../STATE_OF_THE_ART.md)
- [🕒 Évolution](../../EVOLUTION.md)
- [🚀 Live Tutorials](../README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](../../AGENT.md)
