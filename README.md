# YTStream – 24/7 YouTube Streaming Service

This project provides a 24/7 YouTube streaming service that plays audio from a YouTube playlist and streams it live to YouTube with dynamic metadata, artwork, and background video.

It is designed to run on a **headless Ubuntu server** with systemd services.

---

## 🚀 Features

- Continuous audio playback via **MPV**.
- Streams to YouTube with **FFmpeg**.
- Dynamic overlay:
  - Current track title/artist.
  - Thumbnail artwork (auto-downloaded via `yt-dlp`).
- Background looping video.
- Centralized configuration via `.env`.
- Managed as `systemd` services:
  - `ytstream-audio`
  - `ytstream-stream`
- Artwork exposed over HTTP via **Nginx**.

---

## 📦 Prerequisites

Install required packages:

```bash
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
  nginx
