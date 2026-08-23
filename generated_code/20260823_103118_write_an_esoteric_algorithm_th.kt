import java.awt.*
import java.awt.event.WindowAdapter
import java.awt.event.WindowEvent
import java.awt.geom.Path2D
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.Random
import javax.sound.sampled.*
import javax.swing.*
import kotlin.concurrent.thread
import kotlin.math.*

// --- Data Models ---
data class SeismicEvent(val magnitude: Double, val depth: Double, val latitude: Double, val longitude: Double)

// --- Audio Synthesizer Engine ---
class TectonicAudioEngine : Thread() {
    @Volatile var running = true
    @Volatile var pressureHarmonicDissonance = 0.5 // Dictates microtonal dissonance
    @Volatile var activityLevel = 0.2 // Dictates soundscape intensity/volume

    private val sampleRate = 44100f
    private var phase1 = 0.0
    private var phase2 = 0.0
    private var phase3 = 0.0

    override fun run() {
        val format = AudioFormat(sampleRate, 16, 1, true, true)
        val line = AudioSystem.getSourceDataLine(format)
        line.open(format, 4096)
        line.start()

        val buffer = ByteArray(2048)
        var bufferIdx = 0

        while (running) {
            // Earth drone frequencies (~55Hz root A1 base)
            val baseFreq = 55.0
            // Pressure modulates second oscillator away from pure harmonic ratio (dissonance)
            val freq1 = baseFreq
            val freq2 = baseFreq * (1.5 + pressureHarmonicDissonance * 0.12) // Detuned fifth
            val freq3 = baseFreq * (2.0 + pressureHarmonicDissonance * 0.25) // Detuned octave

            phase1 += 2.0 * Math.PI * freq1 / sampleRate
            phase2 += 2.0 * Math.PI * freq2 / sampleRate
            phase3 += 2.0 * Math.PI * freq3 / sampleRate

            // Low frequency ambient oscillation
            val lfo = sin(2.0 * Math.PI * 0.1 * (System.currentTimeMillis() / 1000.0))

            val sampleVal = (sin(phase1) * 0.5 + sin(phase2) * 0.3 + sin(phase3) * 0.2) * (0.3 + 0.2 * lfo) * activityLevel
            val sample16 = (sampleVal.coerceIn(-1.0, 1.0) * 32767).toInt()

            buffer[bufferIdx++] = (sample16 shr 8 and 0xFF).toByte()
            buffer[bufferIdx++] = (sample16 and 0xFF).toByte()

            if (bufferIdx >= buffer.size) {
                line.write(buffer, 0, buffer.size)
                bufferIdx = 0
            }
        }
        line.drain()
        line.close()
    }
}

// --- Visual Canvas Engine ---
class InkWashCanvas : JPanel() {
    private val strokes = mutableListOf<StrokeSegment>()
    private val random = Random()

    data class StrokeSegment(val path: Path2D, val alpha: Float, val width: Float)

    init {
        background = Color(245, 242, 235) // Traditional parchment paper tone
    }

    fun addFaultLineStroke(friction: Double, lat: Double, lon: Double) {
        val width = this.width.toDouble().takeIf { it > 0 } ?: 800.0
        val height = this.height.toDouble().takeIf { it > 0 } ?: 600.0

        // Map lat/lon roughly to screen coordinates
        val startX = ((lon + 180.0) / 360.0) * width
        val startY = ((90.0 - lat) / 180.0) * height

        val path = Path2D.Double()
        path.moveTo(startX, startY)

        // Generate organic, fluid calligraphy stroke
        var currentX = startX
        var currentY = startY
        val segments = (10 + friction * 30).toInt()

        for (i in 0 until segments) {
            val angle = random.nextDouble() * 2 * Math.PI
            val stepLength = 5.0 + friction * 15.0 + random.nextGaussian() * 3
            currentX += cos(angle) * stepLength
            currentY += sin(angle) * stepLength
            path.lineTo(currentX, currentY)
        }

        val strokeAlpha = (0.15 + friction * 0.5).coerceIn(0.05, 0.8).toFloat()
        val strokeWidth = (2.0 + friction * 12.0).toFloat()

        synchronized(strokes) {
            strokes.add(StrokeSegment(path, strokeAlpha, strokeWidth))
            if (strokes.size > 120) strokes.removeAt(0) // Fade old strokes
        }
        repaint()
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        val g2d = g as Graphics2D
        g2d.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        synchronized(strokes) {
            for (stroke in strokes) {
                g2d.color = Color(20, 20, 25, (stroke.alpha * 255).toInt())
                g2d.stroke = BasicStroke(stroke.width, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)
                g2d.draw(stroke.path)
            }
        }
    }
}

