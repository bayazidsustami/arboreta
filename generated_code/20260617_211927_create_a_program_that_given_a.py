import sys, os, math, random, re, subprocess
from pathlib import Path
from io import BytesIO

# external deps: numpy, textblob, svgwrite, moviepy, gtts
# install with: pip install numpy textblob svgwrite moviepy gtts
import numpy as np
from textblob import TextBlob
import svgwrite
from gtts import gTTS
from moviepy.editor import ImageSequenceClip, AudioFileClip, CompositeVideoClip

# ---------- Utility functions ----------
def syllable_count(word):
    # naive vowel group count
    return len(re.findall(r'[aeiouy]+', word.lower()))

def line_meter(line):
    # approximate meter: total syllables per line
    return sum(syllable_count(w) for w in line.split())

def rhyme_key(word):
    # simple rhyme: last vowel group + following letters
    m = re.search(r'([aeiouy][a-z]*)$', word.lower())
    return m.group(1) if m else word.lower()

def sentiment_score(line):
    return TextBlob(line).sentiment.polarity  # -1 to 1

# ---------- SVG mandala generation ----------
def generate_mandala(line, size=400):
    dwg = svgwrite.Drawing(size=(size, size))
    cx, cy = size/2, size/2

    meter = line_meter(line)
    sentiment = sentiment_score(line)
    rhyme = rhyme_key(line.split()[-1]) if line.split() else ''
    random.seed(hash(line))  # deterministic per line

    # color based on sentiment
    hue = int((sentiment + 1) * 180)  # 0-360
    base_color = f"hsl({hue},70%,50%)"

    # symmetry factor from rhyme length
    sym = max(3, min(12, len(rhyme)))
    angle_step = 360 / sym

    # radius based on meter
    max_radius = size/2 * 0.9
    radius = max_radius * min(1, meter / 20)

    for i in range(sym):
        rot = i * angle_step
        group = dwg.g(transform=f"rotate({rot},{cx},{cy})")
        # nested circles
        for r in np.linspace(radius, radius*0.2, 5):
            opacity = 0.6 * (r / radius)
            circle = dwg.circle(center=(cx, cy - r),
                                r=r*0.1,
                                fill=base_color,
                                fill_opacity=opacity,
                                stroke='none')
            group.add(circle)
        dwg.add(group)
    return dwg.tostring()

def svg_to_png(svg_data, out_path):
    # use cairosvg if available, else fallback to simple conversion via inkscape if installed
    try:
        import cairosvg
        cairosvg.svg2png(bytestring=svg_data.encode('utf-8'), write_to=out_path)
    except Exception:
        # attempt inkscape CLI
        tmp_svg = out_path.with_suffix('.svg')
        tmp_svg.write_text(svg_data)
        subprocess.run(['inkscape', str(tmp_svg), '--export-png', str(out_path)], check=False)
        tmp_svg.unlink(missing_ok=True)

# ---------- Main processing ----------
def main(poem_path):
    text = Path(poem_path).read_text(encoding='utf8')
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    frames = []
    tmp_dir = Path('tmp_frames')
    tmp_dir.mkdir(exist_ok=True)

    # generate SVG and PNG frames
    for idx, line in enumerate(lines):
        svg = generate_mandala(line)
        png_path = tmp_dir / f'frame_{idx:04d}.png'
        svg_to_png(svg, png_path)
        frames.append(str(png_path))

    # create audio narration
    tts = gTTS(text='\n'.join(lines), lang='en')
    audio_path = 'poem.mp3'
    tts.save(audio_path)

    # video clip
    clip = ImageSequenceClip(frames, fps=1)  # 1 sec per line
    audio = AudioFileClip(audio_path)
    clip = clip.set_audio(audio).set_duration(audio.duration)

    output = 'poem_mandala.mp4'
    clip.write_videofile(output, codec='libx264', fps=24)

    # cleanup
    for f in frames:
        Path(f).unlink(missing_ok=True)
    tmp_dir.rmdir()
    print(f'Finished. Video saved as {output}')

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print('Usage: python mandala_poem.py <poem.txt>')
        sys.exit(1)
    main(sys.argv[1])