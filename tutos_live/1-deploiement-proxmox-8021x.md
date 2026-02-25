# 🚀 Tuto Live 1 : Déploiement Proxmox sur Réseau Sécurisé (802.1X Filaire)

**Contexte :** Installation "Headless" (sans écran) sur un matériel de récupération (PC à écran brisé) avec un adaptateur USB Ethernet.
**Objectif :** Contourner la quarantaine du réseau de l'X, gérer l'authentification 802.1X qui n'est pas native sur Proxmox, et fournir internet aux futures VMs via NAT.
**Matériel requis :** Serveur (Proxmox 8 / Debian 12), Adaptateur USB Ethernet (dont l'adresse MAC a été validée par la DSI), Câble RJ45.

---

## 🛑 PHASE 0 : PRÉPARATION ET COMPRÉHENSION DU PROBLÈME

Le réseau de l'X utilise une sécurité très stricte : le standard **802.1X sur les ports filaires**. 
Contrairement à un PC portable classique sous Ubuntu ou Windows (équipé de NetworkManager qui gère cela graphiquement de manière invisible), **Proxmox** (qui est basé sur Debian Server) ne gère pas cela nativement "out of the box". 

Si on branche le câble, on fait face à trois murs infranchissables :
1.  **Sécurité OpenSSL :** Debian 12 est "too secure" par défaut. Il rejette les protocoles anciens utilisés par le vieux serveur Radius de l'école.
2.  **Race Condition (Course contre la montre) :** Le client DHCP de Debian répond trop vite. Il demande une IP *avant* la fin de l'authentification WPA. Résultat immédiat : on reçoit une IP de quarantaine (réseau restreint) sans accès à internet.
3.  **Adresse unique (Le goulot) :** L'école ne nous donne qu'une seule adresse IP publique par adresse MAC autorisée. Or, nos futures VMs auront toutes besoin d'accéder à internet.

---

## 🔓 PHASE 1 : LE "HACK" OPENSSL (CRITIQUE SUR DEBIAN 12 / PROXMOX 8)

**🤔 Pourquoi faire cela ?**
Le serveur d'authentification de l'école (Radius) utilise des protocoles de chiffrement anciens. Par mesure de sécurité, Debian 12 bloque purement et simplement ces connexions obsolètes, ce qui provoque un "EAP FAILURE" immédiat et silencieux lors de la tentative de connexion.

**✅ La Solution :** Abaisser le niveau d'exigence de sécurité du système.
1.  Ouvrez le fichier de configuration SSL global : `/etc/ssl/openssl.cnf`.
2.  Cherchez la valeur `SECLEVEL`. Par défaut, elle est à `2`. Il faut la changer en `SECLEVEL=0` tout en bas du fichier.

Si la section n'est pas présente à la fin de votre fichier, ajoutez-la manuellement :
```ini
[system_default_sect]
CipherString = DEFAULT:@SECLEVEL=0
```

---

## 🔑 PHASE 2 : CONFIGURATION DE WPA_SUPPLICANT (L'AUTHENTIFICATION)

**🤔 Pourquoi faire cela ?**
`wpa_supplicant` est le logiciel qui va "parler" au switch de l'école et présenter nos identifiants de connexion pour qu'il daigne "ouvrir" le port réseau.

**📖 Décryptage des paramètres clés utilisés :**
*   `key_mgmt=IEEE8021X` : On définit que nous ne sommes pas sur un Wi-Fi classique, mais sur du filaire sécurisé en entreprise.
*   `eap=TTLS` : C'est le tunnel sécurisé principal utilisé par l'X.
*   `phase2="auth=PAP"` : C'est la méthode d'authentification interne *à l'intérieur* du tunnel (Password Authentication Protocol).
*   `ca_cert` : Le chemin vers les certificats racines du système. C'est indispensable pour valider que le serveur en face est bien celui de l'X et non un attaquant.
*   `altsubject_match` : On ajoute une couche de sécurité en vérifiant que le certificat du serveur réseau porte bien le nom DNS "nac-wifi1...".
*   `eapol_flags=0` : **CRUCIAL pour le filaire.** Ce flag indique au système qu'on n'attend pas de clés de chiffrement dynamiques de données (comme le WEP ou le WPA en Wi-Fi) une fois l'authentification réussie, puisque le câble assure l'isolation physique.

**✅ La Solution : Création du profil d'authentification**
Créez le fichier de configuration (remplacez avec vos vrais identifiants) :
```bash
cat <<EOF > /etc/wpa_supplicant/polytechnique.conf
ctrl_interface=/var/run/wpa_supplicant
ap_scan=0
network={
    key_mgmt=IEEE8021X
    eap=TTLS
    identity="prenom.nom@polytechnique.fr"
    anonymous_identity="anonymous@polytechnique.fr"
    password="TonMotDePasseSimple"
    phase2="auth=PAP"
    ca_cert="/etc/ssl/certs/ca-certificates.crt"
    altsubject_match="DNS:nac-wifi1.polytechnique.fr"
    priority=1
    eapol_flags=0
}
EOF
```

**⚠️ Sécurité absolue :** Ce fichier contient votre mot de passe Polytechnique en clair. Il faut impérativement empêcher les autres utilisateurs du système de le lire :
```bash
chmod 600 /etc/wpa_supplicant/polytechnique.conf
```

---

## 🛠️ PHASE 3 : LE TEST MANUEL (DEBUGGING AVANT AUTOMATISATION)

**🤔 Pourquoi faire cela ?**
C'est la règle d'or d'un serveur headless : si on configure le démarrage automatique (`/etc/network/interfaces`) tout de suite avec une erreur de syntaxe, le serveur perdra sa connexion au prochain reboot et il faudra y brancher physiquement un écran pour le réparer.
On teste d'abord manuellement sur l'interface physique (ici `nic1`, l'adaptateur USB).

**🧹 Nettoyage préventif :**
Si vous avez déjà bidouillé, vous aurez l'erreur "Address already in use". Il faut faire table rase et redémarrer la carte réseau :
```bash
killall wpa_supplicant
killall dhclient
ip link set nic1 down
ip link set nic1 up
```

**🚀 Lancement du test verbeux :**
On va forcer le lancement en affichant toutes les étapes de négociation cryptographique pour voir où ça casse.
*   `-i nic1` : Spécifie l'interface physique.
*   `-D wired` : **Vital.** Force l'utilisation du driver filaire (sinon l'outil croit que c'est une carte Wi-Fi).
*   `-dd` : Mode debug "très bavard".
```bash
wpa_supplicant -i nic1 -c /etc/wpa_supplicant/polytechnique.conf -D wired -dd
```

### 🩺 CAS DE DÉBOGAGE (DEBUG) LORS DU TEST :
*   **Cas A : `CTRL-EVENT-EAP-SUCCESS`** ➔ C'est **GAGNÉ**. L'authentification a fonctionné. Faites `Ctrl+C` pour couper et passez à la phase 4.
*   **Cas B : `CTRL-EVENT-EAP-FAILURE`** ➔ Le réseau vous rejette.
    *   Vérifier le Login/Mot de passe.
    *   Vérifier que le hack OpenSSL (`SECLEVEL=0`) est bien en place et pris en compte.
    *   Vérifier que la ligne `eapol_flags=0` n'a pas été oubliée.
*   **Cas C : `bind(PF_UNIX) failed: Address already in use`** ➔ Un autre processus `wpa_supplicant` tourne en tâche de fond. Faites `killall wpa_supplicant` et recommencez.
*   **Cas D : `USB disconnect` ou l'interface disparaît du log** ➔ C'est un problème matériel ! L'adaptateur USB bouge, n'est pas assez alimenté, ou chauffe. Changer de port USB physique sur le PC.

---

## 🏗️ PHASE 4 : CONFIGURATION RÉSEAU DÉFINITIVE (INTERFACES)

**Objectif :** Automatiser la connexion au démarrage (pour qu'il résiste aux coupures de courant) et créer un routeur NAT interne pour masquer nos futures VMs derrière l'unique IP publique autorisée par l'école.

**📖 Décryptage de l'architecture :**
*   `auto nic1` : On demande au système d'allumer l'USB au boot pour pouvoir lancer l'authentification WPA.
*   `vmbr0` (WAN) : C'est le pont public qui va prendre l'IP de l'X.
*   `pre-up sleep 7` : **Le correctif du "Race Condition" (INDISPENSABLE).** Le client DHCP est beaucoup plus rapide que la poignée de main cryptographique du WPA. On force délibérément le système à attendre 7 secondes (que l'authentification se termine et que le port s'ouvre sur le switch de l'X) avant de lancer sa requête DHCP. Sans ce délai, le serveur de l'X nous voit non-authentifié à la seconde 1, et nous donne instantanément l'IP de quarantaine (192.168.x.x).
*   `vmbr1` (LAN) : C'est notre réseau local privé (`10.10.10.x`).
*   `iptables MASQUERADE` : La règle magique qui fait office de routeur NAT. Elle permet aux VMs (sur `10.10.10.x`) de sortir sur internet en maquillant leurs paquets pour faire croire qu'ils viennent de l'hôte principal.

**✅ La Solution :**
Éditez le fichier `/etc/network/interfaces` :
```text
auto lo
iface lo inet loopback

# L'interface physique (USB) qui ne gère QUE l'auth 802.1X
auto nic1
iface nic1 inet manual
    wpa-conf /etc/wpa_supplicant/polytechnique.conf
    wpa-driver wired

# Pont Public (Internet / WAN)
auto vmbr0
iface vmbr0 inet dhcp
    bridge-ports nic1
    bridge-stp off
    bridge-fd 0
    # Petite pause magique pour laisser le temps au WPA de finir avant que le DHCP ne demande une IP
    pre-up sleep 7

# Pont Privé (Réseau Interne NAT pour les Conteneurs/VMs)
auto vmbr1
iface vmbr1 inet static
    address 10.10.10.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    # Activation du routage au niveau du Kernel
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    # Règle NAT (Masquerading) pour faire sortir le trafic de vmbr1 vers vmbr0
    post-up iptables -t nat -A POSTROUTING -s '10.10.10.0/24' -o vmbr0 -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s '10.10.10.0/24' -o vmbr0 -j MASQUERADE
```

---

## 🚨 PHASE 5 : DÉPANNAGE POST-REBOOT (IP ET ROUTAGE)

Une fois le serveur redémarré avec la nouvelle configuration, tapez `ip a` pour vérifier l'état.

### 🩺 CAS DE DÉBOGAGE 1 : La Schizophrénie (Double IP)
*   **Symptôme :** `vmbr0` possède **DEUX** adresses IP simultanément (par exemple, la mauvaise `192.168.x.x` ET la bonne `129.104.x.x`).
*   **Cause :** Le fameux `sleep 7` n'a pas suffi (le Radius était lent ce jour-là). Le DHCP a obtenu l'IP quarantaine *avant* la fin du WPA, et a refait une requête obtenant l'IP publique *après*.
*   **Conséquence :** Le routage est cassé, le serveur ne sait plus par où sortir (le ping vers `8.8.8.8` échoue).
*   **Solution à chaud :**
    1.  Supprimer manuellement l'IP parasite de quarantaine :
        ```bash
        ip addr del 192.168.101.247/21 dev vmbr0
        ```
    2.  Vérifier que la route par défaut (`ip route`) pointe bien vers le gateway public (`129.104...`).
    3.  Si la connectivité ne revient pas, forcer le renouvellement propre du DHCP :
        ```bash
        dhclient -v -r vmbr0 && dhclient -v vmbr0
        ```

### 🩺 CAS DE DÉBOGAGE 2 : Le Désert (Pas d'IP du tout)
*   **Symptôme :** L'interface `vmbr0` n'a aucune ligne `inet` dans le résultat de `ip a`.
*   **Solution :**
    1.  Vérifiez l'état du daemon d'authentification en tâche de fond :
        ```bash
        wpa_cli -i nic1 status
        ```
    2.  Si la ligne `wpa_state=COMPLETED` est présente, c'est juste le DHCP qui a planté. Lancez la requête manuellement :
        ```bash
        dhclient -v vmbr0
        ```

---

## 🌐 PHASE 6 : ACCÈS INTERNET ET PROXY SYSTÈME

Même avec une IP valide, le réseau de l'X est verrouillé. Il bloque l'accès direct et transparent au Web (HTTP/HTTPS). Pour installer des paquets ou télécharger des scripts, il est impératif de déclarer le proxy de l'école (le fameux "kuzh").

**Configuration Temporaire (pour la session shell en cours, afin de faire des tests ou des curl) :**
```bash
export http_proxy=http://129.104.201.11:8080
export https_proxy=http://129.104.201.11:8080
```

**Configuration Définitive pour APT (Pour les Mises à jour du système) :**
Si vous ne faites pas cela, vos `apt update` tourneront dans le vide.
1. Créez un fichier spécifique pour qu'APT utilise toujours ce proxy de manière transparente :
```bash
echo 'Acquire::http::Proxy "http://129.104.201.11:8080";' > /etc/apt/apt.conf.d/05proxy
echo 'Acquire::https::Proxy "http://129.104.201.11:8080";' >> /etc/apt/apt.conf.d/05proxy
```

*(Bon à savoir : La résolution des noms de domaine (DNS) est gérée par le fichier `/etc/resolv.conf`, qui doit pointer vers les serveurs de l'école ou `127.0.0.53` avec systemd-resolved).*

**✅ Le Test Ultime :**
Exécutez `apt update`. Si la liste des dépôts défile sans erreur "Timeout", félicitations ! Votre serveur est officiellement sorti de sa quarantaine et est prêt pour la production. Prochaine étape : ouvrir des ports et créer la première usine Docker.

---
## 🗺️ Navigation
- [🏠 Accueil](https://kpihx-labs.github.io/presentation/#/README.md)
- [🔭 Vision](https://kpihx-labs.github.io/presentation/#/VISION.md)
- [🏗️ État de l'Art](https://kpihx-labs.github.io/presentation/#/STATE_OF_THE_ART.md)
- [🕒 Évolution](https://kpihx-labs.github.io/presentation/#/EVOLUTION.md)
- [🚀 Live Tutorials](https://kpihx-labs.github.io/presentation/#/tutos_live/README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate](https://kpihx-labs.github.io/presentation/#/AGENT.md)
