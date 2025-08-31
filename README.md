# Streamlab — Twitch / YouTube / Icecast Auto DJ with SoundCloud

This project turns a SoundCloud playlist into a **live video stream** with:
- Background looping MP4
- Playlist audio (via Icecast + Liquidsoap)
- Overlayed song title + artwork
- Streaming out to Twitch, YouTube, or any RTMP endpoint

Tested on **WSL (Ubuntu)** and Linux servers.

---

## 📦 Requirements

### System packages
Install dependencies:
```bash
sudo apt-get update
sudo apt-get install -y \
    ffmpeg \
    icecast2 \
    liquidsoap \
    python3-pip \
    python3-venv \
    moreutils \
    tmux \
    fonts-dejavu-core \
    curl \
    git
```

### Python packages
```bash
pip3 install --upgrade yt-dlp requests python-dotenv
```

---

## 📂 Project structure

```
streamlab/
├── assets/               # Background video, artwork, etc.
│   └── BACKGROUND.mp4
├── cache/                # Cached SoundCloud audio files
├── config/               # Icecast config
│   └── icecast.xml
├── feeder/               # Python feeder: pulls playlist + metadata
│   └── sc_feeder.py
├── liquidsoap/           # Liquidsoap script
│   └── soundcloud_radio.liq
├── logs/                 # Icecast + liquidsoap logs
│   ├── access.log
│   └── error.log
├── scripts/              # Run/stop helper scripts
│   ├── run_all.sh
│   ├── stop_all.sh
│   └── stream.sh
└── tmp/                  # Runtime metadata
    ├── artwork.png
    └── nowplaying.txt
```

---

## ⚙️ Setup

### 1. Configure environment
Edit `.env` in the project root:

```bash
# REQUIRED: set your SoundCloud playlist URL and RTMP endpoint
SC_PLAYLIST="https://soundcloud.com/YOUR_USER/sets/YOUR_PLAYLIST"
RTMP_URL="rtmp://live.twitch.tv/app/YOUR_STREAM_KEY"

# Optional: background video
BG_MP4="$HOME/streamlab/assets/BACKGROUND.mp4"
```

---

### 2. Run each service manually (debug mode)

**Terminal 1 — Icecast**
```bash
cd ~/streamlab
icecast2 -c config/icecast.xml
```

**Terminal 2 — Liquidsoap**
```bash
cd ~/streamlab
liquidsoap liquidsoap/soundcloud_radio.liq
```

**Terminal 3 — Feeder**
```bash
cd ~/streamlab
set -a && source .env && set +a
python3 feeder/sc_feeder.py
```

**Terminal 4 — FFmpeg (stream to Twitch/YouTube/etc.)**
```bash
cd ~/streamlab
./scripts/stream.sh
```

---

### 3. Use tmux orchestration (easier)

Start everything:
```bash
cd ~/streamlab
./scripts/run_all.sh
```

Attach to logs:
```bash
tmux attach -t streamlab
```

Stop:
```bash
./scripts/stop_all.sh
```

---

## 🎧 Testing

- Open in browser/VLC:
  ```
  http://127.0.0.1:8000/live.mp3
  ```
  → should play SoundCloud playlist audio

- Go live on Twitch/YouTube: check your dashboard preview.

---

## ⚡ Tips

- **Background video**: Replace `assets/BACKGROUND.mp4` with your own loop.
- **Twitch quality**: Adjust bitrate in `scripts/stream.sh`. Twitch max:
  ```
  -b:v 6000k -maxrate 6000k -bufsize 12M
  -c:a aac -b:a 160k -ar 44100 -ac 2
  ```
- **Local test stream**: Change `RTMP_URL` in `.env` to a file:
  ```
  RTMP_URL="test.flv"
  ```
  and run `./scripts/stream.sh`. Play in VLC.

---

## 🔧 Troubleshooting

- **No sound in Icecast** → Feeder isn’t pushing tracks.  
  Run manually:
  ```bash
  telnet 127.0.0.1 1234
  rq.push annotate:title="Test",artist="Me":/path/to/file.mp3
  ```

- **Silence but tracks exist** → check `logs/error.log` for Liquidsoap errors.

---
