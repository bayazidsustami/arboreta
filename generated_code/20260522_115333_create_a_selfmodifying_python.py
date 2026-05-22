#!/usr/bin/env python3
"""
Self‑modifying Instagram‑driven ASCII kaleidoscope.

On each run:
1. Pull recent posts for a given hashtag (mocked with placeholder URLs).
2. Download the top 10 images and extract their dominant RGB colors.
3. Generate an ASCII‑art frame that paints those colors as colored blocks.
4. Rewrite the source file so the next execution shows the new frame.
5. Commit the previous version to git as a “memory snapshot”.
"""

import os, sys, json, subprocess, base64, textwrap, random, math
from io import BytesIO
from urllib.request import urlopen, Request

try:
    from PIL import Image
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow"])
    from PIL import Image

# ----------------------------------------------------------------------
# CONFIGURATION
HASHTAG = "nature"
MAX_IMAGES = 10
ASCII_WIDTH = 80
ASCII_HEIGHT = 40
GIT_REPO = "."                       # assumes script lives in a git repo
# ----------------------------------------------------------------------


def fetch_image_urls():
    """
    Placeholder: In a real implementation this would hit Instagram's
    Graph API (requires auth) and return URLs of recent posts for HASHTAG.
    Here we use a static list of CC‑licensed images.
    """
    sample = [
        "https://picsum.photos/seed/pic1/400/400",
        "https://picsum.photos/seed/pic2/400/400",
        "https://picsum.photos/seed/pic3/400/400",
        "https://picsum.photos/seed/pic4/400/400",
        "https://picsum.photos/seed/pic5/400/400",
        "https://picsum.photos/seed/pic6/400/400",
        "https://picsum.photos/seed/pic7/400/400",
        "https://picsum.photos/seed/pic8/400/400",
        "https://picsum.photos/seed/pic9/400/400",
        "https://picsum.photos/seed/pic10/400/400",
    ]
    return sample[:MAX_IMAGES]


def download_image(url):
    """Download image bytes, returning a Pillow Image."""
    req = Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urlopen(req, timeout=10) as resp:
        data = resp.read()
    return Image.open(BytesIO(data)).convert("RGB")


def dominant_color(img):
    """Return the most common color in the image (simple histogram)."""
    # Resize to speed up
    thumb = img.resize((64, 64))
    pixels = list(thumb.getdata())
    # Quantize to 64 colors
    quantized = thumb.quantize(colors=64)
    palette = quantized.getpalette()
    color_counts = sorted(quantized.getcolors(), reverse=True)
    most = color_counts[0][1]
    r = palette[most * 3]
    g = palette[most * 3 + 1]
    b = palette[most * 3 + 2]
    return (r, g, b)


def rgb_to_ansi(r, g, b):
    """Map 24‑bit RGB to an ANSI 256‑color code."""
    # 16‑231 are a 6×6×6 colour cube
    r6 = int(r / 51)
    g6 = int(g / 51)
    b6 = int(b / 51)
    return 16 + 36 * r6 + 6 * g6 + b6


def build_frame(colors):
    """Create an ASCII art frame where each block's background is one of the colors."""
    block = "  "  # two spaces gives a square aspect
    rows = []
    for y in range(ASCII_HEIGHT):
        line = []
        for x in range(ASCII_WIDTH):
            # pick a color based on simple polar kaleidoscope math
            angle = math.atan2(y - ASCII_HEIGHT / 2, x - ASCII_WIDTH / 2)
            distance = math.hypot(x - ASCII_WIDTH / 2, y - ASCII_HEIGHT / 2)
            idx = int((math.sin(angle * 3) + math.cos(distance / 4)) * len(colors) / 2) % len(colors)
            r, g, b = colors[idx]
            code = rgb_to_ansi(r, g, b)
            line.append(f"\x1b[48;5;{code}m{block}\x1b[0m")
        rows.append("".join(line))
    return "\n".join(rows)


def git_snapshot():
    """Commit the current file as a snapshot."""
    # Ensure we are inside a git repo
    subprocess.run(["git", "add", __file__], cwd=GIT_REPO, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["git", "commit", "-m", f"snapshot: {HASHTAG} @ {int(time.time())}"], cwd=GIT_REPO,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def write_self(new_frame):
    """Rewrite this script, embedding the generated frame as a string literal."""
    with open(__file__, "r", encoding="utf-8") as f:
        source = f.readlines()

    # Find the marker lines that surround the frame placeholder
    start_marker = "# <<< FRAME START >>>\n"
    end_marker = "# <<< FRAME END >>>\n"

    # Build new source
    out = []
    in_placeholder = False
    for line in source:
        if line == start_marker:
            out.append(line)
            out.append(f'FRAME = """\\\n{new_frame}\\\n"""\n')
            in_placeholder = True
            continue
        if line == end_marker:
            out.append(line)
            in_placeholder = False
            continue
        if not in_placeholder:
            out.append(line)

    # Write back
    with open(__file__, "w", encoding="utf-8") as f:
        f.writelines(out)


def main():
    # 1. fetch URLs (mocked)
    urls = fetch_image_urls()

    # 2. download and extract dominant colors
    colors = []
    for u in urls:
        try:
            img = download_image(u)
            colors.append(dominant_color(img))
        except Exception as e:
            # skip failures
            continue
    if not colors:
        colors = [(255, 255, 255)]

    # 3. render frame
    frame = build_frame(colors)

    # 4. display current frame (the one embedded from previous run)
    # The variable FRAME will be overwritten later, but we can show the new one now.
    print(frame)

    # 5. git snapshot of current version before we overwrite it
    try:
        import time
        git_snapshot()
    except Exception:
        pass  # git might not be configured; ignore

    # 6. rewrite self with the fresh frame embedded
    write_self(frame)


if __name__ == "__main__":
    main()

# <<< FRAME START >>>
FRAME = """\
"""
# <<< FRAME END >>>