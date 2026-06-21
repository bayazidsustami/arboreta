#!/usr/bin/env bash
# mandala_twitter.sh - stream hashtags, map to notes, drive a WebGL mandala
# Dependencies: twurl, jq, python3, websocat (or socat), ffmpeg, sox, node (optional)
# This script launches a simple WebSocket server that serves an HTML page with Three.js.
# The Bash part pulls live tweets, computes a pseudo‑entropy, selects a MIDI note,
# determines sentiment via a tiny Python helper, and pushes JSON events to the client.

set -euo pipefail

# ----------- CONFIGURATION -----------
PORT=8081                 # WebSocket port
HTML_DIR=$(mktemp -d)    # Temp dir for generated HTML/JS
TWITTER_STREAM="https://api.twitter.com/2/tweets/search/stream?tweet.fields=entities,lang"
# -------------------------------------------------------------------------

# Helper: tiny Python to compute sentiment polarity (0..1) using textblob (fallback avg)
cat > "$HTML_DIR/sentiment.py" <<'PY'
import sys, json
try:
    from textblob import TextBlob
except Exception:
    TextBlob = None
def polarity(txt):
    if TextBlob:
        return (TextBlob(txt).sentiment.polarity + 1) / 2.0
    return 0.5
for line in sys.stdin:
    try:
        obj = json.loads(line)
        txt = obj.get('data', {}).get('text', '')
        print(polarity(txt))
    except:
        print(0.5)
PY

# Helper: generate the WebGL client (uses Three.js via CDN)
cat > "$HTML_DIR/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="en"><head>
<meta charset="UTF-8"><title>Twitter Mandala</title>
<style>body{margin:0;overflow:hidden;}</style>
</head><body>
<script src="https://cdn.jsdelivr.net/npm/three@0.164/build/three.min.js"></script>
<script>
let scene = new THREE.Scene();
let cam = new THREE.PerspectiveCamera(60,innerWidth/innerHeight,0.1,1000);
cam.position.z = 5;
let renderer = new THREE.WebGLRenderer({antialias:true});
renderer.setSize(innerWidth,innerHeight);
document.body.appendChild(renderer.domElement);
let tiles = [];

function addTile(data){
  const size = 0.2 + data.entropy*0.3;
  const geo = new THREE.CircleGeometry(size, 6);
  const col = new THREE.Color(`hsl(${data.note*30%360},70%,${50+data.sentiment*50}%)`);
  const mat = new THREE.MeshBasicMaterial({color:col, side:THREE.DoubleSide});
  const mesh = new THREE.Mesh(geo, mat);
  mesh.rotation.z = data.rotation;
  mesh.position.x = (Math.random()-0.5)*4;
  mesh.position.y = (Math.random()-0.5)*4;
  scene.add(mesh);
  tiles.push(mesh);
  if(tiles.length>200){ scene.remove(tiles.shift()); }
}
function animate(){
  requestAnimationFrame(animate);
  renderer.render(scene,camera);
}
animate();

// WebSocket to receive events from Bash script
let ws = new WebSocket(`ws://${location.hostname}:$PORT`);
ws.onmessage = e=> addTile(JSON.parse(e.data));
ws.onclose =()=> console.log('socket closed');
</script>
</body></html>
HTML

# --------- Launch a tiny WebSocket server (Python) ----------
cat > "$HTML_DIR/ws_server.py" <<'PY'
import asyncio, json, sys, os, websockets

clients = set()

async def handler(ws, path):
    clients.add(ws)
    try:
        async for msg in ws:
            pass
    finally:
        clients.remove(ws)

async def broadcast():
    while True:
        line = await asyncio.get_event_loop().run_in_executor(None, sys.stdin.readline)
        if not line: break
        data = json.loads(line.strip())
        if clients:
            await asyncio.wait([c.send(json.dumps(data)) for c in clients])

async def main():
    async with websockets.serve(handler, "0.0.0.0", $PORT):
        await broadcast()

asyncio.run(main())
PY

# Start the WS server in background
python3 "$HTML_DIR/ws_server.py" &
WS_PID=$!

# Open the HTML page in default browser (Linux/macOS detection)
if command -v xdg-open > /dev/null; then
  xdg-open "$HTML_DIR/index.html"
elif command -v open > /dev/null; then
  open "$HTML_DIR/index.html"
else
  echo "Open $HTML_DIR/index.html manually in a browser."
fi

# --------- Stream tweets, process hashtags ----------
# twurl must be configured with OAuth tokens beforehand.
twurl -H api.twitter.com "/2/tweets/search/stream?tweet.fields=entities,text" |
while read -r tweet_json; do
  # extract hashtags (fallback empty)
  hashtags=$(echo "$tweet_json" | jq -r '.data.entities.hashtags[]?.tag' 2>/dev/null || true)
  for tag in $hashtags; do
    # lexical entropy approximated by Shannon of characters
    entropy=$(echo -n "$tag" | awk '{
      split($0,ch,""); for(i in ch) freq[ch[i]]++;
      n=length($0);
      for(c in freq) {p=freq[c]/n; e-=p*log(p)/log(2);}
      printf "%.3f", e;
    }')
    # map entropy 0..~5 to MIDI note 48..72
    note=$(awk -v e=$entropy 'BEGIN{printf "%d", 48 + (e/5)*24}')
    # rotation based on hash
    rotation=$(echo -n "$tag" | md5sum | awk '{print strtonum("0x" substr($1,1,8))/0xffffffff * 6.283185307179586}')
    # sentiment via tiny python helper
    sentiment=$(echo "$tweet_json" | python3 "$HTML_DIR/sentiment.py")
    # emit JSON line to WS server
    printf '{"hashtag":"%s","entropy":%s,"note":%d,"rotation":%s,"sentiment":%s}\n' \
      "$tag" "$entropy" "$note" "$rotation" "$sentiment"
done
done

# Cleanup on exit
trap "kill $WS_PID 2>/dev/null; rm -rf $HTML_DIR" EXIT