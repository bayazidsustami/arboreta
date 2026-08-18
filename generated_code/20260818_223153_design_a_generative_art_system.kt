import java.awt.*
import java.awt.event.*
import java.awt.geom.*
import java.awt.image.BufferedImage
import java.io.InputStream
import java.net.URL
import java.util.concurrent.ConcurrentLinkedQueue
import javax.sound.midi.*
import javax.swing.*
import kotlin.math.*
import kotlin.random.Random

// Represents a network packet with simulated metadata
data class NetworkPacket(
    val protocol: Protocol,
    val size: Int,
    val srcPort: Int,
    val dstPort: Int
)

enum class Protocol(
    val title: String,
    val basePitch: Int, // MIDI note number
    val chordIntervals: List<Int>,
    val colorPalette: List<Color>
) {
    HTTP(
        "HTTP/HTTPS",
        60, // C4
        listOf(0, 4, 7, 11), // Major 7th
        listOf(Color(0xFF, 0x6B, 0x6B), Color(0xFF, 0x8E, 0x72), Color(0xFF, 0xD1, 0x66), Color(0xF4, 0xA2, 0x61))
    ),
    DNS(
        "DNS",
        62, // D4
        listOf(0, 3, 7, 10), // Minor 7th
        listOf(Color(0x4E, 0xCD, 0xC4), Color(0x45, 0xB7, 0xD1), Color(0x2A, 0x9D, 0x8F), Color(0x26, 0x46, 0x53))
    ),
    SSH(
        "SSH",
        57, // A3
        listOf(0, 3, 7, 14), // Minor add9
        listOf(Color(0x9B, 0x51, 0xE0), Color(0xBB, 0x6B, 0xD9), Color(0x6C, 0x5C, 0xE7), Color(0x3A, 0x0C, 0xA3))
    ),
    UDP(
        "UDP/Streaming",
        65, // F4
        listOf(0, 5, 7, 12), // Sus4 / Stacked 5ths
        listOf(Color(0x06, 0xD6, 0xA0), Color(0x11, 0x8A, 0xB2), Color(0x07, 0x3B, 0x4C), Color(0x00, 0xBB, 0xF9))
    ),
    ICMP(
        "ICMP/Ping",
        72, // C5
        listOf(0, 7, 12, 19), // Open fifths / octaves
        listOf(Color(0xFC, 0xBF, 0x49), Color(0xEA, 0x5C, 0x2B), Color(0xFF, 0xDE, 0x59), Color(0xE7, 0x6F, 0x51))
    )
}

// Voronoi Cell representing a pane of stained glass
class StainedGlassPane(
    var x: Double,
    var y: Double,
    val protocol: Protocol
) {
    var vx: Double = Random.nextDouble(-0.5, 0.5)
    var vy: Double = Random.nextDouble(-0.5, 0.5)
    var energy: Double = 1.0 // Energy/brightness from traffic hits
    var baseColor: Color = protocol.colorPalette.random()
    var targetColor: Color = baseColor

    fun update(boundsWidth: Int, boundsHeight: Int) {
        x += vx
        y += vy

        // Bounce off walls
        if (x < 0 || x > boundsWidth) { vx *= -1; x = x.coerceIn(0.0, boundsWidth.toDouble()) }
        if (y < 0 || y > boundsHeight) { vy *= -1; y = y.coerceIn(0.0, boundsHeight.toDouble()) }

        // Decay energy back to ambient state
        energy = max(0.2, energy * 0.985)
    }

    fun trigger(packetSize: Int) {
        energy = min(2.5, energy + (packetSize / 400.0) + 0.5)
        targetColor = protocol.colorPalette.random()
    }

    fun getCurrentColor(): Color {
        val r = (baseColor.red * 0.9 + targetColor.red * 0.1).toInt()
        val g = (baseColor.green * 0.9 + targetColor.green * 0.1).toInt()
        val b = (baseColor.blue * 0.9 + targetColor.blue * 0.1).toInt()
        baseColor = Color(r, g, b)

        // Apply energy scale
        val er = min(255, (baseColor.red * energy).toInt())
        val eg = min(255, (baseColor.green * energy).toInt())
        val eb = min(255, (baseColor.blue * energy).toInt())
        return Color(er, eg, eb)
    }
}

// Generates live network activity via real outbound pings + synthetic ambient traffic
class NetworkTrafficMonitor(private val onPacketReceived: (NetworkPacket) -> Unit) {
    private var running = true

