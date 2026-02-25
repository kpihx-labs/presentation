import os
import re

BASE_URL = "https://kpihx-labs.github.io/presentation/#"
TUTOS_BASE = f"{BASE_URL}/tutos_live"

# Mapping of what to replace
REPLACEMENTS = {
    r'\]\(README\.md\)': f']({BASE_URL}/README.md)',
    r'\]\(VISION\.md\)': f']({BASE_URL}/VISION.md)',
    r'\]\(STATE_OF_THE_ART\.md\)': f']({BASE_URL}/STATE_OF_THE_ART.md)',
    r'\]\(EVOLUTION\.md\)': f']({BASE_URL}/EVOLUTION.md)',
    r'\]\(AGENT\.md\)': f']({BASE_URL}/AGENT.md)',
    r'\]\(tutos_live/README\.md\)': f']({TUTOS_BASE}/README.md)',
    r'\]\(tutos_live/1-deploiement-proxmox-8021x\.md\)': f']({TUTOS_BASE}/1-deploiement-proxmox-8021x.md)',
    r'\]\(tutos_live/2-mise-en-place-docker-host\.md\)': f']({TUTOS_BASE}/2-mise-en-place-docker-host.md)',
    r'\]\(tutos_live/3-industrialisation-devops\.md\)': f']({TUTOS_BASE}/3-industrialisation-devops.md)',
    r'\]\(tutos_live/4-reseau-overlay-tailscale\.md\)': f']({TUTOS_BASE}/4-reseau-overlay-tailscale.md)',
    r'\]\(tutos_live/5-exposition-publique-cloudflare\.md\)': f']({TUTOS_BASE}/5-exposition-publique-cloudflare.md)',
    r'\]\(tutos_live/security/1-sauvegarde-maintenance-321\.md\)': f']({TUTOS_BASE}/security/1-sauvegarde-maintenance-321.md)',
    r'\]\(tutos_live/security/2-automatisation-watchtower\.md\)': f']({TUTOS_BASE}/security/2-automatisation-watchtower.md)',
    r'\]\(tutos_live/security/3-bouclier-inactivite-ssh\.md\)': f']({TUTOS_BASE}/security/3-bouclier-inactivite-ssh.md)',
    r'\]\(tutos_live/annexes/1-network-watchdog-v3\.md\)': f']({TUTOS_BASE}/annexes/1-network-watchdog-v3.md)',
    r'\]\(tutos_live/annexes/2-termux-ssh-toolkit\.md\)': f']({TUTOS_BASE}/annexes/2-termux-ssh-toolkit.md)',
    # Handle relative jumps from nested folders
    r'\]\(\.\./README\.md\)': f']({BASE_URL}/README.md)',
    r'\]\(\.\./VISION\.md\)': f']({BASE_URL}/VISION.md)',
    r'\]\(\.\./STATE_OF_THE_ART\.md\)': f']({BASE_URL}/STATE_OF_THE_ART.md)',
    r'\]\(\.\./EVOLUTION\.md\)': f']({BASE_URL}/EVOLUTION.md)',
    r'\]\(\.\./AGENT\.md\)': f']({BASE_URL}/AGENT.md)',
    r'\]\(\.\./\.\./README\.md\)': f']({BASE_URL}/README.md)',
    r'\]\(\.\./\.\./VISION\.md\)': f']({BASE_URL}/VISION.md)',
    r'\]\(\.\./\.\./STATE_OF_THE_ART\.md\)': f']({BASE_URL}/STATE_OF_THE_ART.md)',
    r'\]\(\.\./\.\./EVOLUTION\.md\)': f']({BASE_URL}/EVOLUTION.md)',
    r'\]\(\.\./\.\./AGENT\.md\)': f']({BASE_URL}/AGENT.md)',
    r'\]\(\.\./README\.md\)': f']({TUTOS_BASE}/README.md)', # From nested tutos
}

NAV_BLOCK = f"""
---
## 🗺️ Navigation
- [🏠 Accueil]({BASE_URL}/README.md)
- [🔭 Vision]({BASE_URL}/VISION.md)
- [🏗️ État de l'Art]({BASE_URL}/STATE_OF_THE_ART.md)
- [🕒 Évolution]({BASE_URL}/EVOLUTION.md)
- [🚀 Live Tutorials]({TUTOS_BASE}/README.md)
- [🛠️ Templates](https://github.com/kpihx-labs/presentation/tree/main/tutos_live/templates)
- [🤖 Agent Mandate]({BASE_URL}/AGENT.md)"""

def fix_file(path):
    with open(path, 'r') as f:
        content = f.read()
    
    # Remove existing navigation block if present
    content = re.sub(r'---.*## 🗺️ Navigation.*', '', content, flags=re.DOTALL)
    content = content.strip()
    
    # Perform link replacements
    for pattern, replacement in REPLACEMENTS.items():
        content = re.sub(pattern, replacement, content)
    
    # Append fresh absolute navigation
    content += NAV_BLOCK
    
    with open(path, 'w') as f:
        f.write(content)

for root, dirs, files in os.walk('.'):
    if 'tmp_restore' in root or '.git' in root: continue
    for file in files:
        if file.endswith('.md') and file != '_sidebar.md':
            fix_file(os.path.join(root, file))
