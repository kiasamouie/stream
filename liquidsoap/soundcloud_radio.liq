# Liquidsoap 2.x minimal: request queue -> Icecast

# Enable telnet so the feeder can push requests
set("server.telnet", true)
set("server.telnet.bind_addr", "127.0.0.1")
set("server.telnet.port", 1234)

set("log.stdout", true)
set("log.level", 3)

# Request queue (feeder pushes tracks into this)
rq = request.queue(id="rq")

# Make it safe so it's not fallible
safe_rq = mksafe(rq)

# Use safe queue as the only source
src = safe_rq

# Stream to local Icecast (ffmpeg will read http://127.0.0.1:8000/live.mp3)
output.icecast(
  %mp3(bitrate=192, stereo=true, id3v2=true),
  host="127.0.0.1",
  port=8000,
  password="hackme",
  mount="/live.mp3",
  name="SC Radio",
  description="SoundCloud playlist",
  public=false,
  src
)
