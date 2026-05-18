#!/usr/bin/env bash
# Arch Linux Login Maintenance Briefing

# --- Color Variables ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

echo -e "\n${BLUE}===> Arch Linux System Health <===${NC}"

# 1. Systemd Service Check
failed_sys=$(systemctl --failed --plain --no-legend 2>/dev/null | wc -l)
if [[ $failed_sys -gt 0 ]]; then
    echo -e "${RED}[!] Failed systemd services detected:${NC}"
    systemctl --failed --no-pager
else
    echo -e "${GREEN}[✓] All systemd services are running cleanly.${NC}"
fi

# 2. Safe Update Check
# Uses 'checkupdates' from the 'pacman-contrib' package to check for 
# updates without altering the local pacman database (avoids partial upgrades).
if command -v checkupdates >/dev/null 2>&1; then
    updates=$(checkupdates 2>/dev/null | wc -l)
    if [[ $updates -gt 0 ]]; then
         echo -e "${YELLOW}[i] $updates official packages can be upgraded.${NC} (Run 'pacman -Syu')"
    else
         echo -e "${GREEN}[✓] System packages are up to date.${NC}"
    fi
else
    echo -e "${YELLOW}[i] Install 'pacman-contrib' to safely check for updates.${NC}"
fi

# 3. Orphaned Package Check
orphans=$(pacman -Qdtq 2>/dev/null | wc -l)
if [[ $orphans -gt 0 ]]; then
    echo -e "${YELLOW}[i] $orphans orphaned packages taking up space.${NC} (Clean: sudo pacman -Rns \$(pacman -Qdtq))"
else
    echo -e "${GREEN}[✓] No orphaned packages found.${NC}"
fi

# 4. Pacnew / Pacsave Check
# Scans /etc for unmerged configuration files
pacnews=$(find /etc -type f \( -name "*.pacnew" -o -name "*.pacsave" \) 2>/dev/null | wc -l)
if [[ $pacnews -gt 0 ]]; then
    echo -e "${RED}[!] $pacnews .pacnew/.pacsave configuration files found.${NC} (Merge using 'sudo pacdiff')"
fi

# 5. Disk Space Check (Root partition warning if over 90% full)
root_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [[ $root_usage -ge 90 ]]; then
    echo -e "${RED}[!] Root partition is at ${root_usage}% capacity!${NC}"
fi

echo -e "${BLUE}==================================${NC}\n"
