import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpResponse
import java.time.Duration
import kotlin.concurrent.thread
import kotlin.math.*

/**
 * Non-Euclidean ASCII Fluid Automaton Driven by Live News Sentiment
 * 
 * Features:
 * - Real-time global news fetching & sentiment analysis (positive/negative balance).
 * - Non-Euclidean topology warping (Möbius / Klein-bottle lattice wrapping with hyperbolic metrics).
 * - Eulerian grid cellular automaton for fluid density & vorticity propagation.
 * - Dynamic ASCII rendering with ANSI color palette shifted by current sentiment.
 */

data class SentimentState(
    @Volatile var score: Double = 0.0,       // Negative (-1.0) to Positive (+1.0)
    @Volatile var urgency: Double = 0.5,     // Volatility / Energy (0.0 to 1.0)
    @Volatile var lastHeadline: String = "Initializing global news stream..."
)

class NewsSentimentFetcher(private val state: SentimentState) {
    private val client = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(3))
        .build()

    private val rssUrls = listOf(
        "[https://feeds.bbci.co.uk/news/world/rss.xml](https://feeds.bbci.co.uk/news/world/rss.xml)",
        "[https://rss.nytimes.com/services/xml/rss/nyt/World.xml](https://rss.nytimes.com/services/xml/rss/nyt/World.xml)"
    )

    private val posWords = setOf("peace", "growth", "breakthrough", "success", "hope", "accord", "gain", "future", "climate", "cure", "hero", "win", "progress")
    private val negWords = setOf("war", "crisis", "strike", "crash", "death", "threat", "attack", "decline", "fire", "storm", "clash", "risk", "disaster")

    fun start() {
        thread(isDaemon = true, name = "NewsFetcher") {
            var urlIndex = 0
            while (true) {
                try {
                    val url = rssUrls[urlIndex % rssUrls.size]
                    urlIndex++
                    val request = java.net.http.HttpRequest.newBuilder()
                        .uri(URI.create(url))
                        .timeout(Duration.ofSeconds(4))
                        .GET()
                        .build()

                    val response = client.send(request, HttpResponse.BodyHandlers.ofString())
                    if (response.statusCode() == 200) {
                        parseAndAnalyze(response.body())
                    }
                } catch (e: Exception) {
                    // Fallback to simulated ambient noise on network delay
                    simulateNoise()
                }
                Thread.sleep(12000)
            }
        }
    }

    private fun parseAndAnalyze(xml: String) {
        val titles = Regex("<title><!\\[CDATA\\[(.* Rotated)?(.*?)\\]\\]></title>|<title>(.*?)</title>")
            .findAll(xml)
            .map { it.groupValues.last { g -> g.isNotBlank() } }
            .filter { !it.contains("BBC") && !it.contains("NYT") }
            .toList()

        if (titles.isNotEmpty()) {
            val headline = titles.random()
            val words = headline.lowercase().split(Regex("\\W+"))
            val posCount = words.count { it in posWords }
            val negCount = words.count { it in negWords }

            val rawScore = when {
                posCount + negCount == 0 -> (Math.random() - 0.5) * 0.4
                else -> (posCount - negCount).toDouble() / (posCount + negCount)
            }

            // Smooth updates
            state.score = (state.score * 0.6) + (rawScore * 0.4)
            state.urgency = (words.size.toDouble() / 25.0).coerceIn(0.2, 1.0)
            state.lastHeadline = headline
        }
    }

    private fun simulateNoise() {
        state.score = (state.score + (Math.random() - 0.5) * 0.2).coerceIn(-1.0, 1.0)
        state.urgency = (0.3 + Math.random() * 0.5)
        state.lastHeadline = "Simulated Sentiment Stream [Offline Fallback]"
    }
}

class NonEuclideanFluidSim(val width: Int, val height: Int) {
    private val density = Array(height) { DoubleArray(width) }
    private val velocityX = Array(height) { DoubleArray(width) }
    private val velocityY = Array(height) { DoubleArray(width) }
    private val prevDensity = Array(height) { DoubleArray(width) }

    private var t = 0.0

    // Non-Euclidean coordinate mapping: Klein bottle topological wrapping
    private fun mapCoords(x: Int, y: Int): Pair<Int, Int> {
        var nx = x
        var ny = y

        if (ny < 0) {
            ny += height
            nx = width - 1 - ((nx + width) % width) // Flip x on boundary crossing
        } else if (ny >= height) {
            ny -= height
            nx = width - 1 - ((nx + width) % width)
        }

        nx = (nx + width) % width
        return Pair(nx, ny)
    }

