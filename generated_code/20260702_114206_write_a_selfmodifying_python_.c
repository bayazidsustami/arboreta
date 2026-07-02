#include <stdio.h>
#include <stdlib.h>

int main(void) {
    const char *python_code =
        "#!/usr/bin/env python3\n"
        "\"\"\"\n"
        "Self‑modifying script: extracts string literals, runs a tiny L‑system, and stores\n"
        "the resulting SVG path data back as a multi‑line comment.\n"
        "\"\"\"\n"
        "import re, math, pathlib, sys\n"
        "\n"
        "def extract_strings(src):\n"
        "    # Find all single‑ or double‑quoted literals (non‑greedy)\n"
        "    return [m[0] or m[1] for m in re.findall(r'(?<!\\\\)\"(.*?)(?<!\\\\)\"|\\'(.*?)(?<!\\\\)\\'', src)]\n"
        "\n"
        "def lsystem(s, iters=2):\n"
        "    rules = {'F':'F+F-F-F+F'}\n"
        "    out = s\n"
        "    for _ in range(iters):\n"
        "        out = ''.join(rules.get(ch, ch) for ch in out)\n"
        "    return out\n"
        "\n"
        "def to_svg(seq, step=10):\n"
        "    x = y = 0.0\n"
        "    angle = 0.0  # degrees, 0 = east\n"
        "    points = [(x, y)]\n"
        "    for cmd in seq:\n"
        "        if cmd == 'F':\n"
        "            rad = math.radians(angle)\n"
        "            x += step * math.cos(rad)\n"
        "            y += step * math.sin(rad)\n"
        "            points.append((x, y))\n"
        "        elif cmd == '+':\n"
        "            angle += 90\n"
        "        elif cmd == '-':\n"
        "            angle -= 90\n"
        "    # Build SVG path data\n"
        "    d = f\"M {points[0][0]:.2f} {points[0][1]:.2f} \"\n"
        "    d += ' '.join(f\"L {px:.2f} {py:.2f}\" for px, py in points[1:])\n"
        "    return d\n"
        "\n"
        "def main():\n"
        "    src_path = pathlib.Path(__file__)\n"
        "    src = src_path.read_text(encoding='utf-8')\n"
        "    strs = extract_strings(src)\n"
        "    # Run L‑system on each extracted literal and concatenate results\n"
        "    seq = ''.join(lsystem(s) for s in strs)\n"
        "    path_data = to_svg(seq)\n"
        "    # Replace the first triple‑quoted comment with the new SVG data\n"
        "    new_src = re.sub(r'(?s)\\\"\\\"\\\".*?\\\"\\\"\\\"', f'\"\"\"\\n{path_data}\\n\"\"\"', src, count=1)\n"
        "    src_path.write_text(new_src, encoding='utf-8')\n"
        "\n"
        "if __name__ == '__main__':\n"
        "    main()\n"
        "# NOTE: The SVG path will appear inside the triple‑quoted comment above after each run.\n";

    FILE *f = fopen("selfmod.py", "w");
    if (!f) {
        perror("fopen");
        return 1;
    }
    fputs(python_code, f);
    fclose(f);
    // Make the script executable (optional on POSIX)
    if (system("chmod +x selfmod.py") != 0) {
        perror("chmod");
    }
    // Run the generated script once to demonstrate self‑modification
    if (system("./selfmod.py") != 0) {
        perror("execute selfmod.py");
    }
    return 0;
}