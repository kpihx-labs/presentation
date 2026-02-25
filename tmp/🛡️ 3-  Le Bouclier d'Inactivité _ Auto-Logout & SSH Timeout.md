
### LE PROBLÈME : La porte restée entrouverte
Tu as fini de travailler sur le vieux PC dans ta chambre ou tu as fermé ton laptop sans couper ta session SSH\. 
**Le risque :** Toute personne passant devant l'écran ou accédant à ton appareil a les pleins pouvoirs \(root\)\. Une session "fantôme" qui traîne est une faille de sécurité physique et numérique\.

**L'Objectif :** Faire en sorte que le serveur "détecte" ton absence et verrouille la porte automatiquement, sans jamais interrompre tes conteneurs Docker ou tes sauvegardes qui tournent en tâche de fond\.

***

### 1\. La Variable Magique : `TMOUT`
La variable `TMOUT` est un réglage natif du shell \(Bash\)\. Si aucune touche n'est pressée pendant un temps défini, le shell tue la session proprement\.

**Action \(Sur Proxmox en root\) :**
On va rendre ce réglage global et impossible à contourner\.

```warp-runnable-command
# 1. Éditer le profil global du système
nano /etc/profile

```
Ajoute ces lignes tout à la fin :
```warp-runnable-command
# --- SÉCURITÉ KPIHX-LABS ---
# Déconnexion auto après 10 minutes d'inactivité (600 secondes)
TMOUT=600
readonly TMOUT
export TMOUT

```
**Pourquoi `readonly` ?**
C'est la touche "Pro"\. Cela empêche quiconque \(même toi\) de taper `TMOUT=0` pour désactiver la sécurité pendant une session\. C'est gravé dans le marbre dès la connexion\.

***

### 2\. Chasser les Sessions Fantômes \(SSH Client Alive\)
Parfois, ta connexion 4G coupe, mais le serveur croit que tu es encore là\. Il garde la session ouverte "au cas où"\. On va lui dire d'être plus agressif\.

**Action :**
```warp-runnable-command
# 2. Configurer le démon SSH
nano /etc/ssh/sshd_config

```
Cherche et ajuste ces paramètres :
```text
# Envoyer un "Tu es là ?" toutes les 5 minutes
ClientAliveInterval 300

# Si le client ne répond pas 2 fois, on coupe !
ClientAliveCountMax 1

```
**Pourquoi ce réglage ?**
Cela force le serveur à vérifier la présence réelle du client\. Si tu perds ton réseau, le serveur ferme la session immédiatement au lieu de la laisser flotter dans le vide\.

```warp-runnable-command
# Appliquer les changements
systemctl restart ssh

```
***

### 3\. Le Cas de l'Écran Physique \(La Console\)
Grâce au `TMOUT` configuré à l'étape 1, ton vieux PC dans ta chambre ne restera plus jamais sur un prompt `root#` toute la nuit\. Après 15 minutes de silence, il reviendra automatiquement sur l'écran de login Proxmox\.

***

### 💡 L'Astuce de l'Expert : Ne pas perdre ses travaux
"Mais si je lance une compilation de 1 heure, elle va se couper ?"
**Non, si tu es malin\.**

Si tu as une tâche longue à faire, utilise **`tmux`** ou **`screen`**\.
1. Lance `tmux`\.
2. Lance ta commande\.
3. Même si ton `TMOUT` te déconnecte, ton travail continue de tourner dans le "tunnel" tmux\.
4. Tu te reconnectes plus tard et tu tapes `tmux a` pour retrouver ton travail\.


### **Tmux \(Terminal Multiplexer\)**

### 1\. Le Concept : "Detach & Attach"

Normalement, un terminal est lié à ta session SSH\. Si la session coupe, le terminal meurt\.
Avec **Tmux**, le terminal tourne directement sur le serveur, indépendamment de ta connexion\.

1.  Tu te connectes en SSH\.
2.  Tu ouvres une **session tmux**\.
3.  Tu lances ta tâche\.
4.  Tu peux te **déconnecter** \(volontairement ou par accident\)\.
5.  Le serveur continue de faire tourner la tâche dans sa bulle\.
6.  Tu reviens plus tard, tu te **réattaches** à la session, et tu retrouves ton travail exactement où tu l'as laissé\.

***

### 2\. Guide de survie Tmux \(Les commandes\)

Tmux est déjà installé sur la plupart des distributions\.
Sinon on l'installe avec ces commandes 
* `sudo wget -O /usr/local/bin/tmux [https://github.com/nelsonenzo/tmux-appimage/releases/download/3.3a/tmux.appimage](https://github.com/nelsonenzo/tmux-appimage/releases/download/3.3a/tmux.appimage)`
* `sudo chmod +x /usr/local/bin/tmux`

| Action | Commande |
| :\-\-\- | :\-\-\- |
| **Créer une session** | `tmux new -s maintenance` |
| **Sortir \(sans tuer\)** | `Ctrl + b` puis `d` \(pour Detach\) |
| **Lister les sessions** | `tmux ls` |
| **Reprendre une session** | `tmux a -t maintenance` |
| **Tuer une session** | `exit` \(à l'intérieur\) ou `tmux kill-session -t nom` |

***

### 3\. Pourquoi c'est parfait pour ton Homelab ?

#### A\. Le multitasking \(Les Panes\)
Au lieu d'ouvrir 4 terminaux SSH, tu peux diviser ton écran en plusieurs fenêtres dans une seule session tmux :
*   `Ctrl + b` puis `%` : Coupe ton écran verticalement\.
*   `Ctrl + b` puis `"` : Coupe ton écran horizontalement\.
*   **Usage concret :** À gauche tu regardes les logs de Traefik en temps réel \(`tail -f`\), à droite tu modifies un fichier de config\.

#### B\. Résistance au TMOUT
Même si ton `TMOUT` \(le timeout de 15 min qu'on vient de configurer\) te déconnecte, **ton tmux ne meurt pas**\.
*   Le serveur ferme ta session SSH \(sécurité\)\.
*   Mais le processus à l'intérieur de tmux continue \(continuité\)\.
*   À ta reconnexion, tu tapes `tmux a` et tu retrouves tout\.

#### C\. Administration via Smartphone \(Termux\)
Sur l'écran étroit de ton téléphone, c'est dur d'ouvrir plusieurs fenêtres\. Avec Tmux sur le serveur, tu gères tout dans un seul terminal Termux\. Tu peux même commencer un truc sur ton PC à l'école, et le finir sur ton téléphone dans le RER\.

***

### 4\. Screen vs Tmux ?

*   **Screen** : Le grand ancêtre\. Présent partout, même sur de très vieux systèmes\. Un peu plus rustique\.
*   **Tmux** : Le successeur moderne\. Plus puissant, gère mieux les splits d'écran, plus stable\.

**Ma recommandation :** Utilise **Tmux**\. C'est le standard actuel\.



***

### RÉSUMÉ DE LA SÉCURITÉ
| Risque | Solution | Résultat |
| :\-\-\- | :\-\-\- | :\-\-\- |
| **Oubli physique** | `TMOUT` dans `/etc/profile` | Déconnexion auto de l'écran local\. |
| **Vol de PC/Tel** | `TMOUT` \+ `MFA Check` | La session se ferme seule, et le voleur ne peut pas rouvrir\. |
| **Coupure réseau** | `ClientAliveInterval` | Pas de sessions "zombies" sur le serveur\. |

**Verdict :** Ton infrastructure est maintenant protégée contre l'oubli humain\. La forteresse se verrouille d'elle\-même dès que tu tournes le dos\. 🚀