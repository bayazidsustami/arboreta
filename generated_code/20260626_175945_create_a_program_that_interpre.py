import turtle
import sys
import math

# ------------------------------------------------------------
# Simple sentiment derived from raw hex bytes.
# Positive if more high‑nibble bytes (>=8), negative otherwise.
# ------------------------------------------------------------
def sentiment_score(byte_vals):
    high = sum(1 for b in byte_vals if (b >> 4) >= 8)
    low  = len(byte_vals) - high
    return (high - low) / max(1, len(byte_vals))

# ------------------------------------------------------------
# Map sentiment [-1,1] to a colour (HSV -> RGB)
# ------------------------------------------------------------
def sentiment_to_rgb(score):
    # hue: 0 (red) for negative, 120 (green) for positive
    hue = 120 * (score + 1) / 2          # 0..120
    sat = 0.9
    val = 0.9
    h = hue / 60
    i = int(h)
    f = h - i
    p = val * (1 - sat)
    q = val * (1 - sat * f)
    t = val * (1 - sat * (1 - f))
    if i == 0:
        r, g, b = val, t, p
    elif i == 1:
        r, g, b = q, val, p
    else:  # i == 2
        r, g, b = p, val, t
    return r, g, b

# ------------------------------------------------------------
# Decode a line of hex into turtle commands.
# Simple 1‑byte instruction set:
# 0x0-0x3 : forward 20*value
# 0x4-0x7 : left turn 45*value
# 0x8-0xB : right turn 45*value
# 0xC-0xF : change pen size (1+value)
# ------------------------------------------------------------
def execute_commands(t, byte_vals):
    for b in byte_vals:
        opcode = b >> 4
        operand = b & 0x0F
        if opcode <= 0x3:               # forward
            t.forward(20 * (operand + 1))
        elif opcode <= 0x7:               # left
            t.left(45 * (operand + 1))
        elif opcode <= 0xB:               # right
            t.right(45 * (operand + 1))
        else:                             # pen size
            t.pensize(1 + operand)

# ------------------------------------------------------------
# Recursive kaleidoscopic pattern
# ------------------------------------------------------------
def kaleido(t, depth, size, angle):
    if depth == 0:
        return
    for _ in range(6):
        t.forward(size)
        kaleido(t, depth-1, size/3, angle)
        t.backward(size)
        t.right(60)

# ------------------------------------------------------------
# Main driver
# ------------------------------------------------------------
def main():
    # Expect a hex file where each line is a verse (bytes separated by spaces)
    if len(sys.argv) != 2:
        print("Usage: python", sys.argv[0], "poem.hex")
        sys.exit(1)

    hex_lines = []
    with open(sys.argv[1]) as f:
        for ln in f:
            parts = ln.strip().split()
            if not parts:
                continue
            bytes_line = [int(p, 16) for p in parts]
            hex_lines.append(bytes_line)

    screen = turtle.Screen()
    screen.bgcolor("black")
    t = turtle.Turtle()
    t.speed(0)
    t.hideturtle()
    t.up()
    t.goto(0, 0)
    t.down()

    for i, line_bytes in enumerate(hex_lines):
        # sentiment → colour
        score = sentiment_score(line_bytes)
        r, g, b = sentiment_to_rgb(score)
        t.pencolor(r, g, b)

        # reset position for each verse
        t.up()
        t.goto(0, 0)
        t.setheading(0)
        t.down()

        # draw fractal backbone
        kaleido(t, depth=3, size=80, angle=60)

        # execute poetic turtle instructions
        execute_commands(t, line_bytes)

        # slight pause to see evolution
        screen.update()
        turtle.time.sleep(0.8)

    turtle.done()

if __name__ == "__main__":
    main()