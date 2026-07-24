import java.awt.*
import java.awt.image.BufferedImage
import java.util.concurrent.CopyOnWriteArrayList
import javax.swing.JFrame
import javax.swing.JPanel
import javax.swing.Timer
import kotlin.math.*
import kotlin.random.Random

/**
 * Represents an allocated memory block in the dynamic heap space.
 */
data class MemoryBlock(
    val address: Int,
    val size: Int,
    val isLeak: Boolean,
    var age: Float = 0f
)

/**
 * Surrealist Dynamic Heap Garden Renderer
 * Simulates dynamic memory allocation/deallocation and visualizes the heap layout
 * as a blooming surrealist digital garden where leaked memory turns into skeletal branches.
 */
class SurrealistMemoryGarden : JPanel() {
    private val heapCapacity = 256
    private val blocks = CopyOnWriteArrayList<MemoryBlock>()
    private val random = Random(System.currentTimeMillis())
    private var animationFrame = 0

    init {
        preferredSize = Dimension(900, 675)
        background = Color(12, 10, 22)

        // Background thread simulating continuous heap activity (allocations & deallocations)
        Thread {
            while (true) {
                Thread.sleep(120)
                simulateHeapOperations()
            }
        }.apply { isDaemon = true; start() }

        // Main animation loop driving rendering and decay physics
        Timer(16) {
            animationFrame++
            blocks.forEach { block -> block.age += 0.02f }
            repaint()
        }.start()
    }

    private fun simulateHeapOperations() {
        // Free active (non-leaked) memory blocks over time
        blocks.removeIf { !it.isLeak && (random.nextFloat() < 0.12f || it.age > 4.0f) }

        // Allocate new memory blocks into available address space
        if (blocks.size < 48) {
            val address = random.nextInt(heapCapacity)
            val size = random.nextInt(6, 24)
            // 25% probability of creating an unreferenced memory leak
            val isLeak = random.nextFloat() < 0.25f
            blocks.add(MemoryBlock(address, size, isLeak))
        }
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        val g2 = g as Graphics2D
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        val gridCols = 16
        val gridRows = 16
        val cellW = width.toDouble() / gridCols
        val cellH = height.toDouble() / gridRows

        // Render heap memory lattice background
        renderHeapLattice(g2, gridCols, gridRows, cellW, cellH)

        // Shader-like procedural rendering of each memory block in address space
        blocks.forEach { block ->
            val col = block.address % gridCols
            val row = (block.address / gridCols) % gridRows
            val x = col * cellW + cellW / 2
            val y = row * cellH + cellH / 2

            if (block.isLeak) {
                // Withered skeletal growth representing leaked memory
                renderSkeletalBranch(g2, x, y, block)
            } else {
                // Vibrant glowing digital flora representing active, healthy allocations
                renderActiveFlora(g2, x, y, block)
            }
        }

        // On-screen heap analytics HUD
        renderHUD(g2)
    }

    private fun renderHeapLattice(g2: Graphics2D, cols: Int, rows: Int, cellW: Double, cellH: Double) {
        g2.color = Color(35, 28, 55, 90)
        for (i in 0..cols) {
            val x = (i * cellW).toInt()
            g2.drawLine(x, 0, x, height)
        }
        for (j in 0..rows) {
            val y = (j * cellH).toInt()
            g2.drawLine(0, y, width, y)
        }
    }

    private fun renderActiveFlora(g2: Graphics2D, x: Double, y: Double, block: MemoryBlock) {
        val pulse = sin(animationFrame * 0.08 + block.address) * 0.25 + 1.0
        val radius = (block.size * 1.6 * pulse).toFloat().coerceAtLeast(4f)

        // Soft glowing energy field around active allocation
        val aura = RadialGradientPaint(
            x.toFloat(), y.toFloat(), radius,
            floatArrayOf(0.0f, 0.5f, 1.0f),
            arrayOf(
                Color(0, 240, 180, 190),
                Color(130, 60, 255, 90),
                Color(0, 0, 0, 0)
            )
        )
        g2.paint = aura
        g2.fillOval((x - radius).toInt(), (y - radius).toInt(), (radius * 2).toInt(), (radius * 2).toInt())

        // Bioluminescent petal array orbiting memory address core
        val petalCount = 5 + (block.size % 5)
        g2.color = Color(220, 255, 245, 230)
        for (i in 0 until petalCount) {
            val angle = (i * 2 * PI / petalCount) + animationFrame * 0.03
            val px = x + cos(angle) * (radius * 0.55)
            val py = y + sin(angle) * (radius * 0.55)
            g2.fillOval((px - 2.5).toInt(), (py - 2.5).toInt(), 5, 5)
        }
    }

    private fun renderSkeletalBranch(g2: Graphics2D, x: Double, y: Double, block: MemoryBlock) {
        // Decay factor: block withers into pale skeletal bone structures over time
        val decay = (block.age * 0.18f).coerceAtMost(1.0f)
        val branchLength = block.size * 2.8 * (1.0 + decay * 0.5)

        // Color transitions from muted amber to ghostly calcified grey
        val boneColor = Color(
            (190 * decay + 140 * (1 - decay)).toInt(),
            (190 * decay + 90 * (1 - decay)).toInt(),
            (200 * decay + 60 * (1 - decay)).toInt(),
            (210 - decay * 60).toInt()
        )

        g2.color = boneColor
        g2.stroke = BasicStroke(1.2f + (1.0f - decay) * 1.2f, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)

        // Recursive fractal branching representing orphaned pointer chains
        drawFractalSkeleton(g2, x, y, -PI / 2 + sin(block.address.toDouble()), branchLength, 4, block.address)
    }

    private fun drawFractalSkeleton(g2: Graphics2D, x: Double, y: Double, angle: Double, length: Double, depth: Int, seed: Int) {
        if (depth <= 0 || length < 2.0) return

        val endX = x + cos(angle) * length
        val endY = y + sin(angle) * length

        g2.drawLine(x.toInt(), y.toInt(), endX.toInt(), endY.toInt())

        val spread = 0.42 + sin(seed.toDouble() + depth) * 0.08
        drawFractalSkeleton(g2, endX, endY, angle - spread, length * 0.66, depth - 1, seed + 1)
        drawFractalSkeleton(g2, endX, endY, angle + spread, length * 0.66, depth - 1, seed + 2)
    }

    private fun renderHUD(g2: Graphics2D) {
        val activeCount = blocks.count { !it.isLeak }
        val leakCount = blocks.count { it.isLeak }

        g2.font = Font("Monospaced", Font.BOLD, 13)
        g2.color = Color(160, 180, 220, 220)
        g2.drawString("DYNAMIC HEAP MAP // ACTIVE: $activeCount blocks | WITHERED LEAKS: $leakCount blocks", 24, 32)
        
        g2.color = Color(80, 240, 180, 200)
        g2.drawString("● Blooming Flora = Live Memory", 24, 54)
        
        g2.color = Color(200, 190, 180, 200)
        g2.drawString("🕆 Skeletal Branches = Forgotten Leaks", 240, 54)
    }
}

fun main() {
    EventQueue.invokeLater {
        val frame = JFrame("Surrealist Dynamic Heap Memory Map")
        frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
        frame.contentPane = SurrealistMemoryGarden()
        frame.pack()
        frame.setLocationRelativeTo(null)
        frame.isVisible = true
    }
}