import sys, threading, math, time, re, collections
from tkinter import Tk, Text, END, INSERT
import pygame
from pygame import gfxdraw

# ---------- Text analysis ----------
def simple_stress(word):
    """Very rough stress: odd letters vowel -> stressed (1), else 0"""
    vowels = "aeiouy"
    return [1 if (i%2==0 and ch.lower() in vowels) else 0 for i,ch in enumerate(word)]

def analyze(text):
    lines = text.splitlines()
    feet = []           # list of stress patterns per foot (2 syl)
    word_counts = collections.Counter(re.findall(r"\b\w+\b", text.lower()))
    total_words = sum(word_counts.values()) or 1

    for line in lines:
        words = re.findall(r"\b\w+\b", line)
        syls = []
        for w in words:
            syls.extend(simple_stress(w))
        # group into feet of 2 syllables
        for i in range(0, len(syls), 2):
            foot = tuple(syls[i:i+2])
            if len(foot)==2:
                feet.append(foot)
    # map each distinct foot to a hue
    distinct = list(dict.fromkeys(feet))
    foot_hues = {f:i/len(distinct) for i,f in enumerate(distinct)} if distinct else {}
    return {
        "feet":feet,
        "foot_hues":foot_hues,
        "word_freq":{w:c/total_words for w,c in word_counts.items()}
    }

# ---------- Visualization ----------
class Mandala:
    def __init__(self, width=800, height=800):
        pygame.init()
        self.screen = pygame.display.set_mode((width,height))
        self.clock = pygame.time.Clock()
        self.width, self.height = width, height
        self.center = (width//2, height//2)
        self.data = {"feet":[],"foot_hues":{},"word_freq":{}}
        self.running = True

    def update_data(self, data):
        self.data = data

    def draw_petal(self, angle, hue, size, speed):
        # hue -> rgb
        r,g,b = pygame.Color(0)
        col = pygame.Color(0)
        col.hsva = (hue*360, 80, 100, 100)
        points = []
        steps = 20
        for i in range(steps+1):
            a = math.radians(angle + i*360/steps)
            rad = size * (0.5+0.5*math.sin(speed*i))
            x = self.center[0] + rad*math.cos(a)
            y = self.center[1] + rad*math.sin(a)
            points.append((x,y))
        gfxdraw.filled_polygon(self.screen, points, col)

    def run(self):
        t0 = time.time()
        while self.running:
            for e in pygame.event.get():
                if e.type==pygame.QUIT:
                    self.running=False
            self.screen.fill((10,10,30))
            feet = self.data["feet"]
            hues = self.data["foot_hues"]
            if feet:
                for i,foot in enumerate(feet):
                    hue = hues.get(foot,0.0)
                    angle = (i*15)%360
                    size = 100+50*math.sin(time.time()*2+ i)
                    speed = 0.3+0.2*foot[0]
                    self.draw_petal(angle, hue, size, speed)
            pygame.display.flip()
            self.clock.tick(30)
        pygame.quit()

# ---------- GUI ----------
def start_gui(mandala):
    root = Tk()
    root.title("Poem editor")
    txt = Text(root, width=60, height=20, font=("Helvetica",14))
    txt.pack()
    txt.insert(INSERT, "Enter your poem here...\n")
    def on_key(event=None):
        s = txt.get("1.0", END)
        data = analyze(s)
        mandala.update_data(data)
    txt.bind("<KeyRelease>", on_key)
    root.protocol("WM_DELETE_WINDOW", lambda: (mandala.running=False, root.destroy()))
    root.mainloop()

if __name__=="__main__":
    mand = Mandala()
    thr = threading.Thread(target=mand.run, daemon=True)
    thr.start()
    start_gui(mand)
    thr.join()