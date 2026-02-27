# 🛡️ Sécurité 3 : Le Bouclier d'Inactivité (Auto-Logout & SSH Timeout)

**Contexte :** Vous avez fini de travailler sur le vieux PC dans votre chambre ou vous avez fermé votre laptop sans couper la session SSH. Le risque : Toute personne passant devant l'écran a les pleins pouvoirs (root). Une session "fantôme" qui traîne est une faille de sécurité physique et numérique.

**L'Objectif :** Faire en sorte que le serveur "détecte" votre absence et verrouille la porte automatiquement, sans jamais interrompre vos conteneurs Docker ou vos sauvegardes qui tournent en tâche de fond.

---

## 🔒 1. La Variable Magique : `TMOUT`

La variable `TMOUT` est un réglage natif du shell (Bash). Si aucune touche n'est pressée pendant un temps défini, le shell tue la session proprement.

**Action (Sur Proxmox en root) :**
On va rendre ce réglage global et impossible à contourner. Éditez le profil global du système (`/etc/profile`) et ajoutez ces lignes tout à la fin :

```bash
# --- SÉCURITÉ KPIHX-LABS ---
# Déconnexion auto après 10 minutes d'inactivité (600 secondes)
TMOUT=600
readonly TMOUT
export TMOUT
```

**🤔 Pourquoi `readonly` ?**
C'est la touche "Pro". Cela empêche quiconque (même vous) de taper `TMOUT=0` pour désactiver la sécurité pendant une session. C'est gravé dans le marbre dès la connexion.

---

## 🛰️ 2. Chasser les Sessions Fantômes (SSH)

Parfois, votre connexion 4G coupe, mais le serveur croit que vous êtes encore là. Il garde la session ouverte "au cas où". On va lui dire d'être plus agressif.

**Action :**
Éditez le fichier `/etc/ssh/sshd_config` et ajustez ces paramètres :

```text
# Envoyer un "Tu es là ?" toutes les 5 minutes
ClientAliveInterval 300

# Si le client ne répond pas 1 fois, on coupe !
ClientAliveCountMax 1
```

**🤔 Pourquoi ce réglage ?**
Cela force le serveur à vérifier la présence réelle du client. Si vous perdez votre réseau, le serveur ferme la session immédiatement au lieu de la laisser flotter dans le vide.

*(N'oubliez pas de redémarrer le service : `systemctl restart ssh`)*

---

## 🖥️ 3. Le Cas de l'Écran Physique (La Console)

Grâce au `TMOUT` configuré à l'étape 1, votre vieux PC dans votre chambre ne restera plus jamais sur un prompt `root#` toute la nuit. Après 10 minutes de silence, il reviendra automatiquement sur l'écran de login Proxmox.

---

## 💡 L'Astuce de l'Expert : Ne pas perdre ses travaux

**🤔 Le Problème :**
*"Mais si je lance une compilation de 1 heure, elle va se couper à cause du TMOUT ?"*. 
Non, si vous utilisez **Tmux**.

### Tmux (Terminal Multiplexer)

**1. Le Concept : "Detach & Attach"**
Normalement, un terminal est lié à votre session SSH. Si la session coupe, le terminal meurt. Avec **Tmux**, le terminal tourne directement sur le serveur, indépendamment de votre connexion.

1.  Vous vous connectez en SSH.
2.  Vous ouvrez une **session tmux**.
3.  Vous lancez votre tâche.
4.  Vous pouvez vous **déconnectez** (volontairement ou par accident).
5.  Le serveur continue de faire tourner la tâche dans sa bulle.
6.  Vous revenez plus tard, vous vous **réattachez** à la session, et vous retrouvez votre travail exactement où vous l'avez laissé.

**2. Guide de survie Tmux (Les commandes)**

| Action | Commande |
| :--- | :--- |
| **Créer une session** | `tmux new -s maintenance` |
| **Sortir (sans tuer)** | `Ctrl + b` puis `d` (pour Detach) |
| **Lister les sessions** | `tmux ls` |
| **Reprendre une session** | `tmux a -t maintenance` |
| **Tuer une session** | `exit` (à l'intérieur) ou `tmux kill-session -t nom` |

**3. Pourquoi c'est parfait pour votre Homelab ?**

*   **Le multitasking (Les Panes) :** Vous pouvez diviser votre écran (`Ctrl+b` puis `%` ou `"`). À gauche vous regardez les logs de Traefik en temps réel (`tail -f`), à droite vous modifiez un fichier de config.
*   **Résistance au TMOUT :** Même si votre `TMOUT` vous déconnecte, **votre tmux ne meurt pas**. Le serveur ferme votre session SSH, mais le processus continue. À votre reconnexion, tapez `tmux a` et vous retrouvez tout.
*   **Administration via Smartphone (Termux) :** Sur l'écran étroit de votre téléphone, c'est dur d'ouvrir plusieurs fenêtres. Avec Tmux sur le serveur, vous gérez tout dans un seul terminal Termux.

---

### 🛡️ RÉSUMÉ DE LA SÉCURITÉ

| Risque | Solution | Résultat |
| :--- | :--- | :--- |
| **Oubli physique** | `TMOUT` dans `/etc/profile` | Déconnexion auto de l'écran local. |
| **Vol de PC/Tel** | `TMOUT` + Clés SSH | La session se ferme seule, et le voleur ne peut pas rouvrir. |
| **Coupure réseau** | `ClientAliveInterval` | Pas de sessions "zombies" sur le serveur. |

**Verdict :** Ton infrastructure est maintenant protégée contre l'oubli humain. La forteresse se verrouille d'elle-même dès que tu tournes le dos. 🚀🛡️


