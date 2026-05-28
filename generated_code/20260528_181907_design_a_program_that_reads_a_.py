import cv2
import numpy as np
import threading, queue, time, math, sys
import speech_recognition as sr
from textblob import TextBlob
import pygame

# ---------- Configuration ----------
# map sentiment polarity (-1..1) to color (blue..red) and musical note (C4..C6)
def sentiment_to_color(p):
    # blue (sad) to red (happy)
    r = int(255 * (p + 1) / 2)
    b = 255 - r
    return (r, 0, b)

def sentiment_to_freq(p):
    # C4=261.63Hz, C6=1046.50Hz
    low, high = 261.63, 1046.50
    return low + (p + 1) / 2 * (high - low)

# simple synth: generate a sine wave chunk
def synth_wave(freq, duration=0.2, sr=44100):
    t = np.linspace(0, duration, int(sr*duration), False)
    wave = 0.2*np.sin(2*np.pi*freq*t)
    return (wave * 32767).astype(np.int16)

# ---------- Audio Capture & Processing ----------
audio_q = queue.Queue()

def listen_loop():
    r = sr.Recognizer()
    mic = sr.Microphone()
    with mic as source:
        r.adjust_for_ambient_noise(source)
    while True:
        try:
            with mic as source:
                audio = r.listen(source, phrase_time_limit=3)
            # use Google free API (requires internet)
            txt = r.recognize_google(audio)
            audio_q.put(txt)
        except Exception as e:
            pass  # ignore errors and continue

listener = threading.Thread(target=listen_loop, daemon=True)
listener.start()

# ---------- Visualization ----------
pygame.init()
WIDTH, HEIGHT = 800, 600
screen = pygame.display.set_mode((WIDTH, HEIGHT))
clock = pygame.time.Clock()

# state for geometry
angle = 0.0
radius = 50
color = (255, 255, 255)
freq = 440.0
last_play = 0.0

def play_tone(f):
    global last_play
    now = time.time()
    if now - last_play < 0.1:  # limit spamming
        return
    last_play = now
    sound = pygame.sndarray.make_sound(synth_wave(f))
    sound.play()

running = True
while running:
    for ev in pygame.event.get():
        if ev.type == pygame.QUIT:
            running = False

    # grab webcam frame (visual background)
    ret, frame = cv2.VideoCapture(0).read()
    if ret:
        frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        frame = cv2.resize(frame, (WIDTH, HEIGHT))
        bg = pygame.surfarray.make_surface(frame).convert()
        screen.blit(bg, (0,0))
    else:
        screen.fill((0,0,0))

    # process any new spoken text
    try:
        while True:
            txt = audio_q.get_nowait()
            blob = TextBlob(txt)
            polarity = max(-1.0, min(1.0, blob.sentiment.polarity))
            color = sentiment_to_color(polarity)
            freq = sentiment_to_freq(polarity)
            play_tone(freq)
    except queue.Empty:
        pass

    # generate generative art responsive to freq & color
    # geometry rotates faster with higher pitch
    angle += (freq - 261.63) / 200.0
    radius = 30 + 20 * math.sin(pygame.time.get_ticks()*0.005)

    # draw rotating polygon
    pts = []
    n = 5
    for i in range(n):
        th = angle + 2*math.pi*i/n
        x = WIDTH//2 + radius*math.cos(th)
        y = HEIGHT//2 + radius*math.sin(th)
        pts.append((x,y))
    pygame.draw.polygon(screen, color, pts, 3)

    pygame.display.flip()
    clock.tick(30)

pygame.quit()
cv2.destroyAllWindows()
```