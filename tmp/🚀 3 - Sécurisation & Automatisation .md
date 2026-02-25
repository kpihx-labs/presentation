
**Contexte :** L'infrastructure réseau et applicative est désormais fonctionnelle\. Nous passons maintenant en mode "Production"\.

**Objectifs :**
1.  **Sécuriser l'accès serveur** \(Création d'un utilisateur admin & durcissement SSH\)\.
2.  **Mettre en place le socle de données** \(PostgreSQL & Adminer\)\.
3.  **Préparer l'environnement DevOps** \(GitLab, SSH Agent\)\.
4.  **Installer le GitLab Runner** sur le serveur\.
5.  **Déployer un pipeline CI/CD complet** \(Exemple : Projet "Sentinel"\)\.

***

## PHASE 1 : SÉCURISATION DE L'ACCÈS \(SUR L'HÔTE PROXMOX\)

### Pourquoi ?
L'usage direct du compte `root` est dangereux\. Nous créons un compte administrateur dédié \(`ivann`\) et bloquons l'accès root à distance\.

**1\. Création de l'utilisateur et privilèges \(en root\) :**
```warp-runnable-command
adduser ivann
# Entrez un mot de passe fort à la demande.

```
**2\. Installation de sudo \(si absent sur Debian minimal\) :**
```warp-runnable-command
apt update && apt install sudo -y

```
**3\. Élévation de privilèges :**
```warp-runnable-command
usermod -aG sudo ivann

```
**4\. Transfert de la clé SSH existante :**
Pour ne pas perdre l'accès, on copie la clé autorisée de root vers le nouvel utilisateur\.
```warp-runnable-command
mkdir -p /home/ivann/.ssh
cp /root/.ssh/authorized_keys /home/ivann/.ssh/
chown -R ivann:ivann /home/ivann/.ssh
chmod 700 /home/ivann/.ssh
chmod 600 /home/ivann/.ssh/authorized_keys

```
**5\. Durcissement SSH :**
Éditez le fichier `/etc/ssh/sshd_config` et appliquez les modifications suivantes :
*   `PermitRootLogin no` \(Interdit la connexion directe en root\)
*   `PasswordAuthentication no` \(Clé SSH obligatoire\)
*   `PubkeyAuthentication yes`
*   `Port 2222` \(Rappel du port configuré précédemment\)

**6\. Application :**
```warp-runnable-command
systemctl restart ssh

```
***

## PHASE 1\-BIS : CONFIGURATION LOCALE \(SUR VOTRE PC\)

Il faut désormais configurer votre PC pour utiliser l'utilisateur `ivann` pour le bastion \(l'hôte\), tout en gardant `root` pour les conteneurs LXC \(standard LXC\)\.

**Fichier :** `~/.ssh/config`
```text
# --- HOMELAB (Bastion Physique) ---
Host homelab
    HostName homelab.local
    User ivann              # <--- CHANGEMENT : On n'utilise plus root ici
    Port 2222
    ForwardAgent yes        # Vital pour propager vos clés vers GitLab/Serveur
    ServerAliveInterval 60

# --- DOCKER HOST (Conteneur LXC) ---
Host docker-host
    HostName 10.10.10.10
    User root               # On reste root DANS le conteneur
    ProxyJump homelab       # On rebondit via ivann@homelab
    ForwardAgent yes        # On propage la clé pour le Runner

```
***

## PHASE 2 : SOCLE DE DONNÉES \(POSTGRESQL & ADMINER\)

### Pourquoi ?
*   **Postgres** est le standard de base de données pour Python \(Django/FastAPI\)\.
*   **Adminer** offre une interface Web légère pour gérer la base de données\.

**Déploiement via Portainer \(Stack "database"\) :**
```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${DB_USER}       # ex: admin (Défini dans variables Portainer)
      POSTGRES_PASSWORD: ${DB_PASS}   # ex: |ciPher7
      POSTGRES_DB: app_db
    networks:
      - proxy
    volumes:
      - pg_data:/var/lib/postgresql/data

  adminer:
    image: adminer:4-standalone
    container_name: adminer
    restart: unless-stopped
    networks:
      - proxy
    environment:
      # Permet à Adminer de voir Postgres sans passer par le proxy externe
      - NO_PROXY=postgres,db.homelab
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.adminer.rule=Host(`db.homelab`)"
      - "traefik.http.routers.adminer.entrypoints=websecure"
      - "traefik.http.routers.adminer.tls=true"
      - "traefik.http.routers.adminer.middlewares=auth" # BasicAuth Traefik

volumes:
  pg_data:

networks:
  proxy:
    external: true

```
***

## PHASE 3 : PRÉPARATION GITLAB \(LOCAL & DISTANT\)

**Philosophie :** On ne développe plus directement sur le serveur\. Le workflow est : **PC \-> GitLab \-> Serveur\.**

