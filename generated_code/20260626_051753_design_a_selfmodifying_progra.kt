import java.awt.*
import java.awt.event.*
import java.awt.geom.Line2D
import java.io.File
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

// ---------- Helper: read CPU temperature (Linux) ----------
fun readCpuTemp(): Double {
    return try {
        val txt = File("/sys/class/thermal/thermal_zone0/temp").readText().trim()
        txt.toDouble() / 1000.0
    } catch (e: Exception) {
        // fallback random temperature for non‑Linux systems
        40.0 + Math.random() * 30.0
    }
}

// ---------- Simple sentiment analysis ----------
val positiveWords = setOf("sun", "bright", "warm", "glow", "joy", "love", "peace")
val negativeWords = setOf("cold", "dark", "gray", "sad", "lonely", "storm", "pain")

fun sentimentScore(text: String): Int {
    var score = 0
    text.lowercase().split(Regex("\\W+")).forEach {
        when {
            it in positiveWords -> score++
            it in negativeWords -> score--
        }
    }
    return score
}

// ---------- Poem generator based on temperature ----------
fun generatePoem(temp: Double): String {
    // Use temperature to decide number of lines and syllable count (very rough)
    val lines = (temp / 10).toInt().coerceIn(2, 6)
    val syllables = (temp % 10).toInt() + 4               // 4‑8 syllables per line
    val words = listOf("cold", "bright", "storm", "glow", "rain", "sun", "night", "dream", "fire", "silence")
    val sb = StringBuilder()
    repeat(lines) { i ->
        val lineWords = mutableListOf<String>()
        var written = 0
        while (written < syllables) {
            val w = words.random()
            lineWords.add(w)
            written += 1 + w.length % 3                     // fake syllable count
        }
        sb.append(lineWords.joinToString(" ").replaceFirstChar { it.uppercase() })
        if (i < lines - 1) sb.append('\n')
    }
    return sb.toString()
}

// ---------- L‑system fractal ----------
data class LSystem(val axiom: String, val rules: Map<Char, String>, val angle: Double, val iterations: Int)

fun expand(ls: LSystem): String {
    var cur = ls.axiom
    repeat(ls.iterations) {
        val sb = StringBuilder()
        cur.forEach { ch ->
            sb.append(ls.rules.getOrDefault(ch, ch.toString()))
        }
        cur = sb.toString()
    }
    return cur
}

// ---------- Visualization ----------
class FractalPanel(private val commands: String, private val hueBase: Float) : Panel() {
    private var t = 0.0
    private val timer = Timer(30) { repaint() }

    init { timer.start() }

    override fun paint(g: Graphics) {
        val g2 = g as Graphics2D
        g2.color = Color.BLACK
        g2.fillRect(0, 0, size.width, size.height)

        val stack = java.util.Stack<Pair<Point2D.Double, Double>>()
        var x = size.width / 2.0
        var y = size.height.toDouble()
        var angle = -Math.PI / 2
        val step = 5.0

        commands.forEach { ch ->
            when (ch) {
                'F' -> {
                    val nx = x + step * cos(angle)
                    val ny = y + step * sin(angle)
                    val hue = (hueBase + (t / 1000) % 1f) % 1f
                    g2.stroke = BasicStroke(2f)
                    g2.color = Color.getHSBColor(hue, 0.8f, 0.9f)
                    g2.draw(Line2D.Double(x, y, nx, ny))
                    x = nx; y = ny
                }
                '+' -> angle += Math.toRadians(25.0)
                '-' -> angle -= Math.toRadians(25.0)
                '[' -> stack.push(Pair(Point2D.Double(x, y), angle))
                ']' -> {
                    val (pt, a) = stack.pop()
                    x = pt.x; y = pt.y; angle = a
                }
            }
        }
        t += 30
    }
}

// ---------- Self‑modifying part ----------
fun selfModify(poem: String) {
    val sourceFile = File(System.getProperty("java.class.path"))
    if (!sourceFile.isFile) return
    val content = sourceFile.readText()
    val marker = "// === POEM START ==="
    val newContent = if (marker in content) {
        content.substringBefore(marker) + marker + "\n" + poem + "\n// === POEM END ==="
    } else {
        content + "\n$marker\n$poem\n// === POEM END ==="
    }
    sourceFile.writeText(newContent)
}

// ---------- Main ----------
fun main() {
    val temp = readCpuTemp()
    val poem = generatePoem(temp)
    println("Current CPU temp: %.1f°C".format(temp))
    println("\n--- Poem ---\n$poem\n--- End Poem ---\n")

    // sentiment influences color hue
    val sentiment = sentimentScore(poem)
    val hueBase = ((sentiment + 5).coerceIn(0, 10)) / 10f   // 0.0 .. 1.0

    // define a simple L‑system (binary tree)
    val ls = LSystem(
        axiom = "F",
        rules = mapOf('F' to "F[+F]F[-F]F"),
        angle = Math.toRadians(25.0),
        iterations = 4
    )
    val commands = expand(ls)

    // create window
    val frame = Frame("Poetic Fractal")
    frame.size = Dimension(800, 600)
    frame.add(FractalPanel(commands, hueBase))
    frame.isVisible = true
    frame.addWindowListener(object : WindowAdapter() {
        override fun windowClosing(e: WindowEvent?) = System.exit(0)
    })

    // write poem back into source for next run
    selfModify(poem)
}