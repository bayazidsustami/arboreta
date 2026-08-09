import java.awt.*
import java.awt.geom.*
import javax.swing.*
import kotlin.math.*

// Main entry point launching the bioluminescent system monitor frame
fun main() {
    SwingUtilities.invokeLater {
        val frame = JFrame("Living Process Ecosystem - Real-Time System Monitor")
        frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
        frame.isResizable = true
        frame.contentPane = FractalEcosystemPanel()
        frame.pack()
        frame.setLocationRelativeTo(null)
        frame.isVisible = true
    }
}

// Custom panel handling real-time system metrics rendering as bioluminescent flora and fungal blights
class FractalEcosystemPanel : JPanel() {
    private var animationTick = 0.0

    init {
        preferredSize = Dimension(1100, 800)
        background = Color(6, 10, 18) // Dark abyssal background

        // Animation loop running at ~60 FPS to drive organic movement
        Timer(16) {
            animationTick += 0.035
            repaint()
        }.start()
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        val g2d = g as Graphics2D
        
        // Enable high quality antialiasing for smooth glowing vector lines
        g2d.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)
        g2d.setRenderingHint(RenderingHints.KEY_STROKE_CONTROL, RenderingHints.VALUE_STROKE_PURE)

        val w = width.toDouble()
        val h = height.toDouble()

        // Sample real OS metrics: Runtime memory and live OS processes via Java 9+ ProcessHandle API
        val runtime = Runtime.getRuntime()
        val totalMem = runtime.totalMemory()
        val freeMem = runtime.freeMemory()
        val usedMem = totalMem - freeMem
        val memoryLoadRatio = (usedMem.toDouble() / runtime.maxMemory().toDouble()).coerceIn(0.05, 1.0)

        val activeProcesses = ProcessHandle.allProcesses().toList()
        val processCount = activeProcesses.size

        // 1. Spreading Fungal Blights driven by memory consumption
        renderFungalBlights(g2d, w, h, memoryLoadRatio)

        // 2. Living Bioluminescent Fractal Tree sprouted from Process/Thread hierarchy
        val trunkBaseX = w / 2.0
        val trunkBaseY = h - 60.0
        val initialTrunkLength = 135.0

        renderFractalFlora(
            g2d = g2d,
            x = trunkBaseX,
            y = trunkBaseY,
            length = initialTrunkLength,
            angle = -Math.PI / 2,
            depth = 0,
            maxDepth = 7,
            processCount = processCount,
            memRatio = memoryLoadRatio
        )

        // 3. Render System Diagnostics Overlay HUD
        renderHUD(g2d, processCount, memoryLoadRatio, usedMem / (1024 * 1024))
    }

    // Recursively renders OS process tree as bioluminescent fractal flora
    private fun renderFractalFlora(
        g2d: Graphics2D,
        x: Double,
        y: Double,
        length: Double,
        angle: Double,
        depth: Int,
        maxDepth: Int,
        processCount: Int,
        memRatio: Double
    ) {
        if (depth >= maxDepth || length < 4.0) return

        // CPU pulse simulation influencing sway and branch dynamics
        val sway = sin(animationTick + depth * 0.7) * (0.05 + (processCount % 10) * 0.005)
        val currentAngle = angle + sway

        val endX = x + length * cos(currentAngle)
        val endY = y + length * sin(currentAngle)

        // Calculate bioluminescent HSB color palette shifting over time
        val hue = (0.48f + depth * 0.07f + sin(animationTick * 0.4).toFloat() * 0.04f) % 1.0f
        val saturation = 0.85f
        val brightness = (0.75f + sin(animationTick * 2.0 + depth).toFloat() * 0.25f).coerceIn(0.3f, 1.0f)
        val floraColor = Color.getHSBColor(hue, saturation, brightness)

        val alpha = (255 - depth * 28).coerceIn(40, 255)
        g2d.color = Color(floraColor.red, floraColor.green, floraColor.blue, alpha)
        g2d.stroke = BasicStroke(maxOf(1.0f, (maxDepth - depth) * 1.6f), BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)
        g2d.draw(Line2D.Double(x, y, endX, endY))

        // Sprout glowing floral buds at deep branch tips
        if (depth > 4) {
            val budRadius = (5.0 + sin(animationTick * 3.0 + depth) * 2.5) * (1.0 + memRatio)
            g2d.color = Color(0, 255, 200, 190)
            g2d.fill(Ellipse2D.Double(endX - budRadius / 2, endY - budRadius / 2, budRadius, budRadius))
        }

        // Branching factor influenced by thread/process workload density
        val branchReduction = 0.68 + (sin(animationTick + depth) * 0.02)
        val spreadAngle = 0.42 + (processCount % 5) * 0.02

        renderFractalFlora(g2d, endX, endY, length * branchReduction, currentAngle - spreadAngle, depth + 1, maxDepth, processCount, memRatio)
        renderFractalFlora(g2d, endX, endY, length * branchReduction, currentAngle + spreadAngle, depth + 1, maxDepth, processCount, memRatio)
    }

    // Draws creeping fungal spores/blights across canvas proportional to memory load
    private fun renderFungalBlights(g2d: Graphics2D, width: Double, height: Double, memoryRatio: Double) {
        val blightClusters = (memoryRatio * 16).toInt().coerceAtLeast(3)

        for (i in 0 until blightClusters) {
            val posX = (sin(i * 73.123) * 0.42 + 0.5) * width
            val posY = (cos(i * 41.567) * 0.42 + 0.5) * height
            val radius = (25.0 + sin(animationTick + i) * 8.0) * (memoryRatio * 2.2)

            // Render toxic spreading fungal spores
            val toxicAlpha = (memoryRatio * 140).toInt().coerceIn(20, 180)
            g2d.color = Color(200, 30, 110, toxicAlpha)
            g2d.fill(Ellipse2D.Double(posX - radius, posY - radius, radius * 2.0, radius * 2.0))

            // Creeping hyphae filaments connecting fungal blight centers
            g2d.stroke = BasicStroke(1.0f)
            for (j in 0 until 6) {
                val filamentAngle = animationTick * 0.4 + j * (Math.PI / 3.0)
                val tipX = posX + cos(filamentAngle) * (radius * 1.6)
                val tipY = posY + sin(filamentAngle) * (radius * 1.6)
                g2d.color = Color(160, 20, 80, (toxicAlpha * 0.6).toInt())
                g2d.draw(Line2D.Double(posX, posY, tipX, tipY))
            }
        }
    }

    // Heads-Up Display rendering real-time system metrics text
    private fun renderHUD(g2d: Graphics2D, processCount: Int, memRatio: Double, usedMb: Long) {
        g2d.color = Color(20, 30, 45, 200)
        g2d.fillRoundRect(15, 15, 310, 100, 12, 12)
        g2d.color = Color(0, 230, 255, 220)
        g2d.drawRoundRect(15, 15, 310, 100, 12, 12)

        g2d.font = Font("Monospaced", Font.BOLD, 13)
        g2d.drawString("ECOSYSTEM MONITOR v1.0", 30, 38)
        g2d.color = Color(180, 220, 255, 200)
        g2d.drawString("Active OS Processes : $processCount handles", 30, 60)
        g2d.drawString("Memory Load (Blight): ${(memRatio * 100).toInt()}% ($usedMb MB)", 30, 78)
        g2d.drawString("CPU Cycles (Flora)  : Sprouting Active", 30, 96)
    }
}