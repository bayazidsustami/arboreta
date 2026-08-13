import java.awt.*
import java.awt.event.WindowAdapter
import java.awt.event.WindowEvent
import java.awt.geom.Ellipse2D
import java.util.concurrent.Executors
import java.util.concurrent.ThreadLocalRandom
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import javax.sound.sampled.*
import javax.swing.*
import kotlin.math.*

// Ambient Galaxy Driven by Real Hardware Metrics:
// 1. CPU Clock Timing Jitters -> Drives subtle turbulence, star velocity shifts, and ambient frequency pitch modulation.
// 2. Thread Contention -> Controls central gravitational pull and core density expansion.
// 3. Cache Misses -> Triggers exploding supernovae rings and noise synthesis bursts.

data class Star(
    var x: Double,
    var y: Double,
    var vx: Double,
    var vy: Double,
    var size: Double,
    var hue: Float,
    var brightness: Float
)

data class Supernova(
    var x: Double,
    var y: Double,
    var radius: Double,
    var maxRadius: Double,
    var alpha: Float
)

class GalacticCanvas : JPanel() {
    val stars = MutableList(350) {
        val angle = ThreadLocalRandom.current().nextDouble(0.0, 2 * PI)
        val dist = ThreadLocalRandom.current().nextDouble(30.0, 320.0)
        Star(
            x = dist * cos(angle),
            y = dist * sin(angle),
            vx = -sin(angle) * (1.2 + ThreadLocalRandom.current().nextDouble()),
            vy = cos(angle) * (1.2 + ThreadLocalRandom.current().nextDouble()),
            size = ThreadLocalRandom.current().nextDouble(1.5, 4.5),
            hue = ThreadLocalRandom.current().nextFloat() * 0.25f + 0.55f, // Deep cosmos cyan/violet palette
            brightness = ThreadLocalRandom.current().nextFloat() * 0.5f + 0.5f
        )
    }

    val supernovae = java.util.concurrent.CopyOnWriteArrayList<Supernova>()

    @Volatile var jitterMetric = 0.0
    @Volatile var contentionMetric = 0.0
    @Volatile var cacheMissMetric = 0.0

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        val g2 = g as Graphics2D
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        // Subtle frame-fading creates particle motion trails
        g2.color = Color(6, 6, 16, 45)
        g2.fillRect(0, 0, width, height)

        val centerX = width / 2.0
        val centerY = height / 2.0

        // Gravitational pull scales directly with thread contention intensity
        val gravityStrength = 0.04 + contentionMetric * 0.45

        // Render and update star system physics
        for (star in stars) {
            val dx = -star.x
            val dy = -star.y
            val dist = max(12.0, sqrt(dx * dx + dy * dy))
            val force = gravityStrength / (dist * 0.08)

            // Gravitational vectoring
            star.vx += (dx / dist) * force
            star.vy += (dy / dist) * force

            // Apply CPU timing jitter turbulence
            star.vx += (ThreadLocalRandom.current().nextDouble() - 0.5) * (jitterMetric * 2.5)
            star.vy += (ThreadLocalRandom.current().nextDouble() - 0.5) * (jitterMetric * 2.5)

            star.x += star.vx
            star.y += star.vy

            val screenX = centerX + star.x
            val screenY = centerY + star.y

            val color = Color.getHSBColor(
                (star.hue + (jitterMetric * 0.1f).toFloat()) % 1.0f,
                0.75f,
                star.brightness
            )
            g2.color = color
            g2.fill(Ellipse2D.Double(screenX - star.size / 2, screenY - star.size / 2, star.size, star.size))
        }

        // Draw core galactic black hole / energy core (expands with thread contention)
        val coreRadius = 25.0 + contentionMetric * 110.0
        val coreGlow = RadialGradientPaint(
            Point(centerX.toInt(), centerY.toInt()),
            coreRadius.toFloat().coerceAtLeast(1.0f),
            floatArrayOf(0.0f, 0.4f, 1.0f),
            arrayOf(
                Color(220, 140, 255, 200),
                Color(100, 50, 200, 100),
                Color(6, 6, 16, 0)
            )
        )
        g2.paint = coreGlow
        g2.fill(Ellipse2D.Double(centerX - coreRadius, centerY - coreRadius, coreRadius * 2, coreRadius * 2))

        // Draw expanding supernovae triggered by memory cache misses
        val iterator = supernovae.iterator()
        while (iterator.hasNext()) {
            val nova = iterator.next()
            nova.radius += 2.5 + cacheMissMetric * 8.0
            nova.alpha -= 0.025f

            if (nova.alpha <= 0.0f || nova.radius >= nova.maxRadius) {
                supernovae.remove(nova)
            } else {
                g2.color = Color(1.0f, 0.45f, 0.2f, nova.alpha.coerceIn(0.0f, 1.0f))
                g2.stroke = BasicStroke(2.5f)
                val sx = centerX + nova.x
                val sy = centerY + nova.y
                g2.draw(Ellipse2D.Double(sx - nova.radius, sy - nova.radius, nova.radius * 2, nova.radius * 2))
            }
        }
    }
}

// Low-level audio synthesis generating continuous ambient sound driven by CPU telemetry
class AmbientAudioEngine : Thread() {
    val running = AtomicBoolean(true)
    @Volatile var pitchFreq = 220.0
    @Volatile var noiseLevel = 0.0

