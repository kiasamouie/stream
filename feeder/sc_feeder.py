#!/usr/bin/env python3
import json, os, subprocess, time, socket, shlex, tempfile, pathlib

PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CACHE = os.path.join(PROJ, "cache")
TMP   = os.path.join(PROJ, "tmp")
NOWPLAYING = os.path.join(TMP, "nowplaying.txt")
ART_PATH   = os.path.join(TMP, "artwork.png")

SC_PLAYLIST = os.environ.get("SC_PLAYLIST")
LIQ_HOST = "127.0.0.1"
LIQ_PORT = 1234

def sh(cmd, **kw):
    return subprocess.check_output(cmd, text=True, **kw)

def try_sh(cmd, **kw):
    try:
        return sh(cmd, **kw)
    except subprocess.CalledProcessError:
        return ""

def liq_cmd(cmd: str):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((LIQ_HOST, LIQ_PORT))
    s.sendall((cmd+"\n").encode())
    data = s.recv(4096)
    s.close()
    return data.decode(errors="ignore")

def ensure_files():
    pathlib.Path(CACHE).mkdir(parents=True, exist_ok=True)
    pathlib.Path(TMP).mkdir(parents=True, exist_ok=True)
    if not os.path.exists(NOWPLAYING):
        open(NOWPLAYING, "w").write("Loading…")
    if not os.path.exists(ART_PATH):
        open(ART_PATH, "wb").write(bytes.fromhex("89504E470D0A1A0A0000000D49484452000000010000000108060000001F15C4890000000A49444154789C636000000200010005FE02FEA7D805820000000049454E44AE426082"))

def resolve_playlist_entries(playlist_url):
    j = sh(["yt-dlp","-J","--flat-playlist",playlist_url])
    data = json.loads(j)
    out = []
    for e in data.get("entries", []):
        url = e.get("url") or e.get("id")
        if not url: continue
        if not url.startswith("http"):
            url = "https://soundcloud.com/" + url
        out.append(url)
    return out

def get_meta(url):
    d = json.loads(sh(["yt-dlp","-J",url]))
    artist = d.get("uploader") or d.get("artist") or "Unknown"
    title  = d.get("title") or "Unknown Title"
    return artist, title

def update_artwork(url):
    tmpbase = os.path.join(TMP, "artwork_dl")
    # Download only thumbnail, convert to PNG
    try_sh(["yt-dlp","-q","--skip-download","--write-thumbnail","--convert-thumbnails","png","-o", tmpbase, url])
    # Find a png result (yt-dlp may append extensions)
    for cand in [tmpbase, tmpbase+".png", tmpbase+".jpg", tmpbase+".webp.png", tmpbase+".png.png"]:
        if os.path.exists(cand):
            os.replace(cand, ART_PATH)
            break

def expected_path(url):
    # Ask yt-dlp what filename it will use, then download if missing
    tmpl = os.path.join(CACHE, "%(uploader)s - %(title)s.%(ext)s")
    path = sh(["yt-dlp","--get-filename","-o", tmpl, url]).strip()
    return path

def download_audio_if_needed(url, path):
    if os.path.exists(path):
        return
    tmpl = os.path.join(CACHE, "%(uploader)s - %(title)s.%(ext)s")
    # m4a preferred; fall back to bestaudio
    subprocess.check_call(["yt-dlp","-q","-N","4","-f","bestaudio[ext=m4a]/bestaudio","-o", tmpl, url])

def push_track(path, artist, title):
    req = f'annotate:artist={artist},title={title}:{path}'
    print("PUSHING:", req)
    print("RESPONSE:", liq_cmd(f'rq.push {shlex.quote(req)}'))

def main():
    ensure_files()
    playlist = SC_PLAYLIST
    if not playlist:
        raise SystemExit("SC_PLAYLIST not set. Source .env first.")
    while True:
        print("working")
        entries = resolve_playlist_entries(playlist)
        if not entries:
            time.sleep(5)
            continue
        for url in entries:
            try:
                artist, title = get_meta(url)
                open(NOWPLAYING,"w").write(f"{artist} – {title}")
                update_artwork(url)
                path = expected_path(url)
                download_audio_if_needed(url, path)
                push_track(path, artist, title)
            except Exception as e:
                print("Error:", e)
            time.sleep(1)
        time.sleep(5)

if __name__ == "__main__":
    main()
