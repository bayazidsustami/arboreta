import java.io.File
import java.io.InputStream
import java.security.MessageDigest
import kotlin.math.*
import kotlin.random.Random

// Represents a star node generated from a Git commit
data class CommitStar(
    val hash: String,
    val author: String,
    val date: String,
    val message: String,
    val x: Double,
    val y: Double,
    val brightness: Double,
    val poeticFragment: String,
    val hue: Int
)

// Poetic vocabulary dictionary for generative line synthesis
object PoeticLexicon {
    val verbs = listOf("echoes", "weaves", "fractures", "ignites", "dissolves", "blooms", "anchors", "transcends", "remembers", "drifts")
    val nouns = listOf("starlight", "void", "ether", "cipher", "pulse", "silence", "shadow", "horizon", "nexus", "infinity")
    val adjectives = listOf("ancient", "luminous", "ephemeral", "silent", "boundless", "forgotten", "spectral", "resonant", "cosmic", "latent")
    val conjunctions = listOf("beneath", "across", "within", "beyond", "amidst", "toward")

    fun synthesize(commitMsg: String, hash: String): String {
        val seed = hash.fold(0L) { acc, c -> acc + c.code }
        val rng = Random(seed)
        val word = commitMsg.split(Regex("\\s+")).filter { it.length > 2 }.randomOrNull(rng) ?: "code"
        val adj = adjectives.random(rng)
        val verb = verbs.random(rng)
        val noun = nouns.random(rng)
        val prep = conjunctions.random(rng)
        
        return when (rng.nextInt(4)) {
            0 -> "$adj $word $verb $prep $noun"
            1 -> "$word $verb in the $adj $noun"
            2 -> "$prep $adj $noun, $word $verbs"
            else -> "$adj $noun: $word $verb"
        }
    }
}

fun main() {
    // Hide cursor and clear terminal
    print("\u001B[?25l\u001B[2J")
    
    // Add shutdown hook to restore terminal cursor on exit
    Runtime.getRuntime().addShutdownHook(Thread {
        print("\u001B[?25h\u001B[0m\u001B[2J\u001B[1;1H")
    })

    // Fetch commit history via Git command line process
    val commits = fetchGitCommits(limit = 12)
    val width = 90
    val height = 30
    val stars = layoutConstellation(commits, width, height)

    var frame = 0.0
    while (true) {
        // Render current animation frame
        val buffer = Array(height) { CharArray(width) { ' ' } }
        val colorBuffer = Array(height) { IntArray(width) { 0 } }

        // Render Constellation Connections (Lines between nearby stars)
        for (i in stars.indices) {
            for (j in i + 1 until stars.size) {
                val s1 = stars[i]
                val s2 = stars[j]
                val dist = hypot(s1.x - s2.x, s1.y - s2.y)
                if (dist < 22.0) {
                    drawBresenhamLine(
                        s1.x.toInt(), s1.y.toInt(),
                        s2.x.toInt(), s2.y.toInt(),
                        buffer, colorBuffer,
                        (s1.hue + s2.hue) / 2,
                        frame, dist
                    )
                }
            }
        }

        // Render Stars & Calligram Typography
        stars.forEachIndexed { idx, star ->
            val pulse = (sin(frame * 0.15 + idx) + 1.0) / 2.0
            val sx = star.x.roundToInt().coerceIn(0, width - 1)
            val sy = star.y.roundToInt().coerceIn(0, height - 1)
            
            // Draw central star node
            buffer[sy][sx] = if (pulse > 0.5) '★' else '✦'
            colorBuffer[sy][sx] = star.hue

            // Render poetic text calligram along radiating orbital arcs
            val text = star.poeticFragment
            for (charIdx in text.indices) {
                val angle = (frame * 0.03 * (if (idx % 2 == 0) 1 else -1)) + (charIdx * 0.3)
                val radius = 2.5 + sin(frame * 0.05 + charIdx) * 0.5
                val tx = (star.x + cos(angle) * radius * 1.8).toInt()
                val ty = (star.y + sin(angle) * radius * 0.9).toInt()

                if (tx in 0 until width && ty in 0 until height && buffer[ty][tx] == ' ') {
                    buffer[ty][tx] = text[charIdx]
                    colorBuffer[ty][tx] = (star.hue + charIdx * 5) % 360
                }
            }
        }

        // Output double buffer with ANSI color mapping
        val sb = StringBuilder("\u001B[H")
        for (y in 0 until height) {
            for (x in 0 until width) {
                val char = buffer[y][x]
                val hue = colorBuffer[y][x]
                if (char != ' ') {
                    val (r, g, b) = hslToRgb(hue.toDouble(), 0.85, 0.65)
                    sb.append("\u001B[38;2;$r;$g;${b}m$char")
                } else {
                    sb.append(" ")
                }
            }
            sb.append("\n")
        }
        
        // Print header & canvas
        print("\u001B[H\u001B[1;36m✦ GENERATIVE GIT POETRY CONSTELLATION MAP ✦\u001B[0m\n")
        print(sb.toString())

        Thread.sleep(50)
        frame += 1.0
    }
}

