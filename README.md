# 🚀 KpihX Labs : The Sovereign Cloud Journey

Welcome to the official documentation and architectural showcase of **KpihX Labs**. This repository serves as a "Black Box" for a self-hosted infrastructure built on resilience, transparency, and automation.

## 🔭 Vision & Philosophy
KpihX Labs is the transition from the **"Island of Local"** to the **"Peninsula of Cloud"**. It aims to reclaim digital sovereignty by transforming consumer hardware into an enterprise-grade **Platform as a Service (PaaS)**.

- **Sovereignty:** No more dependence on "Free Tier" cloud providers.
- **Transparency:** Every technical "Why" is documented before the "How".
- **AI-Augmented:** A local AI sanctuary (Ollama) integrated into daily workflows.

## 🏗️ Technical Architecture

### 1. The Core (Hypervisor)
- **Hardware:** AMD Laptop (Headless) with a 1TB SSD.
- **OS:** Proxmox VE 8 (Debian 12 based).
- **Network Challenge:** Successfully bypassed the École Polytechnique (l'X) 802.1X security using `wpa_supplicant` hacks and OpenSSL security level adjustments.

### 2. Networking & Zero Trust
- **Internal (Private):** **Tailscale Overlay Mesh** combined with **AdGuard Home** for a Split DNS setup. Accessing `*.homelab` domains is seamless from any device.
- **External (Public):** **Cloudflare Tunnel (HTTP2)** exposing services to `kpihx-labs.com` without opening local ports, protected by **Google OAuth**.
- **Edge Routing:** **Traefik** handles all HTTP/HTTPS traffic with automated redirection and certificate management.

### 3. Industrialization (DevOps)
Development follows a strict **PC ➔ GitLab ➔ Homelab** workflow:
- **GitLab CI/CD:** Local Runner on Docker-Host executes deployments.
- **GitHub Mirroring:** Every private GitLab project is automatically synced to the [kpihx-labs GitHub Org](https://github.com/kpihx-labs).

## 🌐 Live Showcase
The documentation is dynamically served via **Docsify** at:
👉 **[https://kpihx-labs.github.io/presentation](https://kpihx-labs.github.io/presentation)**

## 🔐 CI/CD Secret Variables
To function, the GitLab pipelines require the following variables defined in the Group/Project settings:
- `TELEGRAM_TOKEN`: Bot token for status notifications.
- `CHAT_ID`: Telegram chat ID for alerts.
- `DB_PASS`: Master password for the PostgreSQL stack.
- `GITHUB_TOKEN`: Classic token with `repo` and `admin:org` scopes for mirroring.
- `SSH_USER`: The administrative user (e.g., `ivann`) for bastion access.

## 📚 Documentation Map
- [🔭 Full Vision](VISION.md) — The strategic soul of the project.
- [🏗️ State of the Art](STATE_OF_THE_ART.md) — Detailed technical map.
- [🕒 Evolution](EVOLUTION.md) — Chronological engineering log.
- [🚀 Live Tutorials](tutos_live/) — Step-by-step implementation guides.
- [🛠️ Templates](tutos_live/templates/) — Generic configuration files.

---
*Built with ❤️ and persistence by KpihX.*
