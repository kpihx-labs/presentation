import os
import re
import requests
import time

BASE_WEB_URL = "https://kpihx-labs.github.io/presentation/#/"
REPO_ROOT = "/home/kpihx/Work/Homelab/presentation"

def find_md_files(directory):
    md_files = []
    for root, dirs, files in os.walk(directory):
        if "tmp_restore" in root or ".git" in root:
            continue
        for file in files:
            if file.endswith(".md"):
                md_files.append(os.path.join(root, file))
    return md_files

def extract_links(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    # Find markdown links [text](url)
    links = re.findall(r'\[.*?\]\((.*?)\)', content)
    return links

def check_link(link):
    if not link.startswith("https://kpihx-labs.github.io/presentation"):
        return None # Skip external or non-web links for now
    
    # Try to clean the link to get the direct file path or web path
    # Docsify uses #/path/to/file.md
    clean_url = link.replace("https://kpihx-labs.github.io/presentation/#/", "")
    clean_url = clean_url.replace("https://kpihx-labs.github.io/presentation/", "")
    
    local_path = os.path.join(REPO_ROOT, clean_url)
    
    if os.path.exists(local_path):
        return True
    else:
        return False

def main():
    md_files = find_md_files(REPO_ROOT)
    broken_links = []

    print(f"🔍 Scanning {len(md_files)} files for broken links...")

    for file_path in md_files:
        rel_file = os.path.relpath(file_path, REPO_ROOT)
        links = extract_links(file_path)
        for link in links:
            if link.startswith("https://kpihx-labs.github.io/presentation"):
                is_ok = check_link(link)
                if is_ok == False:
                    broken_links.append((rel_file, link))
                    print(f"❌ Broken: {link} in {rel_file}")
                elif is_ok == True:
                    pass # Link is fine

    if not broken_links:
        print("✅ All internal web links are healthy!")
    else:
        print(f"\nFound {len(broken_links)} broken links.")

if __name__ == "__main__":
    main()
