# 🚀 Tuto Live 3 : Industrialisation, Sécurité et DevOps

**Contexte :** L'infrastructure réseau et applicative est désormais fonctionnelle. Mais pour passer du bricolage à une véritable "Production", nous devons sécuriser les accès et automatiser les déploiements. On ne veut plus coder directement sur le serveur, on veut une usine logicielle.

**Objectifs :**
1.  **Sécuriser l'accès serveur** (Création d'un utilisateur admin & durcissement SSH).
2.  **Mettre en place le socle de données** (PostgreSQL & Adminer).
3.  **Préparer l'environnement DevOps** (GitLab Runner, SSH Agent).
4.  **Installer le GitLab Runner** sur le serveur.
5.  **Déployer un pipeline CI/CD complet** (Exemple : Projet "Sentinel").

---

## 🛡️ PHASE 1 : SÉCURISATION DE L'ACCÈS (SUR L'HÔTE PROXMOX)

### 🤔 Pourquoi faire cela ?
L'usage direct du compte `root` est dangereux. Nous créons un compte administrateur dédié (`ivann`) et bloquons l'accès root à distance.

**1. Création de l'utilisateur et privilèges (en root) :**
```bash
adduser ivann
# Entrez un mot de passe fort à la demande.
```

**2. Installation de sudo (si absent sur Debian minimal) :**
```bash
apt update && apt install sudo -y
```

**3. Élévation de privilèges :**
```bash
usermod -aG sudo ivann
```

**4. Transfert de la clé SSH existante :**
Pour ne pas perdre l'accès, on copie la clé autorisée de root vers le nouvel utilisateur.
```bash
mkdir -p /home/ivann/.ssh
cp /root/.ssh/authorized_keys /home/ivann/.ssh/
chown -R ivann:ivann /home/ivann/.ssh
chmod 700 /home/ivann/.ssh
chmod 600 /home/ivann/.ssh/authorized_keys
```

**5. Durcissement SSH :**
Éditez le fichier `/etc/ssh/sshd_config` et appliquez les modifications suivantes :
*   `PermitRootLogin no` (Interdit la connexion directe en root)
*   `PasswordAuthentication no` (Clé SSH obligatoire)
*   `PubkeyAuthentication yes`
*   `Port 2222` (Rappel du port configuré précédemment)

**6. Application :**
```bash
systemctl restart ssh
```

---

## 🛡️ PHASE 1-BIS : CONFIGURATION LOCALE (SUR VOTRE PC)

Il faut désormais configurer votre PC pour utiliser l'utilisateur `ivann` pour le bastion (l'hôte), tout en gardant `root` pour les conteneurs LXC (standard LXC).

**Fichier :** `~/.ssh/config`
*   **Template complet :** [https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/ssh_config](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/ssh_config)

---

## 🏗️ PHASE 2 : SOCLE DE DONNÉES (POSTGRESQL & ADMINER)

### 🤔 Pourquoi faire cela ?
*   **Postgres** est le standard de base de données pour Python (Django/FastAPI).
*   **Adminer** offre une interface Web légère pour gérer la base de données.

**✅ Déploiement via Portainer (Stack "database") :**
*   **Template :** [https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/postgres_adminer.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/postgres_adminer.yaml)

---

## 🦊 PHASE 3 : PRÉPARATION GITLAB (LOCAL & DISTANT)

**Philosophie :** On ne développe plus directement sur le serveur. Le workflow est : **PC ➔ GitLab ➔ Serveur.**

**Sur votre PC portable :**
1.  **Clé SSH dédiée :** `ssh-keygen -t ed25519 -C "gitlab-key" -f ~/.ssh/id_ed25519_gitlab`
2.  **GitLab :** Ajoutez la clé publique dans *User Settings > SSH Keys*.
3.  **SSH-Agent :** Pour que votre PC "prête" sa clé au serveur lors du déploiement :
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519_gitlab
```

**Sur GitLab.com :**
1.  Créez le groupe **"KpihX Labs"** (`kpihx-labs`).
2.  Définissez les variables CI/CD globales (*Settings > CI/CD > Variables*) :
    *   `DB_PASS`, `CHAT_ID`, `TELEGRAM_TOKEN`, `GITHUB_TOKEN`.
`GITHUB_TOKEN` est un token (classic) à créer sur github avec les droits:
* repo
* admin:org
* delete_repo

---

## ⚙️ PHASE 4 : INSTALLATION DU GITLAB RUNNER (SUR DOCKER HOST)

Le Runner est l'agent qui exécute vos pipelines de déploiement directement sur votre serveur.

**1. Installation du paquet :**
```bash
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | bash
apt install gitlab-runner -y
```

**2. Permissions (CRITIQUE) :**
On autorise le runner à piloter Docker.
```bash
usermod -aG docker gitlab-runner
```

**3. Enregistrement :**
Récupérez le Token dans *GitLab Group > Build > Runners*.
```bash
gitlab-runner register \
  --url "https://gitlab.com" \
  --token "VOTRE-GLRT-TOKEN" \
  --executor "shell" \
  --description "Homelab Docker Host" \
  --tag-list "homelab"
```

---

## 🚀 PHASE 5 : DÉPLOIEMENT AUTOMATISÉ (CI/CD) - EXEMPLE "SENTINEL"

Créez le fichier `.gitlab-ci.yml` à la racine de votre projet sur votre PC.

**Templates disponibles :**
*   **Déploiement simple :** [https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/gitlab-ci-deploy.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/gitlab-ci-deploy.yaml)
*   **Synchronisation GitHub :** [https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/gitlab-sync.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/gitlab-sync.yaml)
*   **Pipeline Complet (Deploy + Sync) :** [https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/gitlab-ci-deploy-sync.yaml](https://github.com/kpihx-labs/presentation/blob/main/tutos_live/templates/gitlab-ci-deploy-sync.yaml)

---
**⚠️ IMPORTANT :** L'API de Github pourra souvent être capricieuse, il faudra dans ce cas (échec de création du repo / repo not found) aller créer dans l'org, un repo vide portant le nom escompté.

---

## 🔄 PHASE 6 : MIGRATION DU CODE (EX: POLYTASK)

**Scénario :** Rapatrier un projet déjà codé sur le serveur vers votre PC local pour le versionner.

**Sur votre PC portable :**
1.  **Rapatriement via SCP :** (Le tunnel `ssh/config` gère le rebond automatiquement)
```bash
mkdir -p ~/Projets/polytask && cd ~/Projets/polytask
scp -r docker-host:/root/polytask/* .
```

2.  **Initialisation Git & Nettoyage :**
```bash
echo ".env" >> .gitignore
echo "__pycache__" >> .gitignore
git init
git branch -M main
git remote add origin https://gitlab.com/kpihx-labs/polytask.git
```

3.  **Premier Push :**
```bash
git add .
git commit -m "Migration: Import initial depuis Homelab"
git push -u origin main
```

---
## 🗺️ Navigation
- [🏠 Accueil](https://kpihx-labs.github.io/presentation/#/README.md)
- [🔭 Vision](https://kpihx-labs.github.io/presentation/#/VISION.md)
- [🏗️ État de l'Art](https://kpihx-labs.github.io/presentation/#/STATE_OF_THE_ART.md)
- [🕒 Évolution](https://kpihx-labs.github.io/presentation/#/EVOLUTION.md)
- [🚀 Live Tutorials](https://kpihx-labs.github.io/presentation/#/tutos_live/README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](https://kpihx-labs.github.io/presentation/#/AGENT.md)
