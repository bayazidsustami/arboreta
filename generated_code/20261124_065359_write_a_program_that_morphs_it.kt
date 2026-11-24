import java.awt.BasicStroke
import java.awt.Color
import java.awt.Dimension
import java.awt.Font
import java.awt.Graphics
import java.awt.Graphics2D
import java.awt.RenderingHints
import java.awt.geom.Path2D
import java.util.Locale
import javax.swing.JFrame
import javax.swing.JPanel
import javax.swing.SwingUtilities
import javax.swing.Timer
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

// Represents a live transit delay feed sample and its derived sentiment (-1.0 frustated .. +1.0 calm).
data class TransitPulse(val line: String, val delayMinutes: Int, val note: String, val sentiment: Double)

// Checks primality for city Air Quality Index (AQI) integer readings.
fun isPrime(n: Int): Boolean {
    if (n < 2) return false
    if (n == 2) return true
    if (n % 2 == 0) return false
    var d = 3
    while (d * d <= n) {
        if (n % d == 0) return false
        d += 2
    }
    return true
}

// Synthesizes realistic streaming transit delay notes and scores sentiment.
class TransitSentimentStream {
    private var tick = 0
    private val templates = listOf(
        Triple("Red Line", 18, "Signal failure stalled trains downtown; riders frustrated"),
        Triple("Blue Line", 2, "Minor platform hold, smooth recovery ahead"),
        Triple("Green Line", 24, "Severe bus bunching and missed connections in rush hour"),
        Triple("Orange Line", 0, "On-time service with steady flow and calm platforms"),
        Triple("Yellow Line", 11, "Slow zone near bridge causing moderate delays"),
        Triple("Purple Line", 4, "Brief switch check, crews resolving quickly")
    )

    fun nextPulse(): TransitPulse {
        val (line, baseDelay, note, _) = templates[tick % templates.size]
        val wave = sin(tick * 0.7) * 5.0
        val delay = max(0, (baseDelay + wave).toInt())
        tick++

        // Lexicon + delay severity heuristic mapped to [-1.0, +1.0].
        val lower = note.lowercase(Locale.ROOT)
        val negativeHits = listOf("failure", "stalled", "frustrated", "severe", "missed", "slow").count { it in lower }
        val positiveHits = listOf("smooth", "on-time", "steady", "calm", "quickly").count { it in lower }
        val delayPenalty = min(1.0, delay / 25.0)
        val rawSentiment = (positiveHits - negativeHits) * 0.35 - delayPenalty * 0.65
        val clamped = max(-1.0, min(1.0, rawSentiment))
        return TransitPulse(line, delay, note, clamped)
    }
}

// Synthesizes city AQI readings, intentionally surfacing prime numbers periodically.
class CityAqiStream {
    private var step = 0
    private val readings = listOf(42, 43, 58, 61, 74, 79, 88, 97, 104, 113, 120, 127)

    fun nextReading(): Int {
        val value = readings[step % readings.size] + ((step / readings.size) * 2)
        step++
        return value
    }
}

// Self-morphing Swing canvas rendering a melting clock driven by AQI primes and transit sentiment.
class MeltingPrimeClockPanel : JPanel() {
    private val transitStream = TransitSentimentStream()
    private val aqiStream = CityAqiStream()

    private var currentSentiment = 0.0
    private var currentAqi = 42
    private var lastPrimeAqi: Int? = null
    private var primeHits = 0
    private var pulseCount = 0

    // Clock angles (in radians) advance ONLY when AQI is prime.
    private var secondAngle = -PI / 2.0
    private var minuteAngle = -PI / 2.0
    private var hourAngle = -PI / 2.0
    private var meltPhase = 0.0

    private val timer: Timer = Timer(450) { onMorphingTick() }

    init {
        preferredSize = Dimension(680, 540)
        background = Color(14, 17, 26)
        timer.isCoalesce = true
        timer.start()
    }

    // Computes target timer interval (ms) from sentiment: negative/tense speeds up or slows down;
    // here negative sentiment (delays/frustration) accelerates frantic ticks (120ms),
    // while calm/positive sentiment relaxes into slower ticks (900ms).
    private fun computeIntervalMs(sentiment: Double): Int {
        val normalized = (sentiment + 1.0) / 2.0 // 0.0 (frantic/negative) -> 1.0 (calm/positive)
        return (120 + normalized * 780).toInt()
    }

    private fun onMorphingTick() {
        pulseCount++
        val pulse = transitStream.nextPulse()
        currentSentiment = pulse.sentiment
        currentAqi = aqiStream.nextReading()
        meltPhase += 0.16 + (1.0 - ((currentSentiment + 1.0) / 2.0)) * 0.25

        // Clock hands move strictly when the city's AQI reading is a prime number.
        if (isPrime(currentAqi)) {
            primeHits++
            lastPrimeAqi = currentAqi
            val stepScale = 1.0 + (1.0 - ((currentSentiment + 1.0) / 2.0)) * 1.5
            secondAngle += (PI / 15.0) * stepScale
            minuteAngle += (PI / 90.0) * stepScale
            hourAngle += (PI / 360.0) * stepScale
        }

        // Morph execution speed dynamically in response to transit delay sentiment.
        timer.delay = computeIntervalMs(currentSentiment)
        repaint()
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        val g2 = g as Graphics2D
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        val cx = width / 2.0
        val cy = height / 2.0 + 25.0
        val radius = min(width, height) * 0.27

        drawMeltingCase(g2, cx, cy, radius)
        drawDialTicks(g2, cx, cy, radius)
        drawHands(g2, cx, cy, radius)
        drawTelemetryHud(g2)
    }

