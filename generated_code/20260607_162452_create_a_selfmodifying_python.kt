import java.io.File
import java.nio.file.Files
import java.nio.file.StandardOpenOption

// Kotlin script that generates a self‑modifying Python script.
// The generated Python script reads its own source as a bitmap,
// applies a simple cellular‑automaton filter, rewrites itself,
// and prints a short poem derived from the new visual patterns.

fun main() {
    // Python source template – placeholders will be replaced by Kotlin.
    val pythonTemplate = """
        #!/usr/bin/env python3
        import sys, os

        # ----- CONFIGURATION -----
        WIDTH = 80        # characters per line (bitmap width)
        THRESH = 4        # neighbor count threshold for "alive" cells
        POEM = [
            "Whispers in code,",
            "bits dance on the screen,",
            "silence becomes line,",
            "life in a loop unseen."
        ]

        # ----- READ OWN SOURCE AS BITMAP -----
        with open(__file__, 'r', encoding='utf-8') as f:
            src = f.readlines()
        # pad lines to the same length
        max_len = max(len(line.rstrip('\n')) for line in src)
        bitmap = [[1 if ch!=' ' and ch!='\n' else 0 for ch in line.rstrip('\n').ljust(max_len)] for line in src]

        H, W = len(bitmap), max_len

        # ----- CELLULAR AUTOMATON STEP -----
        def step(grid):
            new = [[0]*W for _ in range(H)]
            for y in range(H):
                for x in range(W):
                    cnt = 0
                    for dy in (-1,0,1):
                        for dx in (-1,0,1):
                            if dy==0 and dx==0: continue
                            ny, nx = y+dy, x+dx
                            if 0<=ny<H and 0<=nx<W:
                                cnt += grid[ny][nx]
                    new[y][x] = 1 if cnt>=THRESH else 0
            return new

        new_bitmap = step(bitmap)

        # ----- REWRITE SELF WITH NEW GLYPHS -----
        def glyph(val):
            return '#' if val else ' '
        new_lines = [''.join(glyph(c) for c in row)+'\n' for row in new_bitmap]
        with open(__file__, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)

        # ----- DERIVE POEM FROM PATTERN -----
        # Simple rule: count alive cells per line and pick verse modulo length.
        counts = [sum(row) for row in new_bitmap]
        for i, cnt in enumerate(counts[:len(POEM)]):
            print(POEM[i % len(POEM)])

        # End of generated script
    """.trimIndent()

    // Write the Python script to a temporary file
    val pyFile = Files.createTempFile("self_mod", ".py")
    Files.writeString(pyFile, pythonTemplate, StandardOpenOption.WRITE)

    // Make it executable (Unix-like systems)
    try {
        val chmod = ProcessBuilder("chmod", "+x", pyFile.toString()).inheritIO().start()
        chmod.waitFor()
    } catch (e: Exception) {
        // ignore on non‑POSIX platforms
    }

    // Run the generated Python script
    val proc = ProcessBuilder("python3", pyFile.toString())
        .inheritIO()
        .start()
    proc.waitFor()
    
    // Clean up: optionally delete the script after execution
    // Files.deleteIfExists(pyFile)
}