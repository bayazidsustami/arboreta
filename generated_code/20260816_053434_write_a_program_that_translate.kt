import java.awt.AlphaComposite
import java.awt.Color
import java.awt.Dimension
import java.awt.Graphics
import java.awt.Graphics2D
import java.awt.RenderingHints
import java.awt.image.BufferedImage
import java.util.Random
import javax.sound.sampled.AudioFormat
import javax.sound.sampled.AudioSystem
import javax.sound.sampled.SourceDataLine
import javax.swing.JFrame
import javax.swing.JPanel
import javax.swing.SwingUtilities
import kotlin.concurrent.thread
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * Generates microtonal audio synthesis and digital watercolor visuals driven by 
 * simulated live weather telemetry (Temperature, Pressure, Wind Speed).
 */

data class WeatherTelemetry(
    var temperatureC: Double, // Drives hue/warmth and base pitch frequency
    var pressureHpa: Double,  // Drives watercolor bleeding rate and harmonic density
    var windSpeedKmh: Double  // Drives visual turbulent drift and audio tremolo speed
)

class GenerativeAtmosphereApp : JPanel() {

    private val width = 800
    private val height = 600
    private val canvasImage = BufferedImage(width, height, BufferedImage.TYPE_INT_ARGB)
    private val random = Random()

    // Live Telemetry Simulation
    private var telemetry = WeatherTelemetry(temperatureC = 18.0, pressureHpa = 1013.25, windSpeedKmh = 12.0)
    private var telemetryTime = 0.0

    // Audio Engine state
    @Volatile private var isRunning = true
    private var currentFreq1 = 220.0
    private var currentFreq2 = 220.0 * Math.pow(2.0, 13.0 / 31.0) // 31-EDO Microtonal interval (~Neutral Third)
    private var currentFreq3 = 220.0 * Math.pow(2.0, 18.0 / 31.0) // 31-EDO Fifth-ish interval

    init {
        preferredSize = Dimension(width, height)
        
        // Initialize canvas with an organic background wash
        val g2 = canvasImage.createGraphics()
        g2.color = Color(245, 242, 235)
        g2.fillRect(0, 0, width, height)
        g2.dispose()

        // Telemetry Update Loop
        thread(isDaemon = true) {
            while (isRunning) {
                telemetryTime += 0.05
                // Smoothly modulate telemetry simulating dynamic micro-climates
                telemetry.temperatureC = 15.0 + 10.0 * sin(telemetryTime * 0.1)
                telemetry.pressureHpa = 1013.25 + 20.0 * cos(telemetryTime * 0.07)
                telemetry.windSpeedKmh = 10.0 + 8.0 * sin(telemetryTime * 0.15) + 4.0 * random.nextDouble()

                // Map temperature to microtonal pitch anchors (A2 to A4 scale)
                val baseFreq = 110.0 * Math.pow(2.0, (telemetry.temperatureC + 10.0) / 20.0)
                // Select intervals from 31-Equal Division of Tone (31-EDO) microtonal scale
                val microtonalStep1 = (telemetry.pressureHpa % 31).toInt()
                val microtonalStep2 = ((telemetry.pressureHpa + 13) % 31).toInt()

                currentFreq1 = baseFreq
                currentFreq2 = baseFreq * Math.pow(2.0, microtonalStep1 / 31.0)
                currentFreq3 = baseFreq * Math.pow(2.0, microtonalStep2 / 31.0)

                Thread.sleep(100)
            }
        }

        // Visual Generation Loop
        thread(isDaemon = true) {
            while (isRunning) {
                updateWatercolorCanvas()
                repaint()
                Thread.sleep(30)
            }
        }

        // Audio Synthesis Loop
        thread(isDaemon = true) {
            runAudioSynthesizer()
        }
    }

