# 🚀 Tuto Live 3 : Industrialisation, Sécurité et DevOps

**Contexte :** L'infrastructure réseau et applicative est désormais fonctionnelle. Mais pour passer du bricolage à une véritable "Production", nous devons sécuriser les accès et automatiser les déploiements. On ne veut plus coder directement sur le serveur, on veut une usine logicielle.

**Objectifs :**
1. Sécuriser l'accès serveur (Utilisateur admin dédié & durcissement SSH).
2. Mettre en place le socle de données (**PostgreSQL & Adminer**).
3. Préparer l'environnement DevOps (**GitLab Runner**, SSH Agent).
4. Déployer un pipeline CI/CD complet (Exemple : Projet "Sentinel").

---

## 🛡️ PHASE 1 : SÉCURISATION DE L'ACCÈS (L'HÔTE PHYSIQUE)

**🤔 Pourquoi faire cela ?**
Utiliser le compte `root` en permanence est une hérésie en sécurité. Si vous faites une erreur de commande ou si un robot trouve votre mot de passe, c'est la fin de votre serveur. Nous allons créer l'utilisateur `ivann` et interdire à `root` de se connecter à distance.

**✅ La Solution :**
1. **Création de l'utilisateur (en root) :**
   ```bash
   adduser ivann
   # Choisissez un mot de passe solide.
   ```
2. **Droits Sudo :**
   ```bash
   apt update && apt install sudo -y
   usermod -aG sudo ivann
   ```
3. **Migration des Clés SSH :** Ne vous enfermez pas dehors ! Copiez vos clés autorisées :
   ```bash
   mkdir -p /home/ivann/.ssh
   cp /root/.ssh/authorized_keys /home/ivann/.ssh/
   chown -R ivann:ivann /home/ivann/.ssh
   chmod 700 /home/ivann/.ssh
   chmod 600 /home/ivann/.ssh/authorized_keys
   ```
4. **Le Verrou SSH :** Modifiez `/etc/ssh/sshd_config` pour bloquer root et les mots de passe :
   *   `PermitRootLogin no`
   *   `PasswordAuthentication no`
   *   `Port 2222` (Rappel du port sécurisé)

---

## 🏗️ PHASE 2 : LE SOCLE DE DONNÉES

**🤔 Pourquoi faire cela ?**
La plupart de vos futurs projets (Django, FastAPI) auront besoin d'une base de données persistante. Plutôt que de créer un Postgres par projet, on crée un socle robuste et mutualisé.

**✅ La Solution :**
Déployez la stack **PostgreSQL + Adminer** via Portainer.
*   **Template :** `templates/postgres_adminer.yaml`
*   **Détail Vital :** Adminer permet de visualiser vos tables sans installer de logiciel sur votre PC.

---

## 🦊 PHASE 3 : L'USINE LOGICIELLE (GITLAB CI/CD)

**🤔 Pourquoi faire cela ?**
Coder via SSH avec VSCode sature la RAM du serveur (le plugin Remote SSH est gourmand). La méthode "Pro" : vous codez sur votre PC, vous `git push`, et le serveur se met à jour tout seul.

**1. Installation du GitLab Runner (Sur le Docker-Host) :**
C'est l'ouvrier qui va exécuter vos ordres.
```bash
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | bash
apt install gitlab-runner -y
usermod -aG docker gitlab-runner # Autorise le runner à piloter Docker
```

**2. Enregistrement :** Allez sur GitLab (Groupe > Build > Runners) pour récupérer votre jeton.
```bash
gitlab-runner register --url "https://gitlab.com" --token "VOTRE_TOKEN" --executor "shell"
```

**3. Le Pipeline Magique :**
Dans chaque projet, déposez un fichier `.gitlab-ci.yml`.
*   **Template Déploiement :** `templates/gitlab-ci-deploy.yaml` (Déploiement simple sur le lab).
*   **Template Miroir GitHub :** `templates/gitlab-sync.yaml` (Pour garder votre portfolio GitHub à jour automatiquement).
*   **Template Complet (Deploy + Sync) :** `templates/gitlab-ci-deploy-sync.yaml` (La solution industrielle totale).

---

## 🔄 PHASE 4 : MIGRATION DU CODE EXISTANT

**🤔 Pourquoi faire cela ?**
Si vous avez commencé un projet (ex: `polytask`) sur le serveur, il faut le rapatrier proprement sur votre PC pour entrer dans le cycle Git.

**✅ La Solution (Depuis votre PC) :**
```bash
mkdir -p ~/Projets/polytask && cd ~/Projets/polytask
scp -r docker-host:/root/polytask/* . # Grâce au ProxyJump du template config !
git init
git remote add origin https://gitlab.com/kpihx-labs/polytask.git
git add . && git commit -m "Import initial" && git push -u origin main
```

**Verdict :** Votre homelab est maintenant une usine automatisée. Un push, et la magie opère. 🛡️🚀