// Helper: Fetch Git commit log directly using external process execution
fun fetchGitCommits(limit: Int): List<Triple<String, String String,>> {
    return try {
        val process = ProcessBuilder("git", "log", "-n", limit.toString(), "--pretty=format:%h|%an|%s")
            .redirectOutput(ProcessBuilder.Redirect.PIPE)
            .start()
        val text = process.inputStream.bufferedReader().readText()
        process.waitFor()
        if (text.isBlank()) mockCommits() else text.lines().map { line ->
            val parts = line.split("|")
            Triple(parts.getOrElse(0) { "0000000" }, parts.getOrElse(1) { "Unknown" }, parts.getOrElse(2) { "Initial commit" })
        }
    } catch (e: Exception) {
        mockCommits()
    }
}

// Fallback generator when Git is unavailable or repository is empty
fun mockCommits(): List<Triple<String, String String,>> {
    return listOf(
        Triple("a1b2c3d", "Ada Lovelace", "Initialize analytical engine algorithm"),
        Triple("f4e5d6c", "Alan Turing", "Enigma decryption sequence resolved"),
        Triple("7b8c9d0", "Grace Hopper", "Fixed primary compiler bug in vacuum tube"),
        Triple("e1f2a3b", "Margaret Hamilton", "Apollo guidance computer code optimized"),
        Triple("c4d5e6f", "John Carmack", "Fast inverse square root raycaster integrated"),
        Triple("9a8b7c6", "Linus Torvalds", "Kernel monolithic scheduler rewrite")
    )
}

// Layout algorithms positioning commits in dynamic space using spectral hashing
fun layoutConstellation(commits: List<Triple<String, String String,>>, width: Int, height: Int): List<CommitStar> {
    val rng = Random(1337)
    val cx = width / 2.0
    val cy = height / 2.0
    val radiusStep = min(cx, cy) / (commits.size + 1)

    return commits.mapIndexed { i, (hash, author, msg) ->
        val angle = i * (2.0 * PI / commits.size) + (rng.nextDouble() * 0.4 - 0.2)
        val dist = (i + 1) * radiusStep + (rng.nextDouble() * 4.0 - 2.0)
        val x = (cx + cos(angle) * dist * 1.8).coerceIn(4.0, width - 5.0)
        val y = (cy + sin(angle) * dist * 0.9).coerceIn(4.0, height - 5.0)

        val hashInt = hash.fold(0) { acc, c -> acc + c.code }
        val hue = (hashInt * 137) % 360
        val poem = PoeticLexicon.synthesize(msg, hash)

        CommitStar(hash, author, "", msg, x, y, 1.0, poem, hue)
    }
}

// Custom Bresenham line renderer with visual pulsation
fun drawBresenhamLine(x0: Int, y0: Int, x1: Int, y1: Int, buffer: Array<CharArray>, colorBuffer: Array<IntArray>, hue: Int, frame: Double, dist: Double) {
    var x = x0
    var y = y0
    val dx = abs(x1 - x0)
    val dy = abs(y1 - y0)
    val sx = if (x0 < x1) 1 else -1
    val sy = if (y0 < y1) 1 else -1
    var err = dx - dy

    val lineChars = listOf('·', '∘', '.', '°', '•')

    while (true) {
        if (x in buffer[0].indices && y in buffer.indices) {
            if (buffer[y][x] == ' ') {
                val wave = (sin(frame * 0.2 + (x + y) * 0.1) + 1.0) / 2.0
                val charIdx = (wave * (lineChars.size - 1)).toInt()
                buffer[y][x] = lineChars[charIdx]
                colorBuffer[y][x] = hue
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

// Color conversion helper: HSL to RGB triplet
fun hslToRgb(h: Double, s: Double, l: Double): Triple<Int, Int Int,> {
    val c = (1.0 - abs(2.0 * l - 1.0)) * s
    val x = c * (1.0 - abs((h / 60.0) % 2.0 - 1.0))
    val m = l - c / 2.0
    val (r1, g1, b1) = when {
        h < 60 -> Triple(c, x, 0.0)
        h < 120 -> Triple(x, c, 0.0)
        h < 180 -> Triple(0.0, c, x)
        h < 240 -> Triple(0.0, x, c)
        h < 300 -> Triple(x, 0.0, c)
        else -> Triple(c, 0.0, x)
    }
    return Triple(
        ((r1 + m) * 255).toInt().coerceIn(0, 255),
        ((g1 + m) * 255).toInt().coerceIn(0, 255),
        ((b1 + m) * 255).toInt().coerceIn(0, 255)
    )
}