    private fun updateWatercolorCanvas() {
        val g2 = canvasImage.createGraphics()
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        // Bleed / Softening effect (Fading old frames into semi-translucent paper layers)
        g2.composite = AlphaComposite.getInstance(AlphaComposite.SRC_OVER, 0.03f)
        g2.color = Color(248, 246, 240)
        g2.fillRect(0, 0, width, height)

        // Temperature maps to watercolor color palette (Cool Blue/Cyan -> Warm Amber/Magenta)
        val tempNorm = ((telemetry.temperatureC - 5.0) / 30.0).coerceIn(0.0, 1.0).toFloat()
        val r = (0.2f + 0.7f * tempNorm).coerceIn(0f, 1f)
        val g = (0.3f + 0.3f * (1.0f - tempNorm)).coerceIn(0f, 1f)
        val b = (0.8f - 0.6f * tempNorm).coerceIn(0f, 1f)

        // Pressure maps to diffusion size and opacity
        val pressureNorm = ((telemetry.pressureHpa - 990.0) / 50.0).coerceIn(0.2, 1.0)
        val alpha = (0.05f + 0.08f * (1.0 - pressureNorm)).toFloat().coerceIn(0.01f, 0.2f)
        val baseRadius = 40.0 + 80.0 * pressureNorm

        // Wind maps to directional drift offset
        val windAngle = telemetryTime * 0.2
        val windDriftX = cos(windAngle) * telemetry.windSpeedKmh * 2.0
        val windDriftY = sin(windAngle) * telemetry.windSpeedKmh * 2.0

        // Paint organic watercolor splotches using overlapping translucent rings
        g2.composite = AlphaComposite.getInstance(AlphaComposite.SRC_OVER, alpha)
        for (i in 0..4) {
            val cx = (width / 2) + cos(telemetryTime + i) * (width * 0.3) + windDriftX
            val cy = (height / 2) + sin(telemetryTime * 0.8 + i) * (height * 0.3) + windDriftY

            val rVar = r + (random.nextFloat() * 0.1f - 0.05f)
            val gVar = g + (random.nextFloat() * 0.1f - 0.05f)
            val bVar = b + (random.nextFloat() * 0.1f - 0.05f)

            g2.color = Color(rVar.coerceIn(0f, 1f), gVar.coerceIn(0f, 1f), bVar.coerceIn(0f, 1f))

            // Draw organic, irregular watercolor blobs
            val layers = 8
            for (j in layers downTo 1) {
                val layerRadius = baseRadius * (j.toDouble() / layers) + random.nextDouble() * 10.0
                val px = cx + random.nextGaussian() * 5.0
                val py = cy + random.nextGaussian() * 5.0
                g2.fillOval((px - layerRadius).toInt(), (py - layerRadius).toInt(), (layerRadius * 2).toInt(), (layerRadius * 2).toInt())
            }
        }

        g2.dispose()
    }

    private fun runAudioSynthesizer() {
        val sampleRate = 44100f
        val format = AudioFormat(sampleRate, 16, 1, true, true)
        val line: SourceDataLine = AudioSystem.getSourceDataLine(format)
        line.open(format, 44100)
        line.start()

        val buffer = ByteArray(1024)
        var phase1 = 0.0
        var phase2 = 0.0
        var phase3 = 0.0
        var LFOPhase = 0.0

        while (isRunning) {
            val tremoloRate = 0.5 + (telemetry.windSpeedKmh / 10.0) // Tremolo linked to wind speed
            val lfoInc = 2.0 * PI * tremoloRate / sampleRate

            for (i in 0 until buffer.size step 2) {
                phase1 += 2.0 * PI * currentFreq1 / sampleRate
                phase2 += 2.0 * PI * currentFreq2 / sampleRate
                phase3 += 2.0 * PI * currentFreq3 / sampleRate
                LFOPhase += lfoInc

                // Pure Sine Oscillation combined with smooth microtonal drone harmonics
                val tremolo = 0.6 + 0.4 * sin(LFOPhase)
                val wave = (sin(phase1) * 0.4 + sin(phase2) * 0.3 + sin(phase3) * 0.3) * tremolo

                val sample = (wave * 8000.0).toInt().coerceIn(-32768, 32767).toShort()
                buffer[i] = (sample.toInt() shr 8).toByte()
                buffer[i + 1] = (sample.toInt() and 0xFF).toByte()
            }

            line.write(buffer, 0, buffer.size)
        }

        line.drain()
        line.close()
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        g.drawImage(canvasImage, 0, 0, null)

        // Overlay Telemetry HUD Text
        g.color = Color(40, 40, 40, 180)
        g.drawString(String.format("Temp: %.1f°C | Pressure: %.1f hPa | Wind: %.1f km/h", 
            telemetry.temperatureC, telemetry.pressureHpa, telemetry.windSpeedKmh), 20, 30)
    }

    fun stop() {
        isRunning = false
    }
}

fun main() {
    SwingUtilities.invokeLater {
        val frame = JFrame("Generative Weather Ambient & Digital Watercolor")
        val app = GenerativeAtmosphereApp()
        frame.add(app)
        frame.pack()
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE)
        frame.setLocationRelativeTo(null)
        frame.isResizable = false
        frame.isVisible = true
    }
}