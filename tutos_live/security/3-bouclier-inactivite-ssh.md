# 🛡️ Sécurité 3 : Le Bouclier d'Inactivité (Auto-Logout & SSH Timeout)

**Contexte :** Vous avez fini de travailler sur le vieux PC dans votre chambre ou vous avez fermé votre laptop sans couper la session SSH. Le risque : Toute personne passant devant l'écran a les pleins pouvoirs (root). Une session "fantôme" qui traîne est une faille critique de sécurité physique et numérique.

**Objectif :** Faire en sorte que le serveur "détecte" votre absence et verrouille la porte automatiquement, sans jamais interrompre vos conteneurs Docker ou vos sauvegardes qui tournent en tâche de fond.


---
## 🗺️ Navigation
- [🏠 Accueil](../../README.md)
- [🔭 Vision](../../VISION.md)
- [🏗️ État de l'Art](../../STATE_OF_THE_ART.md)
- [🕒 Évolution](../../EVOLUTION.md)
- [🚀 Live Tutorials](../README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](../../AGENT.md)