// --- Live Seismic Sensor Fetcher (USGS Real-time API) ---
object SeismicSensorClient {
    fun fetchLatestSeismicData(): List<SeismicEvent> {
        val events = mutableListOf<SeismicEvent>()
        try {
            val url = URL("[https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson](https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson)")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = 3000
            conn.readTimeout = 3000

            if (conn.responseCode == 200) {
                val stream = conn.inputStream
                val reader = BufferedReader(InputStreamReader(stream))
                val rawJson = reader.readText()
                reader.close()

                // Lightweight regex parsing for zero-dependency native execution
                val magRegex = """"mag":\s*([-+]?\d*\.?\d+)""".toRegex()
                val coordRegex = """"coordinates":\s*\[\s*([-+]?\d*\.?\d+)\s*,\s*([-+]?\d*\.?\d+)\s*,\s*([-+]?\d*\.?\d+)\s*\]""".toRegex()

                val mags = magRegex.findAll(rawJson).map { it.groupValues[1].toDouble() }.toList()
                val coords = coordRegex.findAll(rawJson).map { 
                    Triple(it.groupValues[1].toDouble(), it.groupValues[2].toDouble(), it.groupValues[3].toDouble()) 
                }.toList()

                val count = minOf(mags.size, coords.size)
                for (i in 0 until count) {
                    val mag = maxOf(0.1, mags[i])
                    val (lon, lat, depth) = coords[i]
                    events.add(SeismicEvent(mag, depth, lat, lon))
                }
            }
        } catch (_: Exception) {
            // Fallback synthetic telemetry if offline or rate limited
            val r = Random()
            events.add(SeismicEvent(1.0 + r.nextDouble() * 3.0, 10.0 + r.nextDouble() * 50.0, (r.nextDouble() - 0.5) * 160, (r.nextDouble() - 0.5) * 320))
        }
        return events
    }
}

// --- Main Execution Script ---
fun main() {
    val canvas = InkWashCanvas()
    val frame = JFrame("Esoteric Tectonic Soundscape & Calligraphy")
    frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
    frame.size = Dimension(1024, 768)
    frame.add(canvas)
    frame.setLocationRelativeTo(null)
    frame.isVisible = true

    val audioEngine = TectonicAudioEngine()
    audioEngine.start()

    frame.addWindowListener(object : WindowAdapter() {
        override fun windowClosing(e: WindowEvent?) {
            audioEngine.running = false
        }
    })

    // Real-time atmospheric translation loop
    thread {
        while (audioEngine.running) {
            val seismicEvents = SeismicSensorClient.fetchLatestSeismicData()
            
            if (seismicEvents.isNotEmpty()) {
                val avgMag = seismicEvents.map { it.magnitude }.average()
                val maxDepth = seismicEvents.map { it.depth }.maxOrNull() ?: 1.0

                // Pressure maps directly to harmonic dissonance factor
                audioEngine.pressureHarmonicDissonance = (avgMag / 5.0).coerceIn(0.05, 1.0)
                audioEngine.activityLevel = (0.2 + (avgMag / 10.0)).coerceIn(0.1, 0.8)

                // Generate visual strokes for each seismic event point
                for (event in seismicEvents) {
                    val friction = (event.magnitude * 15.0) / (event.depth + 1.0)
                    SwingUtilities.invokeLater {
                        canvas.addFaultLineStroke(friction.coerceIn(0.1, 1.0), event.latitude, event.longitude)
                    }
                    Thread.sleep(150)
                }
            } else {
                Thread.sleep(2000)
            }
        }
    }
}