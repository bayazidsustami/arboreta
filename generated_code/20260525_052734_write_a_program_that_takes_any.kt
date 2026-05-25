import java.io.File
import kotlin.math.*

// Simple data class for a cell in the automaton
data class Cell(
    var word: String,
    var pos: String,          // part of speech
    var length: Int,          // phonetic length approximation
    var sentiment: Int,       // -1 negative, 0 neutral, 1 positive
    var color: String,        // current color in hex
    var nextColor: String = "" // placeholder for next iteration
)

// Very naive sentiment analyzer
val positiveWords = setOf("good", "happy", "joy", "love", "excellent", "nice", "great", "wonderful")
val negativeWords = setOf("bad", "sad", "pain", "hate", "terrible", "awful", "poor", "angry")

// Very naive POS tagger
fun guessPos(word: String): String = when {
    word.endsWith("ly") -> "adv"
    word.endsWith("ing") || word.endsWith("ed") -> "verb"
    word.endsWith("ous") || word.endsWith("ful") -> "adj"
    else -> "noun"
}

// Map sentiment to a base hue
fun sentimentHue(sentiment: Int): Float = when (sentiment) {
    1 -> 120f   // green for positive
    -1 -> 0f    // red for negative
    else -> 60f // yellow for neutral
}

// Convert HSV to HEX (s and v are fixed for vivid colors)
fun hsvToHex(h: Float, s: Float = 0.7f, v: Float = 0.9f): String {
    val c = v * s
    val x = c * (1 - abs((h / 60) % 2 - 1))
    val m = v - c
    val (r1, g1, b1) = when {
        h < 60 -> Triple(c, x, 0f)
        h < 120 -> Triple(x, c, 0f)
        h < 180 -> Triple(0f, c, x)
        h < 240 -> Triple(0f, x, c)
        h < 300 -> Triple(x, 0f, c)
        else -> Triple(c, 0f, x)
    }
    val r = ((r1 + m) * 255).roundToInt()
    val g = ((g1 + m) * 255).roundToInt()
    val b = ((b1 + m) * 255).roundToInt()
    return "#%02X%02X%02X".format(r, g, b)
}

// Generate initial grid from words
fun buildGrid(words: List<String>): List<List<Cell>> {
    val n = ceil(sqrt(words.size.toDouble())).toInt()
    val padded = words + List(n * n - words.size) { "" }
    val cells = padded.map { w ->
        val clean = w.filter { it.isLetterOrDigit() }.lowercase()
        val pos = if (clean.isEmpty()) "none" else guessPos(clean)
        val sentiment = when {
            positiveWords.contains(clean) -> 1
            negativeWords.contains(clean) -> -1
            else -> 0
        }
        val hue = sentimentHue(sentiment)
        Cell(
            word = clean,
            pos = pos,
            length = clean.length.coerceAtLeast(1),
            sentiment = sentiment,
            color = hsvToHex(hue)
        )
    }
    return cells.chunked(n)
}

// One automaton step: average neighbor hues
fun step(grid: List<List<Cell>>): List<List<Cell>> {
    val rows = grid.size
    val cols = grid[0].size
    val dirs = listOf(-1 to 0, 1 to 0, 0 to -1, 0 to 1)
    for (r in 0 until rows) {
        for (c in 0 until cols) {
            val cell = grid[r][c]
            var sumHue = 0f
            var count = 0
            for ((dr, dc) in dirs) {
                val nr = r + dr
                val nc = c + dc
                if (nr in 0 until rows && nc in 0 until cols) {
                    val neigh = grid[nr][nc]
                    val hue = sentimentHue(neigh.sentiment)
                    sumHue += hue
                    count++
                }
            }
            val avgHue = if (count > 0) sumHue / count else sentimentHue(cell.sentiment)
            cell.nextColor = hsvToHex(avgHue)
        }
    }
    // commit new colors
    for (row in grid) for (cell in row) cell.color = cell.nextColor
    return grid
}

// Render grid to SVG
fun renderSvg(grid: List<List<Cell>>, cellSize: Int = 40): String {
    val rows = grid.size
    val cols = grid[0].size
    val width = cols * cellSize
    val height = rows * cellSize
    val sb = StringBuilder()
    sb.append("""<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height">""")
    for (r in 0 until rows) {
        for (c in 0 until cols) {
            val cell = grid[r][c]
            val cx = c * cellSize + cellSize / 2
            val cy = r * cellSize + cellSize / 2
            val radius = (cell.length.coerceAtMost(cellSize / 2)).toFloat()
            val shape = when (cell.pos) {
                "verb" -> "rect"
                "adj" -> "ellipse"
                "adv" -> "polygon"
                "noun" -> "circle"
                else -> "circle"
            }
            when (shape) {
                "circle" -> sb.append("""<circle cx="$cx" cy="$cy" r="${radius}" fill="${cell.color}" />""")
                "rect" -> sb.append("""<rect x="${cx - radius}" y="${cy - radius}" width="${radius * 2}" height="${radius * 2}" fill="${cell.color}" />""")
                "ellipse" -> sb.append("""<ellipse cx="$cx" cy="$cy" rx="${radius}" ry="${radius/2}" fill="${cell.color}" />""")
                "polygon" -> {
                    val p = listOf(
                        "$cx,${cy - radius}",
                        "${cx - radius},${cy + radius}",
                        "${cx + radius},${cy + radius}"
                    ).joinToString(" ")
                    sb.append("""<polygon points="$p" fill="${cell.color}" />""")
                }
            }
        }
    }
    sb.append("</svg>")
    return sb.toString()
}

// Main entry point
fun main() {
    // read entire stdin as text
    val text = generateSequence(::readLine).joinToString(" ")
    val words = text.split(Regex("\\s+")).filter { it.isNotBlank() }

    if (words.isEmpty()) {
        println("No input text provided.")
        return
    }

    var grid = buildGrid(words)

    // run a few automaton iterations to evolve colors
    repeat(5) { grid = step(grid) }

    val svg = renderSvg(grid)

    // write to file
    File("poem.svg").writeText(svg)
    println("SVG written to poem.svg")
}