**Sur votre PC portable :**
1.  **Clé SSH dédiée :** `ssh-keygen -t ed25519 -C "gitlab-key" -f ~/.ssh/id_ed25519_gitlab`
2.  **GitLab :** Ajoutez la clé publique dans *User Settings > SSH Keys*\.
3.  **SSH\-Agent :** Pour que votre PC "prête" sa clé au serveur lors du déploiement :
```warp-runnable-command
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519_gitlab

```
**Sur GitLab\.com :**
1.  Créez le groupe **"KpihX Labs"** \(`kpihx-labs`\)\.
2.  Définissez les variables CI/CD globales \(*Settings > CI/CD > Variables*\) :
    *   `DB_PASS`, `CHAT_ID`, `TELEGRAM_TOKEN`, `GITHUB_TOKEN`\.
`GITHUB_TOKEN` est un token \(classic\) à créer sur github avec les droits:
* repo
* admin:org
* delete\_repo

***

## PHASE 4 : INSTALLATION DU GITLAB RUNNER \(SUR DOCKER HOST\)

Le Runner est l'agent qui exécute vos pipelines de déploiement directement sur votre serveur\.

**1\. Installation du paquet :**
```warp-runnable-command
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | bash
apt install gitlab-runner -y

```
**2\. Permissions \(CRITIQUE\) :**
On autorise le runner à piloter Docker\.
```warp-runnable-command
usermod -aG docker gitlab-runner

```
**3\. Enregistrement :**
Récupérez le Token dans *GitLab Group > Build > Runners*\.
```warp-runnable-command
gitlab-runner register \
  --url "https://gitlab.com" \
  --token "VOTRE-GLRT-TOKEN" \
  --executor "shell" \
  --description "Homelab Docker Host" \
  --tag-list "homelab"

```
***

## PHASE 5 : DÉPLOIEMENT AUTOMATISÉ \(CI/CD\) \- EXEMPLE "SENTINEL"

Créez le fichier `.gitlab-ci.yml` à la racine de votre projet sur votre PC :

```yaml
stages:
  - deploy
  - sync

# --- JOB 1 : DÉPLOIEMENT SUR HOMELAB ---
deploy_homelab:
  stage: deploy
  tags:
    - homelab   # Cible votre Runner installé en Phase 4
  only:
    - main
  script:
    - echo "🚀 Démarrage du déploiement..."
    # 1. Génération dynamique du .env avec les secrets GitLab
    - echo "TELEGRAM_TOKEN=$TELEGRAM_TOKEN" > .env
    - echo "CHAT_ID=$CHAT_ID" >> .env
    # 2. Nettoyage préventif et mise à jour
    - docker rm -f sentinel || true
    - docker compose up -d --build --force-recreate --remove-orphans
    - docker image prune -f
    - echo "✅ Déploiement terminé !"

# --- JOB 2 : SYNCHRO VERS GITHUB (VITRINE) ---
sync_github:
  stage: sync
  variables:
    GITHUB_ORG: "KpihX-Lab"
    REPO_NAME: "sentinel"
  only:
    - main
  script:
    - echo "🔄 Synchronisation vers GitHub..."
    # Création du repo via API si inexistant et push forcé
    - |
      curl -H "Authorization: token ${GITHUB_TOKEN}" \
           -X POST \
           -d "{\"name\":\"${REPO_NAME}\", \"private\":false}" \
           https://api.github.com/orgs/${GITHUB_ORG}/repos || true
    - git remote add github https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_ORG}/${REPO_NAME}.git || git remote set-url github https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_ORG}/${REPO_NAME}.git
    - git push github $CI_COMMIT_SHA:refs/heads/main --force

```
***
**IMPORTANT:** L'API de Github pourra souvent être capricieuse, il faudra dans ce cas \(échec de création du repo / repo not found\) aller créer dans l'org, un repo vide portant le nom escompté\.

## PHASE 6 : MIGRATION DU CODE \(EX: POLYTASK\)

**Scénario :** Rapatrier un projet déjà codé sur le serveur vers votre PC local pour le versionner\.

**Sur votre PC portable :**
1.  **Rapatriement via SCP :** \(Le tunnel `ssh/config` gère le rebond automatiquement\)
```warp-runnable-command
mkdir -p ~/Projets/polytask && cd ~/Projets/polytask
scp -r docker-host:/root/polytask/* .

```
2.  **Initialisation Git & Nettoyage :**
```warp-runnable-command
echo ".env" >> .gitignore
echo "__pycache__" >> .gitignore
git init
git branch -M main
git remote add origin https://gitlab.com/kpihx-labs/polytask.git

```
3.  **Premier Push :**
```warp-runnable-command
git add .
git commit -m "Migration: Import initial depuis Homelab"
git push -u origin main
```
