import os, sys, random, math, base64, io
from collections import Counter
from PIL import Image, ImageDraw

#===DATA=== (do not edit below this line)
SVG_DATA = """<svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
<!--
Haiku:
crimson dusk whispers
emerald tides rise and fall
violet night breathes deep
-->
<g transform="translate(100,100)">
  <path d="M0,0 L90,0 A90,90 0 0,1 0,90 Z" fill="#ff5555"/>
  <path d="M0,0 L0,90 A90,90 0 0,1 -90,0 Z" fill="#55ff55"/>
  <path d="M0,0 L-90,0 A90,90 0 0,1 0,-90 Z" fill="#5555ff"/>
</g>
</svg>"""
HAIKU = """crimson dusk whispers
emerald tides rise and fall
violet night breathes deep"""
#===END===

def generate_mandala(size=256):
    img = Image.new('RGB', (size, size), 'black')
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2
    for i in range(12):
        r = size // 2 * (i + 1) / 12
        color = tuple(random.randint(0,255) for _ in range(3))
        bbox = [cx - r, cy - r, cx + r, cy + r]
        draw.ellipse(bbox, outline=color, width=3)
    return img

def dominant_palette(img, n=3):
    small = img.resize((64,64))
    colors = list(small.getdata())
    most = [c for c,_ in Counter(colors).most_common(n)]
    return most

COLOR_WORDS = {
    (255,0,0):'crimson',(255,85,85):'crimson',(255,64,64):'crimson',
    (0,255,0):'emerald',(85,255,85):'emerald',(64,255,64):'emerald',
    (0,0,255):'violet',(85,85,255):'violet',(64,64,255):'violet'
}
def nearest_word(rgb):
    return min(COLOR_WORDS.items(),
               key=lambda kv: sum((a-b)**2 for a,b in zip(kv[0],rgb)))[1]

def compose_haiku(palette):
    # simple fixed 5-7-5 using color words
    words = [nearest_word(c) for c in palette]
    line1 = f"{words[0]} dusk whispers"
    line2 = f"{words[1]} tides rise and fall"
    line3 = f"{words[2]} night breathes deep"
    return "\n".join([line1,line2,line3])

def make_svg(haiku):
    # use syllable counts 5,7,5 to drive radii
    radii = [50,70,50]
    colors = ['#ff5555','#55ff55','#5555ff']
    parts = ['<svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">',f'<!--\nHaiku:\n{haiku}\n-->','<g transform="translate(100,100)">']
    for r,c in zip(radii,colors):
        parts.append(f'  <path d="M0,0 L{r},0 A{r},{r} 0 0,1 0,{r} Z" fill="{c}"/>')
    parts.append('</g></svg>')
    return "\n".join(parts)

def self_update(svg, haiku):
    src = open(__file__, 'r', encoding='utf-8').read()
    pre, _sep, post = src.partition('#===DATA===')
    new_src = pre + '#===DATA=== (do not edit below this line)\n'
    new_src += f'SVG_DATA = """{svg}"""\n'
    new_src += f'HAIKU = """{haiku}"""\n'
    new_src += '#===END===\n' + post.split('#===END===',1)[1]
    with open(__file__, 'w', encoding='utf-8') as f:
        f.write(new_src)

def main():
    img_path = 'prev.png'
    if os.path.exists(img_path):
        img = Image.open(img_path)
    else:
        img = generate_mandala()
        img.save(img_path)

    palette = dominant_palette(img)
    haiku = compose_haiku(palette)
    svg = make_svg(haiku)

    # write new image for next run
    new_img = generate_mandala()
    new_img.save(img_path)

    # self‑modify source
    self_update(svg, haiku)

if __name__ == '__main__':
    main()