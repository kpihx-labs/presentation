# 🛡️ Sécurité 3 : Le Bouclier d'Inactivité (Auto-Logout & SSH Timeout)

**Contexte :** Vous avez fini de travailler sur le vieux PC dans votre chambre ou vous avez fermé votre laptop sans couper la session SSH. Le risque : Toute personne passant devant l'écran a les pleins pouvoirs (root). Une session "fantôme" qui traîne est une faille critique de sécurité physique et numérique.

**Objectif :** Faire en sorte que le serveur "détecte" votre absence et verrouille la porte automatiquement, sans jamais interrompre vos conteneurs Docker ou vos sauvegardes qui tournent en tâche de fond.

---

## 🔒 PHASE 1 : LA VARIABLE MAGIQUE (TMOUT)

**🤔 Pourquoi faire cela ?**
La variable `TMOUT` est un réglage natif du shell (Bash). Si aucune touche n'est pressée pendant un temps défini, le shell tue la session proprement.

**✅ La Solution :**
Éditez le profil global du système (`/etc/profile` sur Proxmox en root) et ajoutez ces lignes tout à la fin :
```bash
# --- SÉCURITÉ KPIHX-LABS ---
# Déconnexion auto après 10 minutes d'inactivité (600 secondes)
TMOUT=600
readonly TMOUT # Empêche quiconque (même vous) de taper TMOUT=0 pour contourner
export TMOUT
```

---

## 🛰️ PHASE 2 : CHASSER LES SESSIONS FANTÔMES (SSH)

**🤔 Pourquoi faire cela ?**
Parfois votre connexion 4G coupe, mais le serveur croit que vous êtes encore là. On veut qu'il vérifie votre présence réelle de manière agressive.

**✅ La Solution (Le fichier `sshd_config`) :**
Voici un extrait de la configuration en production via la connexion `kpihx-labs-ui` (qui prouve que l'Agent Forwarding et le PAM sont bien activés) :

```text
└─[$] <> ssh kpihx-labs-ui
Linux pve 6.17.2-1-pve #1 SMP PREEMPT_DYNAMIC PMX 6.17.2-1 (2025-10-21T11:55Z) x86_64
You have mail.
Last login: Tue Feb 24 21:49:54 2026 from 100.82.95.70
ivann@pve:~$ cat /etc/ssh/sshd_config
# ...
Port 2222
PermitRootLogin no
PubkeyAuthentication yes
PubkeyAcceptedKeyTypes ssh-ed25519
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM yes
AllowAgentForwarding yes
AllowTcpForwarding yes
X11Forwarding no
ClientAliveInterval 60
ClientAliveCountMax 3
ChannelTimeout global=30m
UnusedConnectionTimeout 5m
```

**Explication des paramètres de sécurité :**
*   `ClientAliveInterval 60` : Le serveur envoie un ping invisible au client toutes les minutes.
*   `ClientAliveCountMax 3` : S'il n'y a pas de réponse 3 fois de suite, la connexion est tuée net.
*   `UsePAM yes` : Active le module Pluggable Authentication Modules (nécessaire sur Debian).
*   `AllowAgentForwarding yes` : Vital pour que le proxyjump (`homelab-ui` / `docker-host`) fonctionne.

*(N'oubliez pas de redémarrer le service : `systemctl restart ssh`)*

---

## 💡 L'ASTUCE DE L'EXPERT : NE PAS PERDRE SON TRAVAIL (TMUX)

**🤔 Le Problème :**
*"Mais si je lance une compilation de 1 heure, elle va se couper à cause du TMOUT ?"*. 
Oui, sauf si vous utilisez **Tmux**.

**✅ La Solution (Detach & Attach) :**
1. **Créer la session :** Lancez `tmux new -s maintenance`.
2. **Lancer la tâche :** (ex: `apt upgrade` ou `docker build`).
3. **Le crash ou le TMOUT :** Même si la connexion est tuée (TMOUT), le serveur ferme votre session SSH, mais le processus à l'intérieur de tmux continue dans sa bulle.
4. **Le retour :** À votre reconnexion, tapez `tmux a -t maintenance` et vous retrouvez tout exactement là où vous l'avez laissé.

**Verdict :** Ton infrastructure est maintenant protégée contre l'oubli humain. La forteresse se verrouille d'elle-même dès que tu tournes le dos. 🚀🛡️