    fun step(sentiment: Double, urgency: Double) {
        t += 0.05 + urgency * 0.05
        val viscosity = 0.96 + (sentiment * 0.03) // Positive sentiment -> smooth flow, Negative -> turbulence

        // Inject forces based on non-Euclidean hyperbolic vortex generators
        val centerX = width / 2.0 + sin(t * 1.3) * (width / 4.0)
        val centerY = height / 2.0 + cos(t * 0.9) * (height / 4.0)

        for (y in 0 until height) {
            for (x in 0 until width) {
                // Poincare hyperbolic warping metric
                val dx = (x - centerX) / (width / 2.0)
                val dy = (y - centerY) / (height / 2.0)
                val r2 = dx * dx + dy * dy
                val warpFactor = 2.0 / (1.0 + r2).coerceAtLeast(0.1)

                // Inject energy influenced by sentiment
                if (r2 < 0.2) {
                    density[y][x] = (density[y][x] + 1.5 * urgency).coerceAtMost(5.0)
                    val angle = atan2(dy, dx) + (if (sentiment < 0) -1.5 else 1.5) * PI / 2.0
                    velocityX[y][x] += cos(angle) * urgency * warpFactor * 2.0
                    velocityY[y][x] += sin(angle) * urgency * warpFactor * 2.0
                }
            }
        }

        // Cellular Automaton Advection & Diffusion Loop
        for (y in 0 until height) {
            for (x in 0 until width) {
                prevDensity[y][x] = density[y][x]
            }
        }

        for (y in 0 until height) {
            for (x in 0 until width) {
                // Trace back using velocity field
                val backX = x - velocityX[y][x]
                val backY = y - velocityY[y][x]

                val ix = floor(backX).toInt()
                val iy = floor(backY).toInt()

                val (p00x, p00y) = mapCoords(ix, iy)
                val (p10x, p10y) = mapCoords(ix + 1, iy)
                val (p01x, p01y) = mapCoords(ix, iy + 1)
                val (p11x, p11y) = mapCoords(ix + 1, iy + 1)

                val fx = backX - ix
                val fy = backY - iy

                val top = prevDensity[p00y][p00x] * (1 - fx) + prevDensity[p10y][p10x] * fx
                val bottom = prevDensity[p01y][p01x] * (1 - fx) + prevDensity[p11y][p11x] * fx

                density[y][x] = (top * (1 - fy) + bottom * fy) * viscosity

                // Dissipate velocity slowly
                velocityX[y][x] *= 0.92
                velocityY[y][x] *= 0.92
            }
        }
    }

    fun renderAscii(sentimentState: SentimentState): String {
        val asciiChars = " .':-~+=*x%#@".toCharArray()
        val sb = StringBuilder("\u001B[H") // Reset cursor to top-left

        val score = sentimentState.score
        // ANSI Color selection based on sentiment: Red (Negative) -> Cyan/Yellow (Neutral) -> Green/Magenta (Positive)
        val colorCode = when {
            score < -0.3 -> "\u001B[31m"  // Red
            score < -0.1 -> "\u001B[33m"  // Yellow
            score < 0.2 -> "\u001B[36m"   // Cyan
            else -> "\u001B[32m"          // Green
        }
        val resetCode = "\u001B[0m"

        sb.append("=== Non-Euclidean ASCII News Fluid Dynamic Cellular Automaton ===\n")
        sb.append("Sentiment Score: %+.2f | Energy/Urgency: %.2f\n".format(score, sentimentState.urgency))
        val truncatedHeadline = if (sentimentState.lastHeadline.length > width - 12) 
            sentimentState.lastHeadline.take(width - 15) + "..." 
        else sentimentState.lastHeadline
        sb.append("Headline: \"$truncatedHeadline\"\n")
        sb.append("-".repeat(width)).append("\n")

        for (y in 0 until height) {
            for (x in 0 until width) {
                val valDensity = density[y][x].coerceIn(0.0, 1.0)
                val idx = (valDensity * (asciiChars.size - 1)).roundToInt()
                val ch = asciiChars[idx]

                if (ch == ' ') {
                    sb.append(' ')
                } else {
                    sb.append(colorCode).append(ch).append(resetCode)
                }
            }
            sb.append("\n")
        }
        return sb.toString()
    }
}

fun main() {
    val width = 70
    val height = 24

    val state = SentimentState()
    val fetcher = NewsSentimentFetcher(state)
    fetcher.start()

    val sim = NonEuclideanFluidSim(width, height)

    // Clear terminal screen
    print("\u001B[2J")

    while (true) {
        sim.step(state.score, state.urgency)
        print(sim.renderAscii(state))
        Thread.sleep(60)
    }
}