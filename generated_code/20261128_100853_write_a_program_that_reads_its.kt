import java.io.File
import java.util.Random
import javax.sound.sampled.AudioFormat
import javax.sound.sampled.AudioSystem
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.pow
import kotlin.math.sin

// Run with: kotlinc -script HauntingLabyrinth.kts (or save as .kts and execute via kotlin)
// Note: Uses a self-contained quine-like reflection fallback if invoked via standard input/compiled JAR.

fun main() {
    val sampleRate = 44100f
    val format = AudioFormat(sampleRate, 16, 1, true, false)
    val line = AudioSystem.getSourceDataLine(format).apply {
        open(format, 4096)
        start()
    }

    // 1. Read own source code (searches local .kt/.kts files or falls back to embedded quine seed)
    val sourceCode = locateOwnSource()

    // 2. Define an eerie D-Minor harmonic / Phrygian dominant scale (MIDI note numbers)
    val scale = listOf(50, 51, 54, 55, 57, 58, 61, 62, 63, 66, 67, 69, 70, 73, 74)
    val minorTriads = setOf(
        setOf(0, 3, 7), // i   (D minor)
        setOf(5, 8, 0), // iv  (G minor)
        setOf(7, 10, 2) // v   (A minor)
    )

    // 3. Initialize a procedural 21x11 Labyrinth
    val cols = 21
    val rows = 11
    val maze = generateLabyrinth(cols, rows)
    val start = Pair(1, 1)
    val goal = Pair(cols - 2, rows - 2)
    var solutionPath = emptyList<Pair<Int, Int>>()

    // Clear terminal and hide cursor
    print("\u001b[2J\u001b[?25l")

    try {
        // Parse non-whitespace tokens of our own code as musical phrases
        val measures = sourceCode.lines()
            .map { it.trim() }
            .filter { it.isNotEmpty() }

        for ((lineIdx, codeLine) in measures.withIndex()) {
            // Map up to 3 significant characters in the line to a 3-note chord
            val notes = codeLine.take(3).padEnd(3, ' ')
                .map { ch -> scale[abs(ch.code) % scale.size] }
                .distinct()

            // Check if the pitch classes form a minor triad
            val pitchClasses = notes.map { (it - 50).mod(12) }.toSet()
            val isMinorChord = notes.size == 3 && minorTriads.any { triad ->
                triad.all { interval -> pitchClasses.contains(interval) }
            }

            // Solve or dissolve the labyrinth path based on harmonic tension
            solutionPath = if (isMinorChord) solveMazeBFS(maze, start, goal) else emptyList()

            // Synthesize 0.38 seconds of haunting FM/additive audio per line of code
            val durationSec = 0.38
            val totalSamples = (sampleRate * durationSec).toInt()
            val buffer = ByteArray(totalSamples * 2)
            val waveformSlice = DoubleArray(cols)

            for (i in 0 until totalSamples) {
                val t = i / sampleRate
                // Slow haunting attack and exponential decay envelope
                val env = (1.0 - exp(-t * 25.0)) * exp(-t * 3.5)
                var sample = 0.0

                for (midi in notes) {
                    val freq = 440.0 * 2.0.pow((midi - 69) / 12.0)
                    // Subtle ghostly vibrato + fifth harmonic overtone
                    val vibrato = sin(2.0 * PI * 5.2 * t) * 1.8
                    val carrier = sin(2.0 * PI * (freq + vibrato) * t)
                    val overtone = 0.25 * sin(2.0 * PI * (freq * 1.5) * t) * exp(-t * 6.0)
                    sample += (carrier + overtone)
                }

                sample = (sample / notes.size) * env * 0.75

                // Capture amplitude envelope points across the measure to warp the labyrinth
                val bucket = (i * cols) / totalSamples
                if (abs(sample) > abs(waveformSlice[bucket])) {
                    waveformSlice[bucket] = sample
                }

                // Convert [-1.0, 1.0] to 16-bit little-endian PCM
                val pcm = (sample.coerceIn(-1.0, 1.0) * Short.MAX_VALUE).toInt().toShort()
                buffer[i * 2] = (pcm.toInt() and 0xFF).toByte()
                buffer[i * 2 + 1] = ((pcm.toInt() shr 8) and 0xFF).toByte()
            }

            // Render the waveform-modulated labyrinth frame in real time
            renderFrame(maze, waveformSlice, solutionPath, isMinorChord, codeLine, lineIdx + 1, measures.size)

            // Stream audio directly to speakers (blocks naturally to sync visuals with sound)
            line.write(buffer, 0, buffer.size)
        }
    } finally {
        line.drain()
        line.close()
        // Restore terminal cursor
        println("\u001b[?25h\u001b[0m")
    }
}