    private fun drawMeltingCase(g2: Graphics2D, cx: Double, cy: Double, r: Double) {
        // Tension shifts the clock's melt hue from warm amber-gold toward molten coral-violet.
        val tension = 1.0 - ((currentSentiment + 1.0) / 2.0)
        val dripStretch = r * (0.25 + tension * 0.55)

        val path = Path2D.Double()
        val segments = 72
        for (i in 0..segments) {
            val theta = (i.toDouble() / segments) * 2.0 * PI
            val downwardBias = max(0.0, sin(theta))
            val droop = downwardBias * dripStretch * (0.65 + 0.35 * sin(meltPhase + theta * 3.0))
            val ripple = cos(theta * 5.0 - meltPhase * 1.4) * (4.0 + tension * 6.0)
            val px = cx + (r + ripple) * cos(theta)
            val py = cy + r * sin(theta) + droop
            if (i == 0) path.moveTo(px, py) else path.lineTo(px, py)
        }
        path.closePath()

        val fillColor = Color(
            min(255, (215 + tension * 35).toInt()),
            max(60, (165 - tension * 95).toInt()),
            min(220, (95 + tension * 110).toInt()),
            235
        )
        g2.color = fillColor
        g2.fill(path)

        g2.color = Color(250, 235, 195)
        g2.stroke = BasicStroke(3.0f)
        g2.draw(path)
    }

    private fun drawDialTicks(g2: Graphics2D, cx: Double, cy: Double, r: Double) {
        g2.color = Color(32, 26, 38)
        for (i in 0 until 12) {
            val angle = i * (PI / 6.0) - PI / 2.0
            val inner = r * (if (i % 3 == 0) 0.74 else 0.82)
            val outer = r * 0.92
            g2.stroke = BasicStroke(if (i % 3 == 0) 3.0f else 1.5f)
            g2.drawLine(
                (cx + inner * cos(angle)).toInt(),
                (cy + inner * sin(angle)).toInt(),
                (cx + outer * cos(angle)).toInt(),
                (cy + outer * sin(angle)).toInt()
            )
        }
    }

    private fun drawHands(g2: Graphics2D, cx: Double, cy: Double, r: Double) {
        val isPrimeNow = isPrime(currentAqi)
        val handColor = if (isPrimeNow) Color(25, 25, 30) else Color(95, 85, 100)

        // Hour hand
        g2.color = handColor
        g2.stroke = BasicStroke(6.0f, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)
        g2.drawLine(
            cx.toInt(),
            cy.toInt(),
            (cx + r * 0.45 * cos(hourAngle)).toInt(),
            (cy + r * 0.45 * sin(hourAngle)).toInt()
        )

        // Minute hand
        g2.stroke = BasicStroke(4.0f, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)
        g2.drawLine(
            cx.toInt(),
            cy.toInt(),
            (cx + r * 0.68 * cos(minuteAngle)).toInt(),
            (cy + r * 0.68 * sin(minuteAngle)).toInt()
        )

        // Second hand (highlights vividly when prime AQI unlocks motion)
        g2.color = if (isPrimeNow) Color(20, 190, 140) else Color(120, 110, 125)
        g2.stroke = BasicStroke(2.2f, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)
        g2.drawLine(
            cx.toInt(),
            cy.toInt(),
            (cx + r * 0.78 * cos(secondAngle)).toInt(),
            (cy + r * 0.78 * sin(secondAngle)).toInt()
        )

        g2.color = Color(25, 25, 30)
        g2.fillOval((cx - 6).toInt(), (cy - 6).toInt(), 12, 12)
    }

    private fun drawTelemetryHud(g2: Graphics2D) {
        val primeStatus = if (isPrime(currentAqi)) "PRIME (HANDS MOVED)" else "COMPOSITE (HANDS LOCKED)"
        g2.font = Font("SansSerif", Font.BOLD, 14)
        g2.color = Color(235, 240, 250)
        g2.drawString(
            String.format(
                Locale.ROOT,
                "Pulse #%d | Timer Interval: %d ms | Transit Sentiment: %+.2f",
                pulseCount,
                timer.delay,
                currentSentiment
            ),
            20,
            28
        )

        g2.font = Font("SansSerif", Font.PLAIN, 13)
        g2.color = if (isPrime(currentAqi)) Color(90, 235, 180) else Color(210, 175, 130)
        g2.drawString(
            "City AQI: $currentAqi -> $primeStatus | Prime Ticks: $primeHits (Last Prime: ${lastPrimeAqi ?: "none"})",
            20,
            50
        )
    }
}

fun main() {
    SwingUtilities.invokeLater {
        val frame = JFrame("Morphing Transit Sentiment & Prime-AQI Melting Clock")
        frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
        frame.add(MeltingPrimeClockPanel())
        frame.pack()
        frame.setLocationRelativeTo(null)
        frame.isVisible = true
    }
}