    fun start() {
        // Thread 1: Real HTTP / Network requests (Pings)
        Thread {
            val urls = listOf("[https://1.1.1.1](https://1.1.1.1)", "[https://google.com](https://google.com)", "[https://wikipedia.org](https://wikipedia.org)")
            var idx = 0
            while (running) {
                try {
                    val url = URL(urls[idx % urls.size])
                    val start = System.currentTimeMillis()
                    val connection = url.openConnection()
                    connection.connectTimeout = 1000
                    connection.readTimeout = 1000
                    val stream: InputStream = connection.getInputStream()
                    val size = stream.readBytes().size.coerceAtLeast(64)
                    stream.close()
                    val latency = (System.currentTimeMillis() - start).toInt()

                    val packet = NetworkPacket(Protocol.HTTP, size, 443, 50000 + latency % 10000)
                    onPacketReceived(packet)
                } catch (_: Exception) {
                    // Fallback packet if offline
                    onPacketReceived(NetworkPacket(Protocol.ICMP, 64, 0, 0))
                }
                idx++
                Thread.sleep(1500)
            }
        }.start()

        // Thread 2: Simulated local network traffic streams (SSH, DNS, UDP, ICMP)
        Thread {
            while (running) {
                val proto = Protocol.values().random()
                val size = Random.nextInt(64, 1500)
                val packet = NetworkPacket(proto, size, Random.nextInt(1024, 65535), proto.basePitch)
                onPacketReceived(packet)

                val delay = when (proto) {
                    Protocol.DNS -> Random.nextLong(200, 800)
                    Protocol.UDP -> Random.nextLong(50, 200)
                    Protocol.SSH -> Random.nextLong(400, 1200)
                    else -> Random.nextLong(100, 500)
                }
                Thread.sleep(delay)
            }
        }.start()
    }

    fun stop() {
        running = false
    }
}

// Interactive Audio Engine driving Midi synthesis
class AudioEngine {
    private var synthesizer: Synthesizer? = null
    private var channels: Array<MidiChannel>? = null

    init {
        try {
            synthesizer = MidiSystem.getSynthesizer().apply {
                open()
                this@AudioEngine.channels = channels
            }
            // Set sound preset to Warm/Church Organ or Choir-like sound on channel 0
            channels?.get(0)?.programChange(19) // Church Organ
            channels?.get(1)?.programChange(88) // Synth Pad
        } catch (e: Exception) {
            println("MIDI Unavailable: ${e.message}")
        }
    }

    fun playChord(protocol: Protocol, packetSize: Int) {
        val ch = channels?.get(0) ?: return
        val velocity = min(127, 40 + packetSize / 15)

        // Arpeggiate harmonic chord based on protocol map
        Thread {
            protocol.chordIntervals.forEach { interval ->
                val note = protocol.basePitch + interval
                ch.noteOn(note, velocity)
                Thread.sleep(60)
            }
            Thread.sleep(300)
            protocol.chordIntervals.forEach { interval ->
                val note = protocol.basePitch + interval
                ch.noteOff(note)
            }
        }.start()
    }
}

// Main Window & Interactive Graphics Rendering
class StainedGlassWindow : JFrame("Generative Network Stained-Glass Visualizer") {
    private val width = 1000
    private val height = 800
    private val panes = mutableListOf<StainedGlassPane>()
    private val packetQueue = ConcurrentLinkedQueue<NetworkPacket>()
    private val audioEngine = AudioEngine()
    private val networkMonitor = NetworkTrafficMonitor { packetQueue.add(it) }

    // Interactive mouse pulse state
    private var mouseX = -1000
    private var mouseY = -1000

    init {
        defaultCloseOperation = EXIT_ON_CLOSE
        setSize(width, height)
        isResizable = false
        setLocationRelativeTo(null)

        // Seed Voronoi centers for glass panes mapped across protocols
        val protocols = Protocol.values()
        repeat(60) {
            val proto = protocols[it % protocols.size]
            panes.add(
                StainedGlassPane(
                    Random.nextDouble(0.0, width.toDouble()),
                    Random.nextDouble(0.0, height.toDouble()),
                    proto
                )
            )
        }

        val canvas = GlassCanvas()
        add(canvas)

        // Interaction Listeners
        canvas.addMouseMotionListener(object : MouseMotionAdapter() {
            override fun mouseMoved(e: MouseEvent) {
                mouseX = e.x
                mouseY = e.y
            }
        })

        canvas.addMouseListener(object : MouseAdapter() {
            override fun mousePressed(e: MouseEvent) {
                // Simulate an intensive packet burst on click
                val packet = NetworkPacket(Protocol.values().random(), 1400, e.x, e.y)
                packetQueue.add(packet)
            }
        })

        networkMonitor.start()

        // Main Render Loop (~60 FPS)
        Timer(16) {
            processPackets()
            panes.forEach { it.update(width, height) }
            canvas.repaint()
        }.start()
    }

