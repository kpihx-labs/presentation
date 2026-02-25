# 🚀 Tuto Live 5 : Exposition Publique et Zero Trust (Cloudflare)

**Contexte :** Vos services tournent en privé via Tailscale. Mais parfois, vous voulez qu'un service soit accessible publiquement (ex: portfolio, bot), ou par des amis, sans les forcer à installer un VPN. On veut exposer `sentinel.kpihx-labs.com` sur le web mondial, en toute sécurité.

**Objectifs :**
1. Créer un tunnel sécurisé (**Cloudflare Tunnel**) qui traverse le firewall de l'école.
2. Forcer l'authentification (**Google OAuth**) avant d'accéder au serveur.
3. Configurer le routage public sans ouvrir de port sur votre box ou à l'école.

---

## ☁️ PHASE 1 : L'INFRASTRUCTURE (LE TUNNEL)

**🤔 Pourquoi faire cela ?**
Le Tunnel est un "pont" initié par votre serveur **vers** Cloudflare. Comme c'est une connexion sortante, le pare-feu de l'X la laisse passer (en mode HTTP2). Cloudflare reçoit ensuite les requêtes des gens et les renvoie dans ce pont.

**✅ La Solution :**
1. **Cloudflare Zero Trust :** Créez un tunnel et copiez le `TUNNEL_TOKEN`.
2. **Déploiement Docker :** Récupérez le **Template :** `templates/cloudflared.yaml`.
3. **Important :** N'oubliez pas les variables `NO_PROXY=traefik` et le protocole `--protocol http2` dans votre configuration finale pour que le tunnel puisse parler au proxy en interne et traverser l'X.

---

## 🔑 PHASE 2 : L'IDENTITÉ (GOOGLE OAUTH)

**🤔 Pourquoi faire cela ?**
On ne veut pas que n'importe qui accède à vos statistiques Sentinel. On va dire à Cloudflare : *"Si quelqu'un veut entrer, demande-lui de se connecter avec Google et vérifie que c'est bien mon email"*.

**✅ La Solution :**
1. Dans Cloudflare, allez dans *Settings > Authentication*.
2. Ajoutez **Google** comme fournisseur d'identité (OAuth).
3. Créez une **Access Application** pour `sentinel.kpihx-labs.com`.
4. Ajoutez une règle : `Allow` if `Email` is `votre.email@gmail.com`.

---

## 🚦 PHASE 3 : LE ROUTAGE PUBLIC (TRAEFIK)

**🤔 Pourquoi faire cela ?**
Le tunnel envoie le trafic vers Traefik. Mais Traefik doit savoir qu'il est autorisé à répondre au nom de domaine `.com` en plus du `.homelab`.

**✅ La Solution :**
Ajustez les labels dans votre stack applicative (ex: Sentinel) :
```yaml
labels:
  - "traefik.http.routers.sentinel.rule=Host(`sentinel.homelab`) || Host(`sentinel.kpihx-labs.com`)"
```

**⚠️ Détail Vital (TLS Verify) :**
Dans la console Cloudflare Tunnel (Public Hostname), activez l'option **"No TLS Verify"**. Pourquoi ? Car Cloudflare parle à votre Traefik en HTTPS avec un certificat auto-signé qu'il ne connaît pas. Sans cette option, il coupera la connexion par précaution.

**Verdict :** Éteignez le Wifi de votre tel (4G), coupez Tailscale. Allez sur `https://sentinel.kpihx-labs.com`. Identifiez-vous avec Google. Vous êtes chez vous, partout dans le monde. 🌍🛡️
