#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* This C program writes a self‑modifying Python script (mandel.py).
 * The generated Python script:
 *   - draws an animated Mandelbrot set as ASCII art,
 *   - colors each character using 24‑bit ANSI colors derived from its own source code,
 *   - thus any captured frame can be decoded back to the exact script that produced it.
 */

static const char *python_template =
"import sys, os, time, math\n"
"src = open(__file__).read().encode('utf‑8')\n"
"w, h = 80, 40                       # terminal size\n"
"max_iter = 80\n"
"def mandelbrot(cx, cy):\n"
"    x = y = 0.0\n"
"    for i in range(max_iter):\n"
"        x2, y2 = x*x, y*y\n"
"        if x2 + y2 > 4.0:\n"
"            return i\n"
"        y = 2*x*y + cy\n"
"        x = x2 - y2 + cx\n"
"    return max_iter\n"
"def color_from_byte(b):\n"
"    # map a byte to an RGB value (simple gradient)\n"
"    r = (b & 0xE0)      # high 3 bits\n"
"    g = (b & 0x1C) << 3 # middle 3 bits\n"
"    b = (b & 0x03) << 6 # low 2 bits expanded\n"
"    return f\"\\x1b[38;2;{r};{g};{b}m\"\n"
"def frame(t):\n"
"    out = []\n"
"    for y in range(h):\n"
"        line = []\n"
"        for x in range(w):\n"
"            # map screen to complex plane, zooming with time\n"
"            zx = (x - w/2) / (w/4) * (1.5 - 0.5*math.cos(t/10))\n"
"            zy = (y - h/2) / (h/4) * (1.5 - 0.5*math.cos(t/10))\n"
"            n = mandelbrot(zx, zy)\n"
"            ch = ' .:-=+*#%@'[n * 10 // max_iter]\n"
"            # pick a byte from src based on position and time\n"
"            idx = (x + y*w + int(t)) % len(src)\n"
"            line.append(color_from_byte(src[idx]) + ch)\n"
"        out.append(''.join(line) + '\\x1b[0m')\n"
"    return '\\n'.join(out)\n"
"def main():\n"
"    t = 0\n"
"    try:\n"
"        while True:\n"
"            os.system('clear')\n"
"            sys.stdout.write(frame(t))\n"
"            sys.stdout.flush()\n"
"            t += 1\n"
"            time.sleep(0.05)\n"
"    except KeyboardInterrupt:\n"
"        pass\n"
"if __name__ == '__main__':\n"
"    main()\n";

int main(void) {
    FILE *fp = fopen("mandel.py", "w");
    if (!fp) {
        perror("fopen");
        return 1;
    }
    fputs(python_template, fp);
    fclose(fp);
    printf("Python script 'mandel.py' generated.\n");
    return 0;
}