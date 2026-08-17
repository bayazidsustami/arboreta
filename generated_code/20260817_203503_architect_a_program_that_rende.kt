import java.awt.Canvas
import java.awt.Color
import java.awt.Dimension
import java.awt.Graphics2D
import java.awt.RenderingHints
import java.awt.event.WindowAdapter
import java.awt.event.WindowEvent
import java.awt.image.BufferedImage
import java.lang.management.ManagementFactory
import java.lang.management.MemoryMXBean
import java.lang.ref.SoftReference
import java.lang.ref.WeakReference
import java.util.concurrent.CopyOnWriteArrayList
import javax.swing.JFrame
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.random.Random

// --- Domain Models ---

data class Star(
    val id: Int,
    var x: Double,
    var y: Double,
    var vx: Double,
    var vy: Double,
    var weightBytes: Long,
    var brightness: Float = 0.2f,
    var radius: Float = 3f,
    val color: Color = Color(
        Random.nextInt(150, 255),
        Random.nextInt(180, 255),
        Random.nextInt(200, 255)
    )
)

data class Particle(
    var x: Double,
    var y: Double,
    var vx: Double,
    var vy: Double,
    var life: Float = 1.0f,
    val color: Color
)

// --- Memory Simulator & Leak Engine ---

class MemoryEngine(private val canvasWidth: Int, private val canvasHeight: Int) {
    val stars = CopyOnWriteArrayList<Star>()
    val particles = CopyOnWriteArrayList<Particle>()
    val leakedObjects = mutableListOf<ByteArray>() // Intentional memory leak retainer
    
    private var nextStarId = 0
    private val memoryBean: MemoryMXBean = ManagementFactory.getMemoryMXBean()
    private var lastHeapUsed: Long = memoryBean.heapMemoryUsage.used
    
    // Create an initial galaxy of memory pointers
    init {
        repeat(25) { spawnStar() }
    }

    fun spawnStar() {
        val margin = 100.0
        val x = Random.nextDouble(margin, canvasWidth - margin)
        val y = Random.nextDouble(margin, canvasHeight - margin)
        val star = Star(
            id = nextStarId++,
            x = x,
            y = y,
            vx = Random.nextDouble(-0.3, 0.3),
            vy = Random.nextDouble(-0.3, 0.3),
            weightBytes = Random.nextLong(1024 * 100, 1024 * 1024)
        )
        stars.add(star)
    }

    fun simulateLeak() {
        // Allocate uncollected memory blocks to simulate a leaking application
        val leakSize = Random.nextInt(1024 * 50, 1024 * 400)
        leakedObjects.add(ByteArray(leakSize))

        // Distribute leaked bytes across existing stars, growing them brighter & larger
        if (stars.isNotEmpty()) {
            val targetStar = stars[Random.nextInt(stars.size)]
            targetStar.weightBytes += leakSize
            targetStar.brightness = min(1.0f, targetStar.brightness + 0.05f)
            targetStar.radius = min(35f, 3f + (targetStar.weightBytes / (1024f * 1024f)) * 3f)
        }

        // Randomly spawn new memory pointers (stars) as memory grows
        if (Random.nextDouble() < 0.3 && stars.size < 60) {
            spawnStar()
        }
    }

    fun update() {
        val currentHeap = memoryBean.heapMemoryUsage.used
        val deltaMemory = currentHeap - lastHeapUsed

        // Detect Garbage Collection (Heap drastically dropped) -> Supernova Trigger
        if (deltaMemory < -1024 * 1024 * 2) { 
            triggerSupernova()
        }
        lastHeapUsed = currentHeap

        // Orbital Motion & Physics
        val cx = canvasWidth / 2.0
        val cy = canvasHeight / 2.0
        for (star in stars) {
            // Subtle gravitational pull toward center to keep constellation cohesive
            val dx = cx - star.x
            val dy = cy - star.y
            val dist = max(10.0, sqrt(dx * dx + dy * dy))
            star.vx += (dx / dist) * 0.01
            star.vy += (dy / dist) * 0.01

            star.x += star.vx
            star.y += star.vy

            // Soft wall bounces
            if (star.x < 50 || star.x > canvasWidth - 50) star.vx *= -0.8
            if (star.y < 50 || star.y > canvasHeight - 50) star.vy *= -0.8
        }

        // Update Nova Particles
        val iterator = particles.iterator()
        while (iterator.hasNext()) {
            val p = iterator.next()
            p.x += p.vx
            p.y += p.vy
            p.life -= 0.02f
            if (p.life <= 0f) {
                particles.remove(p)
            }
        }
    }

    fun triggerSupernova() {
        // Clear simulated leaks and collapse brightest stars into supernova particles
        leakedObjects.clear()
        
        val supernovas = stars.filter { it.radius > 8f }
        for (star in supernovas) {
            repeat(40) {
                val angle = Random.nextDouble(0.0, Math.PI * 2)
                val speed = Random.nextDouble(1.0, 8.0)
                particles.add(
                    Particle(
                        x = star.x,
                        y = star.y,
                        vx = cos(angle) * speed,
                        vy = sin(angle) * speed,
                        life = 1.0f,
                        color = star.color
                    )
                )
            }
            stars.remove(star)
        }

        // Replenish stars if population gets too low
        while (stars.size < 15) {
            spawnStar()
        }
    }

    fun forceGC() {
        System.gc()
    }
}

// --- Visual Constellation Rendering Canvas ---