    override fun run() {
        val sampleRate = 44100f
        val format = AudioFormat(sampleRate, 8, 1, true, true)
        val line = AudioSystem.getSourceDataLine(format)
        line.open(format, 2048)
        line.start()

        val buffer = ByteArray(512)
        var phase = 0.0

        while (running.get()) {
            val freq = pitchFreq.coerceIn(80.0, 880.0)
            val phaseStep = 2.0 * PI * freq / sampleRate

            for (i in buffer.indices) {
                phase += phaseStep
                val pureTone = sin(phase) * 35.0
                val cacheNoise = (ThreadLocalRandom.current().nextDouble(-1.0, 1.0)) * noiseLevel * 45.0
                buffer[i] = (pureTone + cacheNoise).toInt().coerceIn(-128, 127).toByte()
            }
            line.write(buffer, 0, buffer.size)
            try { sleep(4) } catch (_: Exception) {}
        }
        line.drain()
        line.close()
    }
}

fun main() {
    val frame = JFrame("System Telemetry Galaxy - CPU Jitter, Lock Contention & Cache Misses")
    val canvas = GalacticCanvas()
    canvas.background = Color(6, 6, 16)
    frame.add(canvas)
    frame.setSize(1024, 768)
    frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
    frame.setLocationRelativeTo(null)
    frame.isVisible = true

    val audio = AmbientAudioEngine()
    audio.isDaemon = true
    audio.start()

    val active = AtomicBoolean(true)
    val executor = Executors.newFixedThreadPool(6)

    val contentionLock = Any()
    val cacheArraySize = 8 * 1024 * 1024 // 8MB memory block to induce CPU cache miss thrashing
    val cacheArray = IntArray(cacheArraySize)

    val jitterNs = AtomicLong(0)
    val contentionNs = AtomicLong(0)
    val cacheMissSpikes = AtomicLong(0)

    // Probe 1: System Nano-Clock Timing Jitter Monitor
    executor.submit {
        var lastTime = System.nanoTime()
        while (active.get()) {
            val now = System.nanoTime()
            val delta = now - lastTime
            lastTime = now
            val expectedDelay = 100_000L
            val jitter = abs(delta - expectedDelay)
            jitterNs.set((jitterNs.get() * 0.85 + jitter * 0.15).toLong())
            try { Thread.sleep(0, 100_000) } catch (_: Exception) {}
        }
    }

    // Probe 2 & 3: Thread Lock Contention Simulators
    repeat(2) {
        executor.submit {
            while (active.get()) {
                val start = System.nanoTime()
                synchronized(contentionLock) {
                    val target = System.nanoTime() + ThreadLocalRandom.current().nextLong(30_000, 150_000)
                    while (System.nanoTime() < target) {
                        // Busy-spin holding lock to create contention
                    }
                }
                val waitTime = System.nanoTime() - start
                contentionNs.set((contentionNs.get() * 0.8 + waitTime * 0.2).toLong())
                Thread.yield()
            }
        }
    }

    // Probe 4: Non-sequential Cache Striding Generator & Latency Detector
    executor.submit {
        var pointer = 0
        while (active.get()) {
            val start = System.nanoTime()
            var accumulator = 0
            for (k in 0 until 800) {
                pointer = (pointer + 262147) % cacheArraySize
                accumulator += cacheArray[pointer]
            }
            val elapsed = System.nanoTime() - start
            // Latency spike threshold indicates cache line misses
            if (elapsed > 100_000) {
                cacheMissSpikes.incrementAndGet()
            }
            try { Thread.sleep(2) } catch (_: Exception) {}
        }
    }

    // Main Renderer & Audio Modulation Loop (60 FPS)
    val animationTimer = Timer(16) {
        val currentJitter = (jitterNs.get() / 400_000.0).coerceIn(0.0, 1.0)
        val currentContention = ((contentionNs.get() - 50_000) / 800_000.0).coerceIn(0.0, 1.0)
        val misses = cacheMissSpikes.getAndSet(0)

        canvas.jitterMetric = currentJitter
        canvas.contentionMetric = currentContention
        canvas.cacheMissMetric = (misses / 4.0).coerceIn(0.0, 1.0)

        // Spawn Supernovae on cache miss events
        if (misses > 0) {
            val angle = ThreadLocalRandom.current().nextDouble(0.0, 2 * PI)
            val dist = ThreadLocalRandom.current().nextDouble(40.0, 280.0)
            canvas.supernovae.add(
                Supernova(
                    x = dist * cos(angle),
                    y = dist * sin(angle),
                    radius = 4.0,
                    maxRadius = 60.0 + misses * 15.0,
                    alpha = 0.95f
                )
            )
        }

        // Modulate synth audio based on real hardware state
        audio.pitchFreq = 180.0 + currentContention * 320.0 + currentJitter * 120.0
        audio.noiseLevel = canvas.cacheMissMetric

        canvas.repaint()
    }
    animationTimer.start()

    frame.addWindowListener(object : WindowAdapter() {
        override fun windowClosing(e: WindowEvent?) {
            active.set(false)
            audio.running.set(false)
            executor.shutdownNow()
        }
    })
}