# 🚀 Tuto Live 5 : Exposition Publique et Zero Trust (Cloudflare)

**Contexte :** Vos services tournent en privé via Tailscale. Mais parfois, vous voulez qu'un service soit accessible publiquement (ex: portfolio, bot), ou par des amis, sans les forcer à installer un VPN. On veut exposer `sentinel.kpihx-labs.com` sur le web mondial, en toute sécurité.

**Objectifs :**
1. Créer un tunnel sécurisé (**Cloudflare Tunnel**) qui traverse le firewall de l'école.
2. Forcer l'authentification (**Google OAuth**) avant d'accéder au serveur.
3. Configurer le routage public sans ouvrir de port sur votre box ou à l'école.

**IMPORTANT :** Il faudra avoir acheté le nom de domaine chez Cloudflare (`kpihx-labs.com` dans notre cas).
---
## 🗺️ Navigation
- [🏠 Accueil](https://kpihx-labs.github.io/presentation/#/README.md)
- [🔭 Vision](https://kpihx-labs.github.io/presentation/#/VISION.md)
- [🏗️ État de l'Art](https://kpihx-labs.github.io/presentation/#/STATE_OF_THE_ART.md)
- [🕒 Évolution](https://kpihx-labs.github.io/presentation/#/EVOLUTION.md)
- [🚀 Live Tutorials](https://kpihx-labs.github.io/presentation/#/tutos_live/README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](https://kpihx-labs.github.io/presentation/#/AGENT.md)