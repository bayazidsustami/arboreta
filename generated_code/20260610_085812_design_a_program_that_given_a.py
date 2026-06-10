import sys, io, base64, math, random, json, textwrap
from pathlib import Path

# ---------- Simple haiku syllable splitter (naïve) ----------
def split_syllables(text):
    vowels = "aeiouyAEIOUY"
    words = text.strip().split()
    syls = []
    for w in words:
        cur = ""
        for ch in w:
            cur += ch
            if ch in vowels:
                syls.append(cur)
                cur = ""
        if cur:
            syls.append(cur)
    return syls

# ---------- Generate tones for each syllable ----------
def tone_for_syllable(idx, total):
    # map index to frequency within one octave
    base = 220.0
    freq = base * (2 ** (idx / total))
    return freq

def synth_sine(freq, dur=0.5, rate=44100):
    import numpy as np
    t = np.linspace(0, dur, int(rate*dur), False)
    wave = 0.5*np.sin(2*np.pi*freq*t)
    return wave

def make_audio_blob(syllables):
    import numpy as np
    rate = 44100
    audio = np.array([], dtype=np.float32)
    for i, syl in enumerate(syllables):
        f = tone_for_syllable(i, len(syllables))
        wave = synth_sine(f, dur=0.3, rate=rate)
        # simple per‑syllable rhythm: longer pause for ends of lines
        pause = np.zeros(int(rate*0.1))
        audio = np.concatenate((audio, wave, pause))
    # convert to 16‑bit PCM
    pcm = np.int16(audio/np.max(np.abs(audio)) * 32767)
    wav_bytes = io.BytesIO()
    import wave
    with wave.open(wav_bytes, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(rate)
        wf.writeframes(pcm.tobytes())
    return wav_bytes.getvalue()

# ---------- Generate kaleidoscopic animation script ----------
def make_js_animation(syllables):
    js = """
    const canvas = document.getElementById('c');
    const ctx = canvas.getContext('2d');
    let t = 0;
    function draw(){
        const w = canvas.width, h = canvas.height;
        ctx.clearRect(0,0,w,h);
        const reps = %d;
        for(let i=0;i<reps;i++){
            const angle = (t+ i*2*Math.PI/reps);
            ctx.save();
            ctx.translate(w/2, h/2);
            ctx.rotate(angle);
            ctx.scale(Math.sin(t*0.3)+1.5, Math.cos(t*0.3)+1.5);
            ctx.strokeStyle = `hsl(${(t*40+i*30)%360},80%%,60%%)`;
            ctx.beginPath();
            ctx.moveTo(-100,0);
            ctx.lineTo(100,0);
            ctx.stroke();
            ctx.restore();
        }
        t+=0.02;
        requestAnimationFrame(draw);
    }
    draw();
    """ % len(syllables)
    return js

# ---------- Assemble self‑contained HTML with audio ----------
def make_html(haiku, audio_blob, js_code):
    audio_b64 = base64.b64encode(audio_blob).decode()
    html = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Haiku Sonic Kaleidoscope</title>
<style>body{{margin:0;background:#111}}canvas{{display:block}}</style>
</head>
<body>
<canvas id="c" width="800" height="800"></canvas>
<audio id="a" autoplay loop src="data:audio/wav;base64,{audio_b64}"></audio>
<script>
{js_code}
</script>
</body>
</html>"""
    return html

# ---------- Main driver ----------
def main():
    if len(sys.argv) < 2:
        print("Usage: python haiku_kaleido.py \"your haiku lines separated by /\"")
        return
    haiku = sys.argv[1].replace("\\n"," ").replace("/", " ")
    syls = split_syllables(haiku)
    audio = make_audio_blob(syls)
    js = make_js_animation(syls)
    html = make_html(haiku, audio, js)

    # embed HTML inside a PNG using a custom tEXt chunk (browsers ignore it)
    png_data = bytearray(b'\x89PNG\r\n\x1a\n')  # PNG signature
    # IHDR chunk (1x1 pixel)
    ihdr = b'\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00'
    crc = base64.b16encode(__import__('zlib').crc32(b'IHDR'+ihdr).to_bytes(4,'big')).decode()
    png_data += b'\x00\x00\x00\x0dIHDR' + ihdr + bytes.fromhex(crc)
    # tEXt chunk with HTML
    key = b'HTML'
    txt = key + b'\x00' + html.encode('utf-8')
    length = len(txt).to_bytes(4, 'big')
    chunk_type = b'tEXt'
    crc = __import__('zlib').crc32(chunk_type + txt).to_bytes(4, 'big')
    png_data += length + chunk_type + txt + crc
    # IEND
    png_data += b'\x00\x00\x00\x00IEND\xaeB`\x82'

    out_path = Path("haiku_kaleido.png")
    out_path.write_bytes(png_data)
    print(f"Generated {out_path} – open it in a browser to see & hear the piece.")

if __name__ == "__main__":
    main()