    private fun processPackets() {
        while (!packetQueue.isEmpty()) {
            val packet = packetQueue.poll() ?: break
            // Trigger audio response
            audioEngine.playChord(packet.protocol, packet.size)

            // Find nearest matching glass pane and excite it
            panes.filter { it.protocol == packet.protocol }
                .minByOrNull { pane -> (pane.x - mouseX).pow(2) + (pane.y - mouseY).pow(2) }
                ?.trigger(packet.size)
                ?: panes.random().trigger(packet.size)
        }
    }

    inner class GlassCanvas : JPanel() {
        override fun paintComponent(g: Graphics) {
            super.paintComponent(g)
            val g2 = g as Graphics2D
            g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

            val img = BufferedImage(width, height, BufferedImage.TYPE_INT_RGB)

            // Render Voronoi Stained Glass geometry pixel map
            // Optimized distance calculation via pixel grid sampling
            val gridStep = 4
            for (x in 0 until width step gridStep) {
                for (y in 0 until height step gridStep) {
                    var minDist = Double.MAX_VALUE
                    var secondMinDist = Double.MAX_VALUE
                    var closestPane = panes[0]

                    for (pane in panes) {
                        val dx = x - pane.x
                        val dy = y - pane.y
                        val dist = dx * dx + dy * dy
                        if (dist < minDist) {
                            secondMinDist = minDist
                            minDist = dist
                            closestPane = pane
                        } else if (dist < secondMinDist) {
                            secondMinDist = dist
                        }
                    }

                    // Lead framing effect (dark borders between Voronoi cells)
                    val edgeThreshold = sqrt(secondMinDist) - sqrt(minDist)
                    val color = if (edgeThreshold < 2.5) {
                        Color(20, 20, 25) // Lead solder line
                    } else {
                        // Apply light dispersion and vignette outwards
                        val base = closestPane.getCurrentColor()
                        val distFromCenter = sqrt((x - width / 2.0).pow(2) + (y - height / 2.0).pow(2))
                        val vignette = max(0.5, 1.0 - (distFromCenter / (width * 0.7)))
                        Color(
                            (base.red * vignette).toInt().coerceIn(0, 255),
                            (base.green * vignette).toInt().coerceIn(0, 255),
                            (base.blue * vignette).toInt().coerceIn(0, 255)
                        )
                    }

                    for (dx in 0 until gridStep) {
                        for (dy in 0 until gridStep) {
                            if (x + dx < width && y + dy < height) {
                                img.setRGB(x + dx, y + dy, color.rgb)
                            }
                        }
                    }
                }
            }

            g2.drawImage(img, 0, 0, null)

            // Draw Interactive Mouse Halo Light
            if (mouseX in 0..width && mouseY in 0..height) {
                val radialGrad = RadialGradientPaint(
                    Point2D.Float(mouseX.toFloat(), mouseY.toFloat()),
                    150f,
                    floatArrayOf(0.0f, 1.0f),
                    arrayOf(Color(255, 255, 255, 80), Color(255, 255, 255, 0))
                )
                g2.paint = radialGrad
                g2.fillOval(mouseX - 150, mouseY - 150, 300, 300)
            }

            // Draw HUD Legend Overlay
            g2.color = Color(0, 0, 0, 180)
            g2.fillRoundRect(15, 15, 220, 140, 15, 15)
            g2.color = Color.WHITE
            g2.setFont(Font("SansSerif", Font.BOLD, 12))
            g2.drawString("LIVE NETWORK SPECTRUM", 25, 35)

            Protocol.values().forEachIndexed { index, proto ->
                g2.color = proto.colorPalette[0]
                g2.fillRect(25, 50 + index * 18, 12, 12)
                g2.color = Color.LIGHT_GRAY
                g2.setFont(Font("SansSerif", Font.PLAIN, 11))
                g2.drawString(proto.title, 45, 61 + index * 18)
            }
        }
    }
}

fun main() {
    SwingUtilities.invokeLater {
        val frame = StainedGlassWindow()
        frame.isVisible = true
    }
}