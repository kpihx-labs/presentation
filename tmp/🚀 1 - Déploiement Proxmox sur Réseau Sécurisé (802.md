Contexte : Installation "Headless" \(sans écran\) sur matériel avec Adaptateur USB Ethernet\.  
Objectif : Contourner la quarantaine, gérer l'authentification 802\.1X, et fournir internet aux VMs via NAT\.  
Matériel requis : Serveur, Adaptateur USB Ethernet \(validé DSI\), Câble RJ45\.

***
PHASE 0 : PRÉPARATION ET COMPRÉHENSION DU PROBLÈME

Le réseau de l'X utilise une sécurité 802\.1X sur les ports filaires\. Contrairement à un PC portable \(équipé de NetworkManager\), Proxmox \(basé sur Debian Server\) ne gère pas cela nativement\.

Trois problèmes majeurs surviennent :
Sécurité OpenSSL : Debian 12 est "trop sécurisé" pour le serveur Radius de l'école \(OpenSSL rejette les protocoles anciens\)\.
Race Condition : Le client DHCP répond trop vite, avant la fin de l'authentification WPA\. Résultat : IP de quarantaine\.
Adresse unique : On ne dispose que d'une seule IP publique alors que les VMs ont besoin d'internet\.

***
PHASE 1 : LE "HACK" OPENSSL \(CRITIQUE SUR DEBIAN 12 / PROXMOX 8\)

Pourquoi ? Le serveur d'authentification de l'école utilise des protocoles de chiffrement anciens\. Par défaut, Debian 12 bloque ces connexions, ce qui provoque un "EAP FAILURE" immédiat\.

  Fichier à modifier : /etc/ssl/openssl\.cnf
  Action : Changer SECLEVEL=2 en SECLEVEL=0 tout en bas du fichier\. Si la section n'est pas présente, ajoutez\-la :

\[system\_default\_sect\]
CipherString = DEFAULT:@SECLEVEL=0

***
PHASE 2 : CONFIGURATION DE WPA\_SUPPLICANT \(L'AUTHENTIFICATION\)

Pourquoi ? C'est le logiciel qui va présenter nos identifiants au switch pour "ouvrir" le port réseau\.

Explications des paramètres clés utilisés dans ta configuration :
  key\_mgmt=IEEE8021X : On définit que nous sommes sur du filaire sécurisé\.
  eap=TTLS : Le tunnel sécurisé utilisé par l'X\.
  phase2="auth=PAP" : L'authentification interne dans le tunnel \(Password Authentication Protocol\)\.
  ca\_cert : Chemin vers les certificats racines pour valider que le serveur est bien celui de l'X\.
  altsubject\_match : Vérifie que le serveur s'appelle bien "nac\-wifi1\.\.\."\.
  eapol\_flags=0 : CRUCIAL pour le filaire\. Indique qu'on n'attend pas de clés de chiffrement dynamiques \(WEP/WPA\) après l'authentification\.

Création du fichier /etc/wpa\_supplicant/polytechnique\.conf :
cat <<EOF > /etc/wpa\_supplicant/polytechnique\.conf
ctrl\_interface=/var/run/wpa\_supplicant
ap\_scan=0
network=\{
    key\_mgmt=IEEE8021X
    eap=TTLS
    identity="prenom\.nom@polytechnique\.fr"
    anonymous\_identity="anonymous@polytechnique\.fr"
    password="TonMotDePasseSimple"
    phase2="auth=PAP"
    ca\_cert="/etc/ssl/certs/ca\-certificates\.crt"
    altsubject\_match="DNS:nac\-wifi1\.polytechnique\.fr"
    priority=1
    eapol\_flags=0
\}
EOF

Sécurité : On protège ce fichier car il contient le mot de passe en clair\.
chmod 600 /etc/wpa\_supplicant/polytechnique\.conf

***
PHASE 3 : LE TEST MANUEL \(DEBUGGING AVANT AUTOMATISATION\)

Pourquoi ? Si on configure le démarrage automatique tout de suite et que ça plante, on perd la main sur le serveur\. On teste d'abord manuellement sur l'interface physique \(ici nic1, l'adaptateur USB\)\.

1. Nettoyage préventif
En cas d'erreur "Address already in use", il faut tuer les processus existants :
killall wpa\_supplicant
killall dhclient
ip link set nic1 down
ip link set nic1 up

2. Lancement du test verbeux
  \-i nic1 : Interface physique\.
  \-D wired : Force le driver filaire \(sinon il cherche du Wi\-Fi\)\.
  \-dd : Mode debug très bavard\.
wpa\_supplicant \-i nic1 \-c /etc/wpa\_supplicant/polytechnique\.conf \-D wired \-dd

=== CAS DE DÉBOGAGE \(DEBUG\) ===
  Cas A : "CTRL\-EVENT\-EAP\-SUCCESS"
  \-> C'est GAGNÉ\. L'authentification fonctionne\. Faites Ctrl\+C et passez à la suite\.
  Cas B : "CTRL\-EVENT\-EAP\-FAILURE"
  \-> Vérifier le Login/Mot de passe\.
  \-> Vérifier que OpenSSL SECLEVEL est bien à 0\.
  \-> Vérifier que eapol\_flags=0 est présent\.
  Cas C : "bind\(PF\_UNIX\) failed: Address already in use"
  \-> Un autre wpa\_supplicant tourne déjà\. Faire killall wpa\_supplicant et recommencer\.
  Cas D : "USB disconnect" / L'interface disparaît
  \-> Problème matériel \(l'adaptateur bouge ou chauffe\)\. Changer de port USB physique\.

***
PHASE 4 : CONFIGURATION RÉSEAU DÉFINITIVE \(INTERFACES\)

Objectif : Automatiser le tout au démarrage et créer le routeur NAT pour les VMs via /etc/network/interfaces\.

Explications des blocs :
  auto nic1 : L'USB doit démarrer pour lancer l'authentification WPA\.
  vmbr0 \(WAN\) : Le pont public\. 
  pre\-up sleep 7 : INDISPENSABLE\. Le DHCP est plus rapide que le WPA\. On force le système à attendre 7 secondes que l'authentification se finisse avant de demander une IP, sinon on reçoit l'IP de quarantaine \(192\.168\.\.\.\)\.
  vmbr1 \(LAN\) : Le réseau privé \(10\.10\.10\.x\)\.
  iptables MASQUERADE : Permet aux VMs de sortir sur internet en utilisant l'IP de l'hôte\.

Contenu du fichier :
auto lo
iface lo inet loopback

# L'interface physique \(USB\) gère l'auth 802\.1X
auto nic1
iface nic1 inet manual
    wpa\-conf /etc/wpa\_supplicant/polytechnique\.conf
    wpa\-driver wired

# Pont Public \(Internet\)
auto vmbr0
iface vmbr0 inet dhcp
    bridge\-ports nic1
    bridge\-stp off
    bridge\-fd 0
    \# Petite pause pour laisser le temps au WPA de finir avant le DHCP
    pre\-up sleep 7

# Pont Privé \(NAT pour les Conteneurs/VMs\)
auto vmbr1
iface vmbr1 inet static
    address 10\.10\.10\.1/24
    bridge\-ports none
    bridge\-stp off
    bridge\-fd 0
    \# Activation du routage et du NAT
    post\-up   echo 1 > /proc/sys/net/ipv4/ip\_forward
    post\-up   iptables \-t nat \-A POSTROUTING \-s '10\.10\.10\.0/24' \-o vmbr0 \-j MASQUERADE
    post\-down iptables \-t nat \-D POSTROUTING \-s '10\.10\.10\.0/24' \-o vmbr0 \-j MASQUERADE

***
PHASE 5 : DÉPANNAGE POST\-REBOOT \(IP ET ROUTAGE\)

Après un reboot, vérifiez l'état avec ip a\.

=== CAS DE DÉBOGAGE : Double IP \(Schizophrénie\) ===
  Symptôme : vmbr0 a DEUX IPs \(ex: 129\.104\.x\.x ET 192\.168\.x\.x\)\.
  Cause : Le DHCP a obtenu l'IP quarantaine avant la fin du WPA, puis l'IP publique après\.
  Conséquence : Internet ne marche pas \(ping fail\)\.
  Solution :
Supprimer l'IP parasite : ip addr del 192\.168\.101\.247/21 dev vmbr0
Vérifier la route : ip route \(doit passer par le gateway 129\.104\.\.\.\)
Si besoin, relancer le client DHCP : dhclient \-v \-r vmbr0 && dhclient \-v vmbr0

=== CAS DE DÉBOGAGE : Pas d'IP du tout ===
  Symptôme : vmbr0 n'a aucune ligne inet\.
  Solution :
Vérifier l'état de l'auth : wpa\_cli \-i nic1 status \(Doit être COMPLETED\)\.
Si COMPLETED, demander l'IP manuellement : dhclient \-v vmbr0\.

***
PHASE 6 : ACCÈS INTERNET \(PROXY\)

Le réseau de l'X bloque l'accès direct au Web \(HTTP/HTTPS\)\. Il faut passer par le proxy kuzh\.

Configuration temporaire \(pour tester\) :
export http\_proxy=http://129\\\\\\\.104\\\\\\\.201\\\\\\\.11:8080
export https\_proxy=http://129\\\\\\\.104\\\\\\\.201\\\\\\\.11:8080

Configuration définitive pour APT \(Mises à jour\) :
Créez le fichier /etc/apt/apt\.conf\.d/05proxy :
echo 'Acquire::http::Proxy "http://129\\\\\\\.104\\\\\\\.201\\\\\\\.11:8080";' > /etc/apt/apt\.conf\.d/05proxy
echo 'Acquire::https::Proxy "http://129\\\\\\\.104\\\\\\\.201\\\\\\\.11:8080";' >> /etc/apt/apt\.conf\.d/05proxy

Test final :
Exécutez apt update\. Si les dépôts défilent, votre serveur est prêt pour la production \!
Bon à savoir : les serveurs DNS sont dans /etc/resolv\.conf