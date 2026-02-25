# 🛡️ Sécurité 2 : Mises à jour Automatiques avec Watchtower

**Contexte :** Dans une infrastructure Docker classique, les conteneurs vieillissent. Une faille de sécurité est découverte dans Traefik ? Une nouvelle fonctionnalité sort pour ton bot ? Sans automatisation, vous devez manuellement faire des `docker pull`, `stop`, `rm` et `run` pour chaque service.

**Objectif :** Garder vos conteneurs à jour automatiquement sans casser vos services critiques (comme les bases de données).

---

## 💂‍♂️ PHASE 1 : LE GARDIEN DE NUIT (WATCHTOWER)

**Watchtower** est un "gardien de nuit" :
*   Il se réveille à une heure définie (ex : 5h00 du matin).
*   Vérifie sur Docker Hub si une image plus récente existe.
*   Télécharge l'image si elle est disponible.
*   Redémarre le conteneur avec la **même configuration** (ports, volumes, variables).
*   Supprime l'ancienne image pour libérer de l'espace.

**✅ La Solution :**
1.  **Déploiement :** Utilisez le **Template :** [watchtower.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/watchtower.yaml) et déployez-le via Portainer.
2.  **Réglage :** On le programme à 5h du matin, juste après la maintenance système.

---

## ⚠️ PHASE 2 : GESTION DES EXCLUSIONS

**🤔 Pourquoi faire cela ?**
Une mise à jour automatique de PostgreSQL (v16 ➔ v17) peut rendre votre base de données illisible si elle n'est pas migrée manuellement. On veut mettre à jour les apps (Whoami, Sentinel) mais **pas** les socles de données.

**✅ La Solution :**
Ajoutez ce label dans le `docker-compose.yml` de vos services sensibles :
```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=false"
```

**Verdict :** Votre infrastructure est toujours fraîche et sécurisée, sans effort manuel. 🛡️✨

---
## 🗺️ Navigation
- [🏠 Accueil](https://kpihx-labs.github.io/presentation/#/README.md)
- [🔭 Vision](https://kpihx-labs.github.io/presentation/#/VISION.md)
- [🏗️ État de l'Art](https://kpihx-labs.github.io/presentation/#/STATE_OF_THE_ART.md)
- [🕒 Évolution](https://kpihx-labs.github.io/presentation/#/EVOLUTION.md)
- [🚀 Live Tutorials](https://kpihx-labs.github.io/presentation/#/tutos_live/README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](https://kpihx-labs.github.io/presentation/#/AGENT.md)
