
# 1\. Le concept
Dans une infrastructure Docker classique, les conteneurs vieillissent\. Une faille de sécurité est découverte dans Traefik ? Une nouvelle fonctionnalité sort pour ton bot ?

Sans Watchtower, tu dois manuellement exécuter :
```warp-runnable-command
docker pull
docker stop
docker rm
docker run
```
pour chaque service\.
**Watchtower** est un "gardien de nuit" :
* Il se réveille à une heure définie \(ex : 5h00 du matin\)\.
* Vérifie sur Docker Hub si une image plus récente existe\.
* Télécharge l'image si elle est disponible\.
* Redémarre le conteneur avec la **même configuration** \(ports, volumes, variables\)\.
* Supprime l'ancienne image pour libérer de l'espace\.
***
## 2\. Déploiement \(Docker Compose\)
Configuration optimisée pour environnement Proxmox/Docker récent\.
### Création de la stack
Dans **Portainer** → **Stacks** → **Add stack** → Nom : `maintenance` ou `watchtower`
```warp-runnable-command
services:
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /etc/localtime:/etc/localtime:ro

    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_SCHEDULE=0 0 5 * * *
      - DOCKER_API_VERSION=1.44
      # - http_proxy=http://129.104.201.11:8080
      # - https_proxy=http://129.104.201.11:8080
      # - WATCHTOWER_NOTIFICATIONS=shoutrrr
      # - WATCHTOWER_NOTIFICATION_URL=telegram://TOKEN_BOT@telegram/?channels=CHAT_ID
```
***
## 3\. Gestion des exclusions \(sécurité\)
⚠️ **Important** : Ne pas mettre à jour tous les conteneurs aveuglément\.
Exemple : mise à jour majeure de PostgreSQL \(v16 → v17\) peut rendre les fichiers de base de données illisibles sans migration\.
### Interdire Watchtower sur un conteneur
Ajouter ce label dans le [`docker-compose.yml`](https://docker-compose.yml) du service concerné :
```warp-runnable-command
labels:
  - "com.centurylinklabs.watchtower.enable=false"
```
**Recommandations** :
* ✅ Activer Watchtower pour : `traefik`, `whoami`, `sentinel`, `wa-bot`, `portainer`
* ❌ Désactiver Watchtower pour : `postgres`, `adguard` \(sauf si backups assurés\)
***
## 4\. Vérification du fonctionnement
### Logs au démarrage
```warp-runnable-command
docker logs watchtower
```
Tu dois voir :
```warp-runnable-command
Starting Watchtower and scheduling first run: 0 0 5 * * *
```
Pas d'erreur rouge liée à l'API Docker\.
### Exécution manuelle \(Run Once\)
```warp-runnable-command
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e DOCKER_API_VERSION=1.44 \
  containrrr/watchtower --run-once
```
***
## 5\. Diagnostic des erreurs courantes
### `client version 1.25 is too old`
* **Cause** : Incompatibilité avec Docker Engine v27\+
* **Solution** : Ajouter `DOCKER_API_VERSION=1.44`
### `dial tcp ... i/o timeout`
* **Cause** : Watchtower ne sort pas sur Internet
* **Solution** : Vérifier le NAT ou ajouter `http_proxy`
### Conteneur redémarré mais config perdue
* **Cause** : Absence de volumes persistants
* **Solution** : Utiliser des volumes pour stocker les données importantes
```warp-runnable-command

```
