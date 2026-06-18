import java.io.File
import java.util.Locale

// Simple sentiment word lists
val positive = setOf("love", "joy", "bright", "happy", "sweet", "beauty", "delight", "glad", "cheer", "hope")
val negative = setOf("death", "dark", "sorrow", "pain", "grief", "lonely", "sad", "cry", "woe", "fear")

// Map a line to a valence color (HSV -> RGB)
fun lineColor(line: String): Int {
    var score = 0
    line.lowercase(Locale.getDefault()).split(Regex("\\W+")).forEach {
        when {
            positive.contains(it) -> score += 1
            negative.contains(it) -> score -= 1
        }
    }
    // Map score (-5..5) to hue 240 (blue) .. 0 (red)
    val hue = ((5 - score) * 24).coerceIn(0, 240) // 0 = red, 240 = blue
    return hsvToRgb(hue.toFloat(), 0.7f, 0.9f)
}

// Convert HSV to packed RGB int
fun hsvToRgb(h: Float, s: Float, v: Float): Int {
    val c = v * s
    val x = c * (1 - kotlin.math.abs((h / 60) % 2 - 1))
    val m = v - c
    val (r1, g1, b1) = when {
        h < 60 -> Triple(c, x, 0f)
        h < 120 -> Triple(x, c, 0f)
        h < 180 -> Triple(0f, c, x)
        h < 240 -> Triple(0f, x, c)
        h < 300 -> Triple(x, 0f, c)
        else -> Triple(c, 0f, x)
    }
    val r = ((r1 + m) * 255).toInt()
    val g = ((g1 + m) * 255).toInt()
    val b = ((b1 + m) * 255).toInt()
    return (r shl 16) or (g shl 8) or b
}

// Render a single generation as SVG
fun renderSvg(cells: BooleanArray, baseColor: Int, cellSize: Int, filename: String) {
    val sb = StringBuilder()
    sb.append("""<svg xmlns="http://www.w3.org/2000/svg" width="${cells.size * cellSize}" height="$cellSize">""")
    for (i in cells.indices) {
        if (cells[i]) {
            val r = (baseColor shr 16) and 0xFF
            val g = (baseColor shr 8) and 0xFF
            val b = baseColor and 0xFF
            sb.append("""<rect x="${i * cellSize}" y="0" width="$cellSize" height="$cellSize" fill="rgb($r,$g,$b)"/>""")
        }
    }
    sb.append("</svg>")
    File(filename).writeText(sb.toString())
}

// Elementary cellular automaton rule 30
fun nextGen(prev: BooleanArray): BooleanArray {
    val n = prev.size
    val next = BooleanArray(n)
    for (i in 0 until n) {
        val left = if (i == 0) false else prev[i-1]
        val center = prev[i]
        val right = if (i == n-1) false else prev[i+1]
        // rule 30 binary: 00011110 => mapping
        val index = (if (left) 4 else 0) + (if (center) 2 else 0) + (if (right) 1 else 0)
        next[i] = when (index) {
            0,1,2,4,7 -> false
            else -> true // indexes 3,5,6
        }
    }
    return next
}

// Main script
fun main() {
    // Read whole stdin as poem
    val poem = generateSequence(::readLine).joinToString("\n")
    val lines = poem.trim().lines().filter { it.isNotBlank() }

    // Determine width: longest line in words
    val width = lines.maxOf { it.split(Regex("\\s+")).size }

    // Prepare initial CA state (single true in middle)
    var cells = BooleanArray(width) { false }
    cells[width/2] = true

    val cellSize = 20
    val frames = 120   // total frames for loop
    val outDir = File("frames")
    outDir.mkdirs()

    // Precompute colors per line (cycling if fewer lines than frames)
    val colors = List(frames) { idx -> lineColor(lines[idx % lines.size]) }

    // Generate frames
    for (frame in 0 until frames) {
        renderSvg(cells, colors[frame], cellSize, "${outDir.path}/frame_${frame.toString().padStart(3,'0')}.svg")
        cells = nextGen(cells)
    }

    // Simple index SVG to loop them (optional)
    val indexSb = StringBuilder()
    indexSb.append("""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width*cellSize} $cellSize">""")
    indexSb.append("""<image href="${outDir.listFiles().sortedBy { it.name }[0].name}" width="${width*cellSize}" height="$cellSize">""")
    indexSb.append("""</image></svg>""")
    File("animation.svg").writeText(indexSb.toString())
}

// Run
main()