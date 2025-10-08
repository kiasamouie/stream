#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/ytstream"
REPO_DIR="$(pwd)"

echo "[ytstream] 🚀 Starting installation..."

# -----------------------------
# 1. Prompt for input
# -----------------------------
read -rp "Enter service username [ytstream]: " SERVICE_USER
SERVICE_USER="${SERVICE_USER:-ytstream}"

read -rp "Enter YouTube Stream Key: " YOUTUBE_STREAM_KEY
if [[ -z "$YOUTUBE_STREAM_KEY" ]]; then
  echo "Error: Stream key cannot be empty." >&2
  exit 1
fi

# -----------------------------
# 2. Install prerequisites
# -----------------------------
echo "[ytstream] Installing prerequisites..."
sudo apt-get update
sudo apt-get install -y \
  git \
  ffmpeg \
  mpv \
  yt-dlp \
  imagemagick \
  curl \
  alsa-utils \
  fonts-dejavu-core \
  nginx \
  dos2unix \
  dbus-user-session

# -----------------------------
# 3. Configure ALSA Loopback
# -----------------------------
echo "[ytstream] Configuring ALSA loopback..."

# Load ALSA loopback module
if ! lsmod | grep -q snd_aloop; then
  sudo modprobe snd-aloop || true
fi

# Verify the module loaded
if ! lsmod | grep -q snd_aloop; then
  echo "[ytstream] snd-aloop module not found, installing kernel extras..."
  sudo apt-get install -y linux-modules-extra-$(uname -r)
  sudo modprobe snd-aloop
fi

# Persist across reboots
echo "snd-aloop" | sudo tee /etc/modules-load.d/snd-aloop.conf >/dev/null

# Configure ALSA loopback parameters
sudo tee /etc/modprobe.d/alsa-loopback.conf >/dev/null <<'EOF'
options snd-aloop index=0 enable=1 id=Loopback pcm_substreams=2
EOF

# Reload module with new parameters
sudo modprobe -r snd-aloop || true
sudo modprobe snd-aloop

# Add both the installing user and service user to the audio group
if ! getent group audio >/dev/null; then
  echo "[ytstream] Creating 'audio' group..."
  sudo groupadd --system audio
fi

sudo usermod -aG audio "$USER" || true
if id "$SERVICE_USER" &>/dev/null; then
  sudo usermod -aG audio "$SERVICE_USER" || true
fi

# -----------------------------
# 4. Create application directory
# -----------------------------
echo "[ytstream] Setting up application directory at $APP_DIR"
sudo mkdir -p "$APP_DIR/assets"

echo "[ytstream] Copying repository files..."
sudo cp -r "$REPO_DIR/"{svc_audio.sh,svc_stream.sh,metadata.lua,playlist.url} "$APP_DIR/" 2>/dev/null || true

# Copy env file or create new one
if [[ -f "$REPO_DIR/.env" ]]; then
  sudo cp "$REPO_DIR/.env" "$APP_DIR/"
elif [[ -f "$REPO_DIR/example.env" ]]; then
  echo "[ytstream] Using example.env to create .env"
  sudo cp "$REPO_DIR/example.env" "$APP_DIR/.env"
else
  echo "Warning: No .env or example.env found, creating new file."
  echo "YOUTUBE_STREAM_KEY=$YOUTUBE_STREAM_KEY" | sudo tee "$APP_DIR/.env" >/dev/null
fi

# Update YouTube stream key
sudo sed -i "s/^YOUTUBE_STREAM_KEY=.*/YOUTUBE_STREAM_KEY=\"$YOUTUBE_STREAM_KEY\"/" "$APP_DIR/.env" || \
  echo "YOUTUBE_STREAM_KEY=\"$YOUTUBE_STREAM_KEY\"" | sudo tee -a "$APP_DIR/.env" >/dev/null

sudo cp -r "$REPO_DIR/assets/"* "$APP_DIR/assets/" 2>/dev/null || true
sudo chmod +x "$APP_DIR/"*.sh

# Ensure playlist.url exists
if [[ ! -f "$APP_DIR/playlist.url" ]]; then
  echo "[ytstream] Creating empty playlist.url"
  sudo touch "$APP_DIR/playlist.url"
fi

# -----------------------------
# 5. Ownership & permissions
# -----------------------------
echo "[ytstream] Setting ownership and permissions..."
if ! id "$SERVICE_USER" &>/dev/null; then
  echo "[ytstream] Creating user $SERVICE_USER..."
  sudo useradd -m -s /bin/bash "$SERVICE_USER"
  sudo usermod -aG audio "$SERVICE_USER"
fi

sudo chown -R "$SERVICE_USER":"$SERVICE_USER" "$APP_DIR"
sudo chmod -R u+rwX,go+rX "$APP_DIR/assets"

# -----------------------------
# 6. Normalize line endings
# -----------------------------
echo "[ytstream] Converting files to Unix line endings..."
sudo dos2unix "$APP_DIR/"*.sh "$APP_DIR/.env" >/dev/null 2>&1 || true

# -----------------------------
# 7. Configure Nginx
# -----------------------------
echo "[ytstream] Configuring nginx..."
NGINX_CONF="/etc/nginx/sites-available/ytstream"
sudo tee "$NGINX_CONF" >/dev/null <<EOF
server {
    listen 9090;
    server_name 127.0.0.1;

    location / {
        root $APP_DIR/assets;
        autoindex off;
        add_header Cache-Control "no-store";
    }
}
EOF

sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/ytstream
sudo nginx -t
sudo systemctl reload nginx

# -----------------------------
# 8. Install systemd services
# -----------------------------
echo "[ytstream] Installing systemd services..."

SYSTEMD_SRC_DIR="$REPO_DIR/systemd"
SYSTEMD_DST_DIR="/etc/systemd/system"

for svc in ytstream-audio ytstream-stream; do
  if [[ -f "$SYSTEMD_SRC_DIR/$svc.service" ]]; then
    sudo cp "$SYSTEMD_SRC_DIR/$svc.service" "$SYSTEMD_DST_DIR/"
    sudo chown root:root "$SYSTEMD_DST_DIR/$svc.service"
    sudo chmod 644 "$SYSTEMD_DST_DIR/$svc.service"
  else
    echo "[ytstream] WARNING: Missing service file $svc.service"
  fi
done

sudo systemctl daemon-reload
sudo systemctl enable ytstream-audio.service ytstream-stream.service
sudo systemctl restart ytstream-audio.service ytstream-stream.service

# -----------------------------
# 9. Done
# -----------------------------
echo "[ytstream] ✅ Installation complete!"
echo
echo "ALSA loopback configured and persistent."
echo "ytstream-audio and ytstream-stream are installed as system services."
echo "All run as user: $SERVICE_USER"
echo
echo "Check service status with:"
echo "  systemctl status ytstream-audio"
echo "  systemctl status ytstream-stream"
echo
echo "Verify ALSA loopback:"
echo "  aplay -l"
echo "  arecord -l"
