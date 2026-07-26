import com.sun.management.GarbageCollectionNotificationInfo
import java.awt.Color
import java.awt.Dimension
import java.awt.Graphics
import java.awt.Graphics2D
import java.awt.RenderingHints
import java.lang.management.ManagementFactory
import java.util.concurrent.CopyOnWriteArrayList
import javax.management.NotificationListener
import javax.management.openmbean.CompositeData
import javax.sound.sampled.AudioFormat
import javax.sound.sampled.AudioSystem
import javax.swing.JFrame
import javax.swing.JPanel
import javax.swing.SwingUtilities
import javax.swing.Timer
import kotlin.concurrent.thread
import kotlin.math.PI
import kotlin.math.sin

/**
 * Generative Star Chart & Microtonal Audio Synthesizer driven by JVM GC Events.
 * 
 * - Listens for Garbage Collection notifications via JMX.
 * - Derives 2D cosmic coordinates and microtonal audio frequencies from freed byte sizes.
 * - Renders decaying, fading stars on a dark canvas while emitting dynamic sine wave tones.
 * - Continuously allocates garbage objects to sustain the cycle.
 */

data class Star(
    val x: Int,
    val y: Int,
    val initialSize: Float,
    val color: Color,
    val frequency: Double,
    var opacity: Float = 1.0f
)

class CosmosCanvas : JPanel() {
    val stars = CopyOnWriteArrayList<Star>()

    init {
        preferredSize = Dimension(900, 700)
        background = Color(10, 10, 22)
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        val g2d = g as Graphics2D
        g2d.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        for (star in stars) {
            val alpha = (star.opacity.coerceIn(0f, 1f) * 255).toInt()
            if (alpha <= 0) continue

            // Render glowing star core and outer corona
            val size = star.initialSize * star.opacity
            val renderColor = Color(star.color.red, star.color.green, star.color.blue, alpha)
            
            g2d.color = Color(star.color.red, star.color.green, star.color.blue, alpha / 4)
            g2d.fillOval((star.x - size).toInt(), (star.y - size).toInt(), (size * 2).toInt(), (size * 2).toInt())

            g2d.color = renderColor
            g2d.fillOval((star.x - size / 2).toInt(), (star.y - size / 2).toInt(), size.toInt(), size.toInt())
        }
    }
}

class MicrotonalAudioEngine {
    private val sampleRate = 44100f
    private val format = AudioFormat(sampleRate, 8, 1, true, true)
    private val line = AudioSystem.getSourceDataLine(format)

    init {
        line.open(format, 44100)
        line.start()
    }

    // Play a microtonal sine tone based on exact byte frequency
    fun playTone(freq: Double, durationMs: Int) {
        thread(isDaemon = true) {
            val numSamples = (sampleRate * durationMs / 1000).toInt()
            val buffer = ByteArray(numSamples)
            for (i in 0 until numSamples) {
                val angle = 2.0 * PI * i / (sampleRate / freq)
                val envelope = 1.0 - (i.toDouble() / numSamples) // Linear fade out
                buffer[i] = (sin(angle) * 127 * envelope).toInt().toByte()
            }
            line.write(buffer, 0, buffer.size)
        }
    }
}

fun main() {
    val canvas = CosmosCanvas()
    val audio = MicrotonalAudioEngine()

    // Setup GUI
    SwingUtilities.invokeLater {
        val frame = JFrame("GC Microtonal Star Chart")
        frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
        frame.add(canvas)
        frame.pack()
        frame.setLocationRelativeTo(null)
        frame.isVisible = true
    }

    // Capture JVM Garbage Collection Notifications
    val gcBeans = ManagementFactory.getGarbageCollectorMXBeans()
    val gcListener = NotificationListener { notification, _ ->
        if (notification.type == GarbageCollectionNotificationInfo.GARBAGE_COLLECTION_NOTIFICATION) {
            val info = GarbageCollectionNotificationInfo.from(notification.userData as CompositeData)
            val gcInfo = info.gcInfo ?: return@NotificationListener

            // Calculate total bytes reclaimed during this GC cycle
            var freedBytes = 0L
            val before = gcInfo.memoryUsageBeforeGc
            val after = gcInfo.memoryUsageAfterGc
            for ((key, usageBefore) in before) {
                val usageAfter = after[key]
                if (usageAfter != null) {
                    freedBytes += (usageBefore.used - usageAfter.used).coerceAtLeast(0)
                }
            }

            if (freedBytes > 0) {
                // Map byte size to 2D Star Chart coordinates and microtonal audio frequency
                val hash = freedBytes.hashCode()
                val x = Math.abs(hash % (canvas.width.takeIf { it > 0 } ?: 900))
                val y = Math.abs((hash / 31) % (canvas.height.takeIf { it > 0 } ?: 700))
                val starSize = (freedBytes % 30 + 10).toFloat()

                // Microtonal pitch continuum (200Hz - 1200Hz based on memory byte size)
                val microtonalFreq = 200.0 + (freedBytes % 10000000L) / 10000000.0 * 1000.0

                // Assign cosmic spectrum colors based on frequency
                val hue = (microtonalFreq / 1200.0).toFloat()
                val color = Color.getHSBColor(hue, 0.8f, 1.0f)

                val newStar = Star(x, y, starSize, color, microtonalFreq)
                canvas.stars.add(newStar)

                // Emit audio frequency for the dying memory state
                audio.playTone(microtonalFreq, 300)
            }
        }
    }

    // Register GC listener to all GC MXBeans
    for (gcBean in gcBeans) {
        val emitter = gcBean as javax.management.NotificationEmitter
        emitter.addNotificationListener(gcListener, null, null)
    }

    // Render loop: Decaying stars gradually fade out and vanish
    Timer(33) {
        val iterator = canvas.stars.iterator()
        while (iterator.hasNext()) {
            val star = iterator.next()
            star.opacity -= 0.015f
            if (star.opacity <= 0f) {
                canvas.stars.remove(star)
            }
        }
        canvas.repaint()
    }.start()

    // Memory Pressure Generator: continuously allocate objects to trigger GC
    thread(isDaemon = true) {
        val memoryTrash = mutableListOf<ByteArray>()
        while (true) {
            memoryTrash.add(ByteArray(1024 * 64)) // Allocate 64KB chunks
            if (memoryTrash.size > 200) {
                memoryTrash.clear() // Drop references to trigger GC sweep
                System.gc()
            }
            Thread.sleep(20)
        }
    }
}