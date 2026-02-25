# 🛠️ Annexe 2 : Termux SSH Homelab Toolkit

**Contexte :** Vous voulez gérer votre lab depuis votre smartphone (RER, école). Mais Android ne supporte pas le DNS local (`.local`). Si l'IP du serveur change, votre session SSH est perdue.

**Objectif :** Transformer Termux en véritable poste de commande mobile capable de retrouver le serveur tout seul.

---

## 🛰️ LE HACK DE DÉCOUVERTE (HOMELAB_FINDER)

Puisque mDNS ne marche pas, on a écrit un script qui scanne les adresses IP autour de la dernière connue et vérifie l'**empreinte SSH (Fingerprint)**. Si l'empreinte correspond, le script sait que c'est votre serveur.

**✅ La Solution :**
1. **Script :** Installez le script de découverte dans votre Termux.
2. **Fonctionnement :**
   *   Scan une plage d'IP (ex: `129.104.232.*`).
   *   Compare le fingerprint.
   *   Mise à jour automatique de votre `~/.ssh/config`.
   *   Envoie une notif Telegram : *"Homelab trouvé à l'IP 129.104.x.y !"*.

---

## 🧱 CONFIGURATION OPTIMISÉE

Pour que ce soit confortable, votre config SSH Termux doit être calquée sur celle de votre PC :
*   **Host `homelab-ui` :** Avec les tunnels LocalForward (Portainer, Traefik).
*   **Host `docker-host` :** Via ProxyJump.

**Verdict :** Votre homelab est littéralement dans votre poche, stable et auto-réparable. 📱🛡️

---
## 🗺️ Navigation
- [🏠 Accueil](../../README.md)
- [🔭 Vision](../../VISION.md)
- [🏗️ État de l'Art](../../STATE_OF_THE_ART.md)
- [🕒 Évolution](../../EVOLUTION.md)
- [🤖 Agent Mandate](../../AGENT.md)