class ConstellationCanvas(
    private val widthPx: Int,
    private val heightPx: Int,
    private val engine: MemoryEngine
) : Canvas() {

    init {
        preferredSize = Dimension(widthPx, heightPx)
        background = Color(8, 10, 20)
    }

    fun render() {
        val bs = bufferStrategy
        if (bs == null) {
            createBufferStrategy(2)
            return
        }

        val g = bs.drawGraphics as Graphics2D
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        // Dark sky backdrop with slight trail persistence
        g.color = Color(8, 10, 22, 220)
        g.fillRect(0, 0, widthPx, heightPx)

        val stars = engine.stars

        // 1. Draw Constellation Edges (Pointers / References connecting active memory)
        val maxDist = 180.0
        for (i in 0 until stars.size) {
            for (j in i + 1 until stars.size) {
                val s1 = stars[i]
                val s2 = stars[j]
                val dx = s1.x - s2.x
                val dy = s1.y - s2.y
                val dist = sqrt(dx * dx + dy * dy)

                if (dist < maxDist) {
                    val alpha = ((1.0 - (dist / maxDist)) * 180).toInt().coerceIn(0, 255)
                    // Edge weight correlates with memory density between nodes
                    val connectionWeight = min(s1.brightness, s2.brightness)
                    g.color = Color(100, 180, 255, alpha)
                    g.stroke = java.awt.BasicStroke(0.5f + connectionWeight * 1.5f)
                    g.drawLine(s1.x.toInt(), s1.y.toInt(), s2.x.toInt(), s2.y.toInt())
                }
            }
        }

        // 2. Draw Stars (Active Pointers / Objects growing brighter with leaks)
        for (star in stars) {
            val r = star.radius
            val x = (star.x - r).toInt()
            val y = (star.y - r).toInt()
            val diameter = (r * 2).toInt()

            // Outer Glow Aura
            val glowRadius = r * 3f
            val glowX = (star.x - glowRadius).toInt()
            val glowY = (star.y - glowRadius).toInt()
            val glowDiam = (glowRadius * 2).toInt()
            val glowAlpha = (star.brightness * 60).toInt().coerceIn(0, 255)

            g.color = Color(star.color.red, star.color.green, star.color.blue, glowAlpha)
            g.fillOval(glowX, glowY, glowDiam, glowDiam)

            // Inner Core Star
            g.color = star.color
            g.fillOval(x, y, diameter, diameter)

            // Dynamic Bright Core center
            g.color = Color.WHITE
            val coreSize = max(2f, r * 0.4f).toInt()
            g.fillOval((star.x - coreSize / 2).toInt(), (star.y - coreSize / 2).toInt(), coreSize, coreSize)
        }

        // 3. Draw Supernova Explosion Particles (GC Event VFX)
        for (p in engine.particles) {
            val alpha = (p.life * 255).toInt().coerceIn(0, 255)
            g.color = Color(p.color.red, p.color.green, p.color.blue, alpha)
            val pSize = max(2, (p.life * 6).toInt())
            g.fillOval(p.x.toInt(), p.y.toInt(), pSize, pSize)
        }

        // 4. Interface Readout / Real-time Telemetry Overlay
        val runtime = Runtime.getRuntime()
        val usedMB = (runtime.totalMemory() - runtime.freeMemory()) / (1024 * 1024)
        val maxMB = runtime.maxMemory() / (1024 * 1024)

        g.color = Color(200, 220, 255, 200)
        g.font = g.font.deriveFont(12f)
        g.drawString("ACTIVE MEMORY NODES (POINTERS): ${stars.size}", 20, 30)
        g.drawString("HEAP USAGE: $usedMB MB / $maxMB MB", 20, 50)
        g.drawString("STATUS: ${if (usedMB > maxMB * 0.7) "CRITICAL LEAK (SUPERNOVA IMMINENT)" else "MONITORING LEAKS..."}", 20, 70)
        g.drawString("[CLICK CANVAS TO TRIGGER MANUAL GC SUPERNOVA]", 20, 90)

        g.dispose()
        bs.show()
    }
}

// --- Application Entry Point ---

fun main() {
    val width = 1000
    val height = 750

    val engine = MemoryEngine(width, height)

    val frame = JFrame("Memory Leak Constellation Map - Real-Time Visualizer")
    val canvas = ConstellationCanvas(width, height, engine)

    frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
    frame.isResizable = false
    frame.add(canvas)
    frame.pack()
    frame.setLocationRelativeTo(null)
    frame.isVisible = true

    // Click canvas to trigger GC supernova intentionally
    canvas.addMouseListener(object : java.awt.event.MouseAdapter() {
        override fun mouseClicked(e: java.awt.event.MouseEvent?) {
            engine.forceGC()
        }
    })

    // Main Engine Loop Thread
    val appThread = Thread {
        var lastLeakTick = System.currentTimeMillis()

        while (frame.isVisible) {
            // Continuously update dynamic system physics
            engine.update()

            // Inject artificial memory leak periodically
            if (System.currentTimeMillis() - lastLeakTick > 150) {
                engine.simulateLeak()
                lastLeakTick = System.currentTimeMillis()
            }

            // Render frame
            canvas.render()

            try {
                Thread.sleep(16) // ~60 FPS update cycle
            } catch (e: InterruptedException) {
                break
            }
        }
    }

    appThread.isDaemon = true
    appThread.start()
}