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
  pulseaudio \
  pulseaudio-utils \
  fonts-dejavu-core \
  nginx \
  dos2unix

# -----------------------------
# 3. Configure PulseAudio (user mode)
# -----------------------------
echo "[ytstream] Configuring PulseAudio user mode..."

# Ensure user exists
if ! id "$SERVICE_USER" &>/dev/null; then
  echo "[ytstream] Creating user $SERVICE_USER..."
  sudo useradd -m -s /bin/bash "$SERVICE_USER"
fi

USER_HOME="/home/$SERVICE_USER"
PULSE_CONF_DIR="$USER_HOME/.config/pulse"
SYSTEMD_USER_DIR="$USER_HOME/.config/systemd/user"

sudo -u "$SERVICE_USER" mkdir -p "$PULSE_CONF_DIR" "$SYSTEMD_USER_DIR"

# Write PulseAudio configs
echo "[ytstream] Writing PulseAudio configuration..."
sudo tee "$PULSE_CONF_DIR/default.pa" >/dev/null <<'EOF'
.include /etc/pulse/default.pa
load-module module-null-sink sink_name=YTStream sink_properties=device.description=YTStream
EOF

sudo tee "$PULSE_CONF_DIR/client.conf" >/dev/null <<'EOF'
autospawn = yes
daemon-binary = /usr/bin/pulseaudio
enable-shm = yes
EOF

# Copy PulseAudio systemd service
if [[ -f "$REPO_DIR/systemd/pulseaudio.service" ]]; then
  sudo cp "$REPO_DIR/systemd/pulseaudio.service" "$SYSTEMD_USER_DIR/"
else
  echo "[ytstream] WARNING: pulseaudio.service not found in $REPO_DIR/systemd/"
fi

sudo chown -R "$SERVICE_USER":"$SERVICE_USER" "$PULSE_CONF_DIR" "$SYSTEMD_USER_DIR"

# Enable lingering and start PulseAudio
sudo loginctl enable-linger "$SERVICE_USER"
sudo -u "$SERVICE_USER" systemctl --user daemon-reload || true
sudo -u "$SERVICE_USER" systemctl --user enable pulseaudio.service || true
sudo -u "$SERVICE_USER" systemctl --user start pulseaudio.service || true

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
# 8. Install systemd user services
# -----------------------------
echo "[ytstream] Installing user services for ytstream..."

for svc in pulseaudio ytstream-audio ytstream-stream; do
  if [[ -f "$REPO_DIR/systemd/$svc.service" ]]; then
    sudo cp "$REPO_DIR/systemd/$svc.service" "$SYSTEMD_USER_DIR/"
    sudo chown "$SERVICE_USER":"$SERVICE_USER" "$SYSTEMD_USER_DIR/$svc.service"
  else
    echo "[ytstream] WARNING: Missing service file $svc.service"
  fi
done

# Enable all user-level services
sudo -u "$SERVICE_USER" bash -c '
  systemctl --user daemon-reload
  systemctl --user enable pulseaudio.service ytstream-audio.service ytstream-stream.service
  systemctl --user restart pulseaudio.service ytstream-audio.service ytstream-stream.service
'

# -----------------------------
# 9. Done
# -----------------------------
echo "[ytstream] ✅ Installation complete!"
echo
echo "PulseAudio, ytstream-audio, and ytstream-stream are now configured."
echo "All run as user: $SERVICE_USER"
echo
echo "Check service status with:"
echo "  sudo -u $SERVICE_USER systemctl --user status pulseaudio"
echo "  sudo -u $SERVICE_USER systemctl --user status ytstream-audio"
echo "  sudo -u $SERVICE_USER systemctl --user status ytstream-stream"
