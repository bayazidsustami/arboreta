#!/usr/bin/env bash
# selfmod_music.sh – self‑modifying audio‑visual generator
# iteration counter (updated by the script itself)
ITER=0

# ------------------- configuration -------------------
# Twitter API endpoint (requires Bearer token in $TWITTER_BEARER)
TWITTER_URL="https://api.twitter.com/2/tweets/search/recent?query=%22Zeno%20paradox%22%20-lang%3Aen&tweet.fields=text&max_results=10"
# Simple positive/negative word lists for sentiment (feel free to extend)
POS=("wonder" "amazing" "love" "joy" "delight")
NEG=("hate" "confusing" "boring" "sad" "annoy")
# Mapping ranges
NOTE_MIN=220   # A3
NOTE_MAX=880   # A5
DUR_MIN=0.2    # seconds
DUR_MAX=1.0    # seconds
# Output files
AUDIO="output.wav"
VISUAL="mandala.mp4"
# ----------------------------------------------------

# ensure required tools exist
for cmd in curl python3 sox ffmpeg; do
    command -v "$cmd" >/dev/null || { echo "Missing required tool: $cmd"; exit 1; }
done

# ---------- sentiment analysis (tiny python helper) ----------
sentiment_of() {
    python3 - <<PY "$1"
import sys, re
text = sys.argv[1].lower()
pos = ["wonder","amazing","love","joy","delight"]
neg = ["hate","confusing","boring","sad","annoy"]
score = sum(text.count(w) for w in pos) - sum(text.count(w) for w in neg)
print(score)
PY
}
# --------------------------------------------------------------

# ---------- self‑modification: bump iteration counter ----------
sed -i "s/^ITER=.*/ITER=$((ITER+1))/; s/^# iteration counter.*/# iteration counter (updated by the script itself)/" "$0"
# --------------------------------------------------------------

# fetch recent tweets about obscure paradoxes
RAW_TWEETS=$(curl -s -H "Authorization: Bearer $TWITTER_BEARER" "$TWITTER_URL")
# extract tweet texts (fallback to empty if jq not available)
if command -v jq >/dev/null; then
    TEXTS=$(echo "$RAW_TWEETS" | jq -r '.data[].text')
else
    TEXTS=$(echo "$RAW_TWEETS" | grep -o '"text":"[^"]*' | cut -d'"' -f4)
fi

# build a short sound collage
rm -f "$AUDIO"
for txt in $TEXTS; do
    # compute sentiment score
    SCORE=$(sentiment_of "$txt")
    # map score to frequency and duration
    # normalize score roughly between -5..5
    NORM=$(awk -v s="$SCORE" 'BEGIN{v=s/5; if(v<-1)v=-1; if(v>1)v=1; print v}')
    FREQ=$(awk -v n="$NORM" -v lo=$NOTE_MIN -v hi=$NOTE_MAX 'BEGIN{print lo + (hi-lo)*(n+1)/2}')
    DUR=$(awk -v n="$NORM" -v lo=$DUR_MIN -v hi=$DUR_MAX 'BEGIN{print lo + (hi-lo)*(n+1)/2}')
    # generate a sine tone with SoX; append to collage
    sox -n -r 44100 -b 16 -c 1 -t wav - synth "$DUR" sine "$FREQ" vol 0.5 | \
        sox - "$AUDIO" --combine concatenate 2>/dev/null
done

# if no audio generated, create a silent placeholder
if [ ! -s "$AUDIO" ]; then
    sox -n -r 44100 -b 16 -c 1 "$AUDIO" trim 0.0 0.1
fi

# ---------- visualisation: animated fractal mandala ----------
# generate a simple fractal pattern frame via imagemagick (fallback)
if command -v convert >/dev/null; then
    FRAME="frame.png"
    convert -size 400x400 plasma:fractal -rotate $((RANDOM%360)) "$FRAME"
    ffmpeg -y -loop 1 -i "$FRAME" -i "$AUDIO" -c:v libx264 -tune stillimage -c:a aac -shortest "$VISUAL" >/dev/null 2>&1
    rm -f "$FRAME"
else
    # fallback: just copy audio as video placeholder
    ffmpeg -y -f lavfi -i color=c=black:s=400x400:d=5 -i "$AUDIO" -c:v libx264 -c:a aac -shortest "$VISUAL" >/dev/null 2>&1
fi

# ---------- play and show live ----------
# play audio while ffplay streams the video (both in background)
ffplay -autoexit -loglevel quiet "$VISUAL" &
ffplay -autoexit -loglevel quiet "$AUDIO" &
wait

# cleanup old artefacts (keep last few iterations)
ls -1t output_*.wav visual_*.mp4 2>/dev/null | tail -n +4 | xargs -r rm -f
exit 0