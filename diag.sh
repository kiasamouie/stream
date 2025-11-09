#!/usr/bin/env bash
# ============================================================
#  YTStream Diagnostic Script (filtered + limited version)
#  Focused on relevant errors from ffmpeg/mpv with capped lines
# ============================================================

set -e

GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; CYAN="\e[36m"; RESET="\e[0m"

divider() { echo -e "${CYAN}------------------------------------------------------------${RESET}"; }
header() { echo -e "\n${YELLOW}$1${RESET}"; divider; }

CURRENT_USER=$(whoami)
echo -e "${GREEN}Running YTStream diagnostics as '$CURRENT_USER'...${RESET}"
echo "Timestamp: $(date -Is)"

# ------------------------------------------------------------
# 🔧 Check audio group membership
# ------------------------------------------------------------
header "🔧 Checking audio group membership"

if id -nG "$CURRENT_USER" | grep -qw "audio"; then
  echo -e "${GREEN}✔ User '$CURRENT_USER' is in the audio group${RESET}"
else
  echo -e "${RED}✘ User '$CURRENT_USER' is NOT in the audio group${RESET}"
  echo -e "${YELLOW}→ This user may not have access to ALSA devices (like Loopback).${RESET}"
  echo "   To fix: sudo usermod -aG audio $CURRENT_USER && log out/in"
fi

# ------------------------------------------------------------
# 🎛 Service Status
# ------------------------------------------------------------
header "🎛 Service Status"

for svc in ytstream-audio ytstream-stream; do
  if systemctl list-unit-files | grep -q "^${svc}.service"; then
    if systemctl is-active --quiet "$svc"; then
      echo -e "${GREEN}✔ $svc is active${RESET}"
    else
      echo -e "${RED}✘ $svc is inactive${RESET}"
    fi
  else
    echo -e "${YELLOW}⚠ $svc not found${RESET}"
  fi
done

# ------------------------------------------------------------
# 🎧 ALSA Loopback Devices (compact)
# ------------------------------------------------------------
header "🎧 ALSA Loopback Devices"

if arecord -l 2>/dev/null | grep -q "Loopback"; then
  echo -e "${GREEN}✔ Loopback capture device detected${RESET}"
  arecord -l 2>/dev/null | grep -A1 "Loopback" | sed 's/^/   /'
else
  echo -e "${RED}✘ No Loopback capture device detected${RESET}"
  echo "   Try: sudo modprobe snd-aloop"
fi

if aplay -l 2>/dev/null | grep -q "Loopback"; then
  echo -e "${GREEN}✔ Loopback playback device detected${RESET}"
  aplay -l 2>/dev/null | grep -A1 "Loopback" | sed 's/^/   /'
else
  echo -e "${RED}✘ No Loopback playback device detected${RESET}"
fi

# ------------------------------------------------------------
# 🔊 Loopback audio activity
# ------------------------------------------------------------
header "🔊 Loopback Audio Activity"

play_status=$(grep "state" /proc/asound/Loopback/pcm0p/sub0/status 2>/dev/null | awk '{print $2}')
capture_status=$(grep "state" /proc/asound/Loopback/pcm1c/sub0/status 2>/dev/null | awk '{print $2}')

[[ "$play_status" == "RUNNING" ]] && echo -e "${GREEN}✔ Playback stream active${RESET}" || echo -e "${RED}✘ No active playback stream${RESET}"
[[ "$capture_status" == "RUNNING" ]] && echo -e "${GREEN}✔ Capture stream active${RESET}" || echo -e "${RED}✘ No active capture stream${RESET}"

# ------------------------------------------------------------
# 🧾 Focused Service Logs (errors + limited output)
# ------------------------------------------------------------
header "🧾 Service Logs (last 30 minutes — filtered and limited)"

if [ "$(id -u)" -eq 0 ]; then
  echo -e "${CYAN}▶ ytstream-stream.service (ffmpeg)${RESET}"
  echo "------------------------------------------------------------"
  sudo journalctl -u ytstream-stream.service --since "30 minutes ago" -o cat | \
    grep -A5 -B5 -E "Error|failed|reset|IO error|Connection|Broken pipe" | tail -n 40 || \
    echo "No errors found in stream service."

  echo -e "\n${CYAN}▶ ytstream-audio.service (mpv)${RESET}"
  echo "------------------------------------------------------------"
  sudo journalctl -u ytstream-audio.service --since "30 minutes ago" -o cat | \
    grep -A3 -B3 -E "Error|failed|reset|IO error|Connection|Broken pipe" | tail -n 40 || \
    echo "No errors found in audio service."
else
  echo -e "${YELLOW}⚠ Run this script with sudo to view service logs${RESET}"
  echo "   sudo /opt/ytstream/diag.sh"
fi

divider
echo -e "${GREEN}✅ Diagnostics complete.${RESET}"
