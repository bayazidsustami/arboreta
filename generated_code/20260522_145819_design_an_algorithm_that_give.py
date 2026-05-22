import sys, time, math, random, xml.etree.ElementTree as ET

# ---------- Simple sentiment & rhythm analysis ----------
POS = {"joy","happy","love","wonder","delight","bright","sunny","glee","glad","cheer"}
NEG = {"sad","hate","anger","sorrow","gloom","dark","pain","grim","moan","lonely"}

def analyze(text):
    words = [w.strip(".,!?;:()[]\"'").lower() for w in text.split()]
    pos = sum(1 for w in words if w in POS)
    neg = sum(1 for w in words if w in NEG)
    sentiment = (pos - neg) / max(1, len(words))          # -1 .. 1
    lengths = [len(w) for w in words if w]
    rhythm = (max(lengths)-min(lengths)) / max(1, sum(lengths)/len(lengths)) if lengths else 0
    return sentiment, rhythm, words

# ---------- Fractal SVG generator ----------
def hue_from_sentiment(s):
    # map -1..1 to 0..240 (blue to red)
    return int((s+1)*120)

def fractal_svg(words, sentiment, rhythm, size=500):
    hue = hue_from_sentiment(sentiment)
    root = ET.Element('svg', attrib={
        'xmlns':'http://www.w3.org/2000/svg',
        'width':str(size), 'height':str(size),
        'viewBox':'0 0 {} {}'.format(size, size)
    })
    defs = ET.SubElement(root, 'defs')
    style = ET.SubElement(defs, 'style')
    style.text = '''
@keyframes pulse {{
  0% {{ r: 5; }}
  50% {{ r: 20; }}
  100% {{ r: 5; }}
}}
circle {{ animation: pulse 2s infinite ease-in-out; }}
'''
    def draw(x, y, r, depth):
        if depth == 0 or r < 2: return
        col = f'hsl({hue},{int(70+30*depth)}%,50%)'
        circle = ET.SubElement(root, 'circle', {
            'cx':str(x), 'cy':str(y), 'r':str(r),
            'fill':col, 'stroke':'none'
        })
        angle = 0
        for _ in range(5):
            angle += random.uniform(0.8, 1.2)*math.pi/2
            nx = x + r*math.cos(angle)
            ny = y + r*math.sin(angle)
            draw(nx, ny, r*0.5* (0.8+0.4*rhythm), depth-1)
    draw(size/2, size/2, size*0.3, 6)
    return ET.tostring(root, encoding='unicode')

# ---------- Live‑coding simulation ----------
CODE_STAGES = [
    "# stage 1: load text\nimport sys",
    "# stage 2: analyse sentiment\nsentiment, rhythm, words = analyze(text)",
    "# stage 3: generate SVG\nsvg = fractal_svg(words, sentiment, rhythm)",
    "# stage 4: output HTML\nhtml = f'''<html><body>{svg}</body></html>'''",
    "# stage 5: write file\nopen('output.html','w').write(html)"
]

def live_code():
    for snippet in CODE_STAGES:
        for line in snippet.split('\\n'):
            sys.stdout.write(line + '\\n')
            sys.stdout.flush()
            time.sleep(0.3)          # typing effect
        time.sleep(0.7)

# ---------- Main execution ----------
def main():
    text = sys.stdin.read().strip() or "Joy and sorrow dance together."
    sentiment, rhythm, words = analyze(text)
    live_code()
    svg = fractal_svg(words, sentiment, rhythm)
    html = f\"\"\"<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Fractal Live‑Coding</title></head>
<body>{svg}</body></html>\"\"\"
    with open('live_fractal.html','w') as f:
        f.write(html)
    print("\\nGenerated live_fractal.html – open it in a browser to see the animated fractal.")
    
if __name__ == "__main__":
    main()