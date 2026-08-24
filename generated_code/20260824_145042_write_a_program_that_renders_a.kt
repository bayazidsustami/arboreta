import java.io.File
import kotlin.math.abs
import kotlin.math.sin
import kotlin.math.cos

// Represents a star derived directly from a node/token in the source AST
data class ASTStar(
    val symbol: Char,
    val xRatio: Double,
    val yRatio: Double,
    val brightnessBase: Double,
    val twinkleFrequency: Double,
    val twinklePhase: Double,
    val nodeType: String
)

// Main generative visualizer using raw terminal ANSI control
fun main() {
    // 1. Inspect own running source code to build the AST representation
    val sourceFile = File("Constellation.kt")
    val sourceCode = if (sourceFile.exists()) {
        sourceFile.readText()
    } else {
        // Fallback self-contained source representation if running directly from memory/script
        """
        fun main() {
            val source = "generative_ast_constellation"
            val stars = source.map { it.code }
            println(stars)
        }
        """.trimIndent()
    }

    // Parse source code tokens into AST-derived stars
    val stars = parseSourceToASTStars(sourceCode)

    // Hide terminal cursor & clear screen
    print("\u001B[?25l\u001B[2J")

    // Restore terminal cursor cleanly on process termination
    Runtime.getRuntime().addShutdownHook(Thread {
        print("\u001B[?25h\u001B[0m\u001B[2J\u001B[1;1H")
    })

    val chars = charArrayOf('.', '·', '*', '°', '+', 'o', 'O', '✦', '✧', '★')
    var frame = 0.0

    // Render loop
    while (true) {
        val width = 80
        val height = 24
        val grid = Array(height) { CharArray(width) { ' ' } }
        val colorGrid = Array(height) { IntArray(width) { 90 } } // Default dark gray

        // Draw astronomical reference grid (declination lines)
        for (y in 0 until height step 4) {
            for (x in 0 until width step 2) {
                grid[y][x] = '·'
                colorGrid[y][x] = 234 // Dim ambient grid
            }
        }

        // Draw constellation lines between structurally connected AST nodes
        for (i in 0 until stars.size - 1) {
            val s1 = stars[i]
            val s2 = stars[i + 1]
            // Connect nodes that share syntactic proximity or structural hierarchy
            if (s1.nodeType == s2.nodeType || abs(i - (i + 1)) == 1) {
                val x1 = (s1.xRatio * (width - 1)).toInt()
                val y1 = (s1.yRatio * (height - 1)).toInt()
                val x2 = (s2.xRatio * (width - 1)).toInt()
                val y2 = (s2.yRatio * (height - 1)).toInt()
                drawLine(x1, y1, x2, y2, grid, colorGrid, width, height)
            }
        }

        // Render stars with real-time mathematical twinkling
        for (star in stars) {
            val x = (star.xRatio * (width - 1)).toInt().coerceIn(0, width - 1)
            val y = (star.yRatio * (height - 1)).toInt().coerceIn(0, height - 1)

            // Dynamic sine-wave brightness modulation based on AST parameters
            val twinkle = sin(frame * star.twinkleFrequency + star.twinklePhase)
            val currentBrightness = (star.brightnessBase + twinkle * 0.4).coerceIn(0.0, 1.0)

            val charIdx = (currentBrightness * (chars.size - 1)).toInt()
            grid[y][x] = chars[charIdx]

            // Color coding derived from AST Node Type
            colorGrid[y][x] = when (star.nodeType) {
                "KEYWORD" -> 93   // Bright Magenta
                "IDENTIFIER" -> 96// Bright Cyan
                "LITERAL" -> 93   // Bright Yellow
                "OPERATOR" -> 92  // Bright Green
                else -> 97        // Bright White
            }
        }

        // Render frame to terminal using ANSI buffering
        val sb = StringBuilder("\u001B[H")
        sb.append("═══ AST LIVE CONSTELLATION MAP ═══ [Nodes: ${stars.size}] ════════════════════════\n")
        for (y in 0 until height) {
            for (x in 0 until width) {
                val col = colorGrid[y][x]
                val ch = grid[y][x]
                if (col > 200) {
                    sb.append("\u001B[38;5;${col}m$ch")
                } else {
                    sb.append("\u001B[${col}m$ch")
                }
            }
            sb.append("\u001B[0m\n")
        }
        sb.append("════════════════════════════════════════════════════════════════════════════════")
        print(sb.toString())

        Thread.sleep(50)
        frame += 0.1
    }
}

// Tokenizes source code into AST-like lexical structures and projects them into celestial space
fun parseSourceToASTStars(code: String): List<ASTStar> {
    val tokens = code.split(Regex("\\s+|(?<=[(){}\\[\\],;=+-/*])|(?=[(){}\\[\\],;=+-/*])")).filter { it.isNotBlank() }
    val stars = mutableListOf<ASTStar>()

    val keywords = setOf("fun", "val", "var", "import", "class", "data", "for", "while", "if", "else", "when", "return")
    val operators = setOf("=", "+", "-", "*", "/", "==", "!=", "&&", "||", "->", ":")

    for ((index, token) in tokens.withIndex()) {
        val nodeType = when {
            token in keywords -> "KEYWORD"
            token in operators -> "OPERATOR"
            token.toIntOrNull() != null || token.startsWith("\"") -> "LITERAL"
            token.firstOrNull()?.isLetter() == true -> "IDENTIFIER"
            else -> "PUNCTUATION"
        }

        // Deterministic hash functions derived from node content & syntax tree position
        val hash = (token.hashCode() xor (index * 31))
        val normHash = abs(hash) / Int.MAX_VALUE.toDouble()

        // Polar mapping algorithm based on AST sequence depth
        val angle = index * 137.5 * (Math.PI / 180.0) // Golden ratio angle dispersion
        val radius = 0.1 + 0.8 * (index.toDouble() / tokens.size)

        val xRatio = (0.5 + radius * cos(angle) * 0.5).coerceIn(0.05, 0.95)
        val yRatio = (0.5 + radius * sin(angle) * 0.5).coerceIn(0.05, 0.95)

        val brightness = 0.3 + 0.7 * normHash
        val twinkleFreq = 0.5 + 2.0 * abs(sin(normHash * Math.PI))
        val twinklePhase = normHash * 2.0 * Math.PI

        stars.add(
            ASTStar(
                symbol = token.first(),
                xRatio = xRatio,
                yRatio = yRatio,
                brightnessBase = brightness,
                twinkleFrequency = twinkleFreq,
                twinklePhase = twinklePhase,
                nodeType = nodeType
            )
        )
    }

    return stars
}

// Bresenham's algorithm for drawing constellation line segments in terminal space
fun drawLine(x0: Int, y0: Int, x1: Int, y1: Int, grid: Array<CharArray>, colors: Array<IntArray>, w: Int, h: Int) {
    var x = x0
    var y = y0
    val dx = abs(x1 - x0)
    val dy = abs(y1 - y0)
    val sx = if (x0 < x1) 1 else -1
    val sy = if (y0 < y1) 1 else -1
    var err = dx - dy

    while (true) {
        if (x in 0 until w && y in 0 until h) {
            if (grid[y][x] == ' ') {
                grid[y][x] = '·'
                colors[y][x] = 90 // Dim grey constellation line
            }
        }
        if (x == x1 && y == y1) break
        val e2 = 2 * err
        if (e2 > -dy) {
            err -= dy
            x += sx
        }
        if (e2 < dx) {
            err += dx
            y += sy
        }
    }
}