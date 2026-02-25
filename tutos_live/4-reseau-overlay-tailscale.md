# 🚀 Tuto Live 4 : Réseau Overlay et DNS Privé (Tailscale & AdGuard)

**Contexte :** Vous avez des services qui tournent (Sentinel, Adminer), mais pour y accéder, vous devez soit faire des tunnels SSH compliqués, soit être physiquement à l'X. Nous voulons un accès "Transparent" : taper `sentinel.homelab` dans le navigateur de votre téléphone, n'importe où dans le monde, et que ça fonctionne.

**Objectifs :**
1. Créer un annuaire DNS privé (**AdGuard Home**) pour gérer les domaines `.homelab`.
2. Monter un tunnel VPN sécurisé (**Tailscale**) qui traverse tous les firewalls.
3. Configurer le **Split DNS** pour ne pas ralentir votre connexion internet classique.
---
## 🗺️ Navigation
- [🏠 Accueil](https://kpihx-labs.github.io/presentation/#/README.md)
- [🔭 Vision](https://kpihx-labs.github.io/presentation/#/VISION.md)
- [🏗️ État de l'Art](https://kpihx-labs.github.io/presentation/#/STATE_OF_THE_ART.md)
- [🕒 Évolution](https://kpihx-labs.github.io/presentation/#/EVOLUTION.md)
- [🚀 Live Tutorials](https://kpihx-labs.github.io/presentation/#/tutos_live/README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](https://kpihx-labs.github.io/presentation/#/AGENT.md)