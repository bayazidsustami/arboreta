import java.awt.Color
import java.awt.Dimension
import java.awt.Graphics
import java.awt.Graphics2D
import java.awt.RenderingHints
import java.awt.event.KeyAdapter
import java.awt.event.KeyEvent
import java.awt.image.BufferedImage
import javax.swing.JFrame
import javax.swing.JPanel
import javax.swing.SwingUtilities
import javax.swing.Timer
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

// Represents an active ripple propagating through the fractal visualization
data class Ripple(val x: Double, val y: Double, var radius: Double = 0.0, var amplitude: Double = 1.0)

// Simulated byte modification in system memory
data class MemoryMutation(val address: Int, val value: Byte)

class MemoryFractalVisualizer : JPanel() {
    private val widthPx = 800
    private val heightPx = 800
    private val maxIterations = 32
    
    // Simulated system memory buffer (64 KB)
    private val memorySize = 65536
    private val memory = ByteArray(memorySize)
    
    // Concurrency-safe active ripples list
    @Volatile
    private var ripples = mutableListOf<Ripple>()
    
    // Offscreen render buffer for real-time fractal drawing
    private val buffer = BufferedImage(widthPx, heightPx, BufferedImage.TYPE_INT_RGB)
    
    init {
        preferredSize = Dimension(widthPx, heightPx)
        isFocusable = true
        
        // Randomize initial memory allocations
        Random.nextBytes(memory)
        
        // Key listener: Manual memory write on any key press
        addKeyListener(object : KeyAdapter() {
            override fun keyPressed(e: KeyEvent) {
                val addr = Random.nextInt(memorySize)
                val valByte = Random.nextInt(-128, 127).toByte()
                triggerMemoryAllocationChange(MemoryMutation(addr, valByte))
            }
        })

        // Background thread: Continuous random memory allocations & mutations
        Thread {
            while (true) {
                Thread.sleep(80)
                val addr = Random.nextInt(memorySize)
                val valByte = Random.nextInt(-128, 127).toByte()
                triggerMemoryAllocationChange(MemoryMutation(addr, valByte))
            }
        }.start()

        // Main render loop (~60 FPS)
        Timer(16) {
            updateRipples()
            renderFractalMap()
            repaint()
        }.start()
    }

    // Handles byte modifications and translates memory offset to 2D complex plane coordinates
    private fun triggerMemoryAllocationChange(mutation: MemoryMutation) {
        memory[mutation.address] = mutation.value
        
        // Map memory address space (0 to 65535) into complex space [-2.0, 2.0]
        val normalizedAddr = mutation.address.toDouble() / memorySize
        val cx = -2.0 + 4.0 * normalizedAddr
        val cy = sin(normalizedAddr * Math.PI * 2.0) * 1.5
        
        // Spawn reverberating ripple from memory modification point
        synchronized(ripples) {
            ripples.add(Ripple(cx, cy, radius = 0.0, amplitude = (mutation.value.toInt() and 0xFF) / 255.0))
        }
    }

    // Expands and decays ripples over time
    private fun updateRipples() {
        synchronized(ripples) {
            val iterator = ripples.iterator()
            while (iterator.hasNext()) {
                val r = iterator.next()
                r.radius += 0.04
                r.amplitude *= 0.96 // Dampen amplitude
                if (r.amplitude < 0.02 || r.radius > 5.0) {
                    iterator.remove()
                }
            }
        }
    }

    // Renders the fractal memory map combined with dynamic ripple wave fields
    private fun renderFractalMap() {
        val currentRipples = synchronized(ripples) { ripples.toList() }
        
        // Compute memory activity hash to dynamically morph the Julia set constant
        var memSum = 0
        for (i in 0 until 1024) { memSum += memory[i * 64].toInt() and 0xFF }
        val memoryFactor = memSum / 1024.0 / 255.0
        
        val baseCr = -0.7 + (memoryFactor * 0.1)
        val baseCi = 0.27015 + (memoryFactor * 0.05)

        for (py in 0 until heightPx) {
            val zi0 = -1.5 + (3.0 * py / heightPx)
            for (px in 0 until widthPx) {
                val zr0 = -1.5 + (3.0 * px / widthPx)

                // Calculate cumulative reverberating wave displacement from memory mutations
                var waveEffect = 0.0
                for (r in currentRipples) {
                    val dx = zr0 - r.x
                    val dy = zi0 - r.y
                    val dist = Math.sqrt(dx * dx + dy * dy)
                    val wave = sin((dist - r.radius) * 12.0) * r.amplitude
                    val factor = 1.0 / (1.0 + abs(dist - r.radius) * 5.0)
                    waveEffect += wave * factor
                }

                // Perturb Julia constant dynamically with memory ripples
                var zr = zr0
                var zi = zi0
                val cr = baseCr + waveEffect * 0.08
                val ci = baseCi + waveEffect * 0.08

                var iter = 0
                while (zr * zr + zi * zi < 4.0 && iter < maxIterations) {
                    val temp = zr * zr - zi * zi + cr
                    zi = 2.0 * zr * zi + ci
                    zr = temp
                    iter++
                }

                // Generative procedural palette based on fractal iterations and memory ripples
                val colorInt = if (iter == maxIterations) {
                    0x050510
                } else {
                    val t = iter.toDouble() / maxIterations
                    val r = (sin(t * 10.0 + waveEffect) * 127 + 128).toInt().coerceIn(0, 255)
                    val g = (cos(t * 8.0 - waveEffect) * 127 + 128).toInt().coerceIn(0, 255)
                    val b = (sin(t * 15.0) * 127 + 128).toInt().coerceIn(0, 255)
                    (r shl 16) or (g shl 8) or b
                }
                
                buffer.setRGB(px, py, colorInt)
            }
        }
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        val g2d = g as Graphics2D
        g2d.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)
        
        // Draw the generative fractal buffer
        g2d.drawImage(buffer, 0, 0, null)
        
        // Overlay diagnostic interface text
        g2d.color = Color(0, 255, 180, 200)
        g2d.drawString("FRACTAL MEMORY MAP INTERPRETER", 20, 30)
        g2d.drawString("Active Reverberations: ${ripples.size}", 20, 50)
        g2d.drawString("Press ANY KEY to manually mutate a memory byte", 20, 70)
    }
}

fun main() {
    SwingUtilities.invokeLater {
        val frame = JFrame("Real-Time Memory Allocation Fractal Interpreter")
        val visualizer = MemoryFractalVisualizer()
        frame.add(visualizer)
        frame.pack()
        frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
        frame.setLocationRelativeTo(null)
        frame.isVisible = true
    }
}