fun locateOwnSource(): String {
    val candidates = File(".").listFiles { _, name -> name.endsWith(".kts") || name.endsWith(".kt") }
    val selfFile = candidates?.firstOrNull { it.readText().contains("locateOwnSource") }
    return selfFile?.readText() ?: """
        fun haunt() {
            val shadow = listOf(50, 53, 57)
            while (true) { echo(shadow) }
        }
    """.trimIndent()
}

// Recursive backtracker maze generator
fun generateLabyrinth(cols: Int, rows: Int): Array<BooleanArray> {
    val grid = Array(rows) { BooleanArray(cols) { true } } // true = wall
    val rng = Random(42)

    fun carve(x: Int, y: Int) {
        grid[y][x] = false
        val dirs = listOf(Pair(0, -2), Pair(2, 0), Pair(0, 2), Pair(-2, 0)).shuffled(rng)
        for ((dx, dy) in dirs) {
            val nx = x + dx
            val ny = y + dy
            if (nx in 1 until cols - 1 && ny in 1 until rows - 1 && grid[ny][nx]) {
                grid[y + dy / 2][x + dx / 2] = false
                carve(nx, ny)
            }
        }
    }

    carve(1, 1)
    return grid
}

// Breadth-First Search to solve the labyrinth when a minor chord strikes
fun solveMazeBFS(maze: Array<BooleanArray>, start: Pair<Int, Int>, goal: Pair<Int, Int>): List<Pair<Int, Int>> {
    val queue = ArrayDeque<Pair<Int, Int>>()
    val cameFrom = mutableMapOf<Pair<Int, Int>, Pair<Int, Int>?>()
    queue.add(start)
    cameFrom[start] = null

    while (queue.isNotEmpty()) {
        val curr = queue.removeFirst()
        if (curr == goal) break
        for ((dx, dy) in listOf(Pair(0, -1), Pair(1, 0), Pair(0, 1), Pair(-1, 0))) {
            val next = Pair(curr.first + dx, curr.second + dy)
            if (next.second in maze.indices && next.first in maze[0].indices &&
                !maze[next.second][next.first] && next !in cameFrom
            ) {
                cameFrom[next] = curr
                queue.add(next)
            }
        }
    }

    val path = mutableListOf<Pair<Int, Int>>()
    var step: Pair<Int, Int>? = goal
    while (step != null && step in cameFrom) {
        path.add(step)
        step = cameFrom[step]
    }
    return path.reversed()
}

// Renders the labyrinth walls sculpted by the live audio waveform amplitude
fun renderFrame(
    maze: Array<BooleanArray>,
    waveform: DoubleArray,
    solution: List<Pair<Int, Int>>,
    isMinor: Boolean,
    codeLine: String,
    current: Int,
    total: Int
) {
    val solutionSet = solution.toSet()
    val midRow = maze.size / 2
    val sb = StringBuilder("\u001b[H") // Move cursor home

    val status = if (isMinor) "\u001b[31m[MINOR CHORD - LABYRINTH SOLVED]\u001b[0m"
                 else "\u001b[36m[DISSONANCE - SEEKING HARMONY]\u001b[0m"
    sb.append("Measure $current/$total $status\n")
    sb.append("Score: \u001b[33m${codeLine.take(44).padEnd(44)}\u001b[0m\n\n")

    for (y in maze.indices) {
        for (x in maze[y].indices) {
            val ampOffset = (waveform[x] * (maze.size / 2.2)).toInt()
            val waveRow = (midRow + ampOffset).coerceIn(0, maze.lastIndex)
            val pos = Pair(x, y)

            when {
                pos in solutionSet -> sb.append("\u001b[1;31m◆ \u001b[0m") // Glowing crimson solution thread
                maze[y][x] -> {
                    // Walls vibrate with different blocks based on proximity to waveform peak
                    val wallGlyph = if (abs(y - waveRow) <= 1) "\u001b[35m▓▒\u001b[0m" else "\u001b[90m██\u001b[0m"
                    sb.append(wallGlyph)
                }
                y == waveRow -> sb.append("\u001b[36m≈≈\u001b[0m") // Live waveform flowing through corridors
                else -> sb.append("  ")
            }
        }
        sb.append("\n")
    }
    print(sb.toString())
}

main()