# 🚀 Tuto Live 4 : Réseau Overlay et DNS Privé (Tailscale & AdGuard)

**Contexte :** Vous avez des services qui tournent (Sentinel, Adminer), mais pour y accéder, vous devez soit faire des tunnels SSH compliqués, soit être physiquement à l'X. Nous voulons un accès "Transparent" : taper `sentinel.homelab` dans le navigateur de votre téléphone, n'importe où dans le monde, et que ça fonctionne.

**Objectifs :**
1. Créer un annuaire DNS privé (**AdGuard Home**) pour gérer les domaines `.homelab`.
2. Monter un tunnel VPN sécurisé (**Tailscale**) qui traverse tous les firewalls.
3. Configurer le **Split DNS** pour ne pas ralentir votre connexion internet classique.


---
## 🗺️ Navigation
- [🏠 Accueil](../README.md)
- [🔭 Vision](../VISION.md)
- [🏗️ État de l'Art](../STATE_OF_THE_ART.md)
- [🕒 Évolution](../EVOLUTION.md)
- [🚀 Live Tutorials](README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](../AGENT.md)
