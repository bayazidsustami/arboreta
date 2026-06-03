import java.io.File
import java.nio.file.Files
import java.nio.file.StandardOpenOption

fun main() {
    // Python script that self‑modifies, interprets its source as turtle commands, and outputs an SVG.
    val python = """
        #!/usr/bin/env python3
        import sys, random, math, pathlib

        # -------- Configuration --------
        STEP = 10                       # forward step size
        ANGLE = 90                      # turn angle in degrees
        THICKNESS_STEP = 0.5            # pen thickness increment
        HUE_STEP = 30                   # hue change per '-' command
        MUTATE_PROB = 0.02              # probability to mutate a cell
        COMMANDS = "FLR+-"              # possible commands
        # --------------------------------

        # Read own source as 2‑D grid
        src_path = pathlib.Path(__file__)
        lines = src_path.read_text().splitlines()
        grid = [list(line) for line in lines]

        # Turtle state
        x, y = 0.0, 0.0
        angle = 0.0                     # 0 = east
        thickness = 1.0
        hue = 0

        # SVG header
        min_x = max_x = x
        min_y = max_y = y
        path_cmds = []

        def forward():
            global x, y, min_x, max_x, min_y, max_y
            rad = math.radians(angle)
            nx = x + STEP * math.cos(rad)
            ny = y + STEP * math.sin(rad)
            path_cmds.append(f"M{x:.2f},{y:.2f} L{nx:.2f},{ny:.2f}")
            x, y = nx, ny
            min_x, max_x = min(min_x, x), max(max_x, x)
            min_y, max_y = min(min_y, y), max(max_y, y)

        # Interpret grid
        for row in grid:
            for ch in row:
                if ch == 'F':
                    forward()
                elif ch == 'L':
                    angle = (angle + ANGLE) % 360
                elif ch == 'R':
                    angle = (angle - ANGLE) % 360
                elif ch == '+':
                    thickness += THICKNESS_STEP
                elif ch == '-':
                    hue = (hue + HUE_STEP) % 360

                # Stochastic mutation
                if random.random() < MUTATE_PROB:
                    row[row.index(ch)] = random.choice(COMMANDS)

        # Build SVG
        pad = 20
        width = max_x - min_x + 2 * pad
        height = max_y - min_y + 2 * pad
        offset_x = -min_x + pad
        offset_y = -min_y + pad

        def hue_to_rgb(h):
            c = 0.5
            x = c * (1 - abs((h/60)%2 - 1))
            if h < 60:   r,g,b = c,x,0
            elif h <120: r,g,b = x,c,0
            elif h <180: r,g,b = 0,c,x
            elif h <240: r,g,b = 0,x,c
            elif h <300: r,g,b = x,0,c
            else:        r,g,b = c,0,x
            return f"rgb({int(r*255)},{int(g*255)},{int(b*255)})"

        svg_parts = [
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
            f'<rect width="100%" height="100%" fill="white"/>'
        ]

        # Draw turtle paths
        for cmd in path_cmds:
            svg_parts.append(
                f'<path d="{cmd}" stroke="{hue_to_rgb(hue)}" stroke-width="{thickness}" fill="none"/>'
            )

        # Render transformed source as text painting
        text_y = pad
        for line in grid:
            txt = "".join(line)
            svg_parts.append(
                f'<text x="{pad}" y="{text_y}" font-family="monospace" font-size="8" fill="black">{txt}</text>'
            )
            text_y += 10

        svg_parts.append('</svg>')

        # Write SVG
        out_svg = src_path.with_suffix('.svg')
        out_svg.write_text("\n".join(svg_parts))

        # Overwrite source with mutated version
        new_source = "\n".join("".join(row) for row in grid)
        src_path.write_text(new_source)

        print(f"Generated {out_svg.name} and updated source.")
        """.trimIndent()

    // Write the Python script to a file
    val pyFile = File("self_modifying.py")
    Files.writeString(pyFile.toPath(), python, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING)
    pyFile.setExecutable(true)

    // Optionally execute the script
    try {
        val process = ProcessBuilder("python3", pyFile.absolutePath)
            .inheritIO()
            .start()
        process.waitFor()
    } catch (e: Exception) {
        System.err.println("Failed to run the generated Python script: ${e.message}")
    }
}