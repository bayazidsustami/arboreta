import Foundation

let pythonCode = """
#!/usr/bin/env python3
import sys, os, termios, tty, threading, time
from PIL import Image
import mido

# Load image and convert to grayscale
img = Image.open('input.png').convert('L')
w, h = img.size
pixels = list(img.getdata())

# Simple mapping: brighter -> more 'F' in axiom
threshold = 128
axiom = ''.join('F' if p > threshold else '' for p in pixels[:100]) or 'F'

# Initial rule set
rules = {'F': 'F+F--F+F'}

# L-system parameters
iterations = 0
max_iter = 4

def lsystem(s, n):
    for _ in range(n):
        s = ''.join(rules.get(ch, ch) for ch in s)
    return s

def render_ascii(s):
    mapping = {'F':'*','+':'/','-':'\\\\'}
    line = ''.join(mapping.get(c, ' ') for c in s)
    size = int(len(line) ** 0.5) + 1
    for i in range(0, len(line), size):
        print(line[i:i+size])
    print("\\n"*2)

def play_midi(s):
    freq = {}
    for ch in s:
        freq[ch] = freq.get(ch,0)+1
    base = 60
    notes = [base + i for i,_ in enumerate(sorted(freq))]
    if not notes: return
    msg_on = mido.Message('note_on', note=notes[0], velocity=64)
    msg_off = mido.Message('note_off', note=notes[0])
    try:
        with mido.open_output() as out:
            out.send(msg_on)
            time.sleep(0.2)
            out.send(msg_off)
    except Exception:
        pass

def input_thread():
    global rules
    while True:
        ch = sys.stdin.read(1)
        if ch == 'q':
            os._exit(0)
        if ch == 'r':
            rules['F'] = rules['F'][::-1]

fd = sys.stdin.fileno()
old = termios.tcgetattr(fd)
tty.setraw(fd)

threading.Thread(target=input_thread, daemon=True).start()

try:
    while True:
        iterStr = lsystem(axiom, iterations)
        os.system('clear')
        print(f'Iteration: {iterations}')
        render_ascii(iterStr)
        play_midi(iterStr)
        iterations = (iterations + 1) % (max_iter + 1)
        time.sleep(0.5)
finally:
    termios.tcsetattr(fd, termios.TCSADRAIN, old)
"""

let fileURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("lsystem.py")
try? pythonCode.write(to: fileURL, atomically: true, encoding: .utf8)
try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fileURL.path)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = ["python3", fileURL.path]
process.standardInput = FileHandle.standardInput
process.standardOutput = FileHandle.standardOutput
process.standardError = FileHandle.standardError

try? process.run()
process.waitUntilExit()