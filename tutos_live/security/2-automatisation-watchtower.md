# 🛡️ Sécurité 2 : Mises à jour Automatiques avec Watchtower

**Contexte :** Dans une infrastructure Docker classique, les conteneurs vieillissent. Une faille de sécurité est découverte dans Traefik ? Une nouvelle fonctionnalité sort pour ton bot ? Sans automatisation, vous devez manuellement faire des `docker pull`, `stop`, `rm` et `run` pour chaque service.

**Objectif :** Garder vos conteneurs à jour automatiquement sans casser vos services critiques (comme les bases de données).

---

## 💂‍♂️ 1. Le concept

**Watchtower** est un "gardien de nuit" :
*   Il se réveille à une heure définie (ex : 5h00 du matin).
*   Vérifie sur Docker Hub si une image plus récente existe.
*   Télécharge l'image si elle est disponible.
*   Redémarre le conteneur avec la **même configuration** (ports, volumes, variables).
*   Supprime l'ancienne image pour libérer de l'espace.

---

## 🏗️ 2. Déploiement (Docker Compose)

Configuration optimisée pour environnement Proxmox/Docker récent.

### Création de la stack
Dans **Portainer ➔ Stacks ➔ Add stack** ➔ Nom : `maintenance` ou `watchtower`.

*   **Template complet :** [https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/watchtower.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/watchtower.yaml)

---

## ⚠️ 3. Gestion des exclusions (sécurité)

**Important :** Ne pas mettre à jour tous les conteneurs aveuglément. Exemple : une mise à jour majeure de PostgreSQL (v16 ➔ v17) peut rendre les fichiers de base de données illisibles sans migration manuelle.

### Interdire Watchtower sur un conteneur
Ajoutez ce label dans le `docker-compose.yml` du service concerné :
```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=false"
```

**Recommandations :**
*   ✅ **Activer Watchtower pour :** `traefik`, `whoami`, `sentinel`, `wa-bot`, `portainer`.
*   ❌ **Désactiver Watchtower pour :** `postgres`, `adguard` (sauf si backups assurés).

---

## ✅ 4. Vérification du fonctionnement

### Logs au démarrage
```bash
docker logs watchtower
```
Tu dois voir : `Starting Watchtower and scheduling first run: 0 0 5 * * *`.

### Exécution manuelle (Run Once)
Si vous voulez forcer une mise à jour immédiate :
```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e DOCKER_API_VERSION=1.44 \
  containrrr/watchtower --run-once
```

---

## 🩺 5. Diagnostic des erreurs courantes

*   **`client version 1.25 is too old`**
    *   **Cause :** Incompatibilité avec Docker Engine v27+.
    *   **Solution :** Ajouter `DOCKER_API_VERSION=1.44` dans l'environnement.
*   **`dial tcp ... i/o timeout`**
    *   **Cause :** Watchtower ne sort pas sur Internet.
    *   **Solution :** Vérifier le NAT ou ajouter le `http_proxy`.
*   **Conteneur redémarré mais config perdue**
    *   **Cause :** Absence de volumes persistants.
    *   **Solution :** Utiliser impérativement des volumes pour stocker les données importantes.

---
## 🗺️ Navigation
- [🏠 Accueil](../../README.md)
- [🔭 Vision](../../VISION.md)
- [🏗️ État de l'Art](../../STATE_OF_THE_ART.md)
- [🕒 Évolution](../../EVOLUTION.md)
- [🚀 Live Tutorials](../README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](../../AGENT.md)
