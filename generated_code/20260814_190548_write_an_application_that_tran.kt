import java.awt.*
import java.awt.event.KeyAdapter
import java.awt.event.KeyEvent
import java.lang.management.ManagementFactory
import javax.swing.*
import kotlin.math.*

/**
 * Transcribes system clock nanosecond drift into a recursive fractal tree.
 * - Clock Drift: Nanosecond jitter between nanoTime and system epoch drives branch sway and angular variance.
 * - CPU Temp: Estimated CPU temperature/load dictates tree depth and growth scale.
 * - Keyboard Activity: User keypresses decay the tree, causing branches to wither and fade.
 */
class FractalClockTree : JFrame("Nanosecond Drift & Thermal Fractal Tree") {

    private var keyPressCount = 0
    private var lastKeyTime = System.currentTimeMillis()
    private var witherFactor = 0.0

    init {
        defaultCloseOperation = EXIT_ON_CLOSE
        size = Dimension(900, 700)
        isResizable = true
        setLocationRelativeTo(null)

        val canvas = TreeCanvas()
        add(canvas)

        // Track keyboard activity to induce branch withering
        addKeyListener(object : KeyAdapter() {
            override fun keyPressed(e: KeyEvent) {
                keyPressCount++
                lastKeyTime = System.currentTimeMillis()
                witherFactor = (witherFactor + 0.2).coerceAtMost(1.0)
            }
        })

        // Main render loop (~60 FPS)
        Timer(16) {
            val idleTime = System.currentTimeMillis() - lastKeyTime
            if (idleTime > 120) {
                witherFactor = (witherFactor - 0.015).coerceAtLeast(0.0)
            }
            canvas.repaint()
        }.start()
    }

    private inner class TreeCanvas : JPanel() {
        init {
            background = Color(12, 15, 24)
        }

        override fun paintComponent(g: Graphics) {
            super.paintComponent(g)
            val g2d = g as Graphics2D
            g2d.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

            // Calculate nanosecond clock drift jitter relative to epoch time
            val millisInNano = System.currentTimeMillis() * 1_000_000L
            val nanoTime = System.nanoTime()
            val driftJitter = abs(nanoTime - millisInNano) % 10_000_000L
            val driftPhase = (driftJitter / 10_000_000.0) * 2.0 * PI

            // Estimate CPU thermal activity via system load
            val osBean = ManagementFactory.getOperatingSystemMXBean()
            val systemLoad = osBean.systemLoadAverage.let { if (it < 0) 0.35 else it.coerceIn(0.1, 1.0) }
            val cpuTempSimulated = 35.0 + systemLoad * 45.0 // ~35°C (idle) to 80°C (load)

            // Compute growth parameters based on thermal state and keyboard decay
            val maxDepth = (5 + (cpuTempSimulated / 10.0).toInt()).coerceIn(4, 10)
            val baseLength = 130.0 * (1.0 - witherFactor * 0.5)
            val angleSpread = (PI / 5.5) + sin(driftPhase) * 0.12

            val startX = width / 2.0
            val startY = height * 0.88

            // Render telemetry HUD
            g2d.color = Color(160, 190, 220, 160)
            g2d.font = Font("Monospaced", Font.PLAIN, 12)
            g2d.drawString("Clock Drift Jitter : $driftJitter ns", 20, 30)
            g2d.drawString("Simulated CPU Temp : ${"%.1f".format(cpuTempSimulated)}°C", 20, 48)
            g2d.drawString("Branch Wither Level: ${"%.0f".format(witherFactor * 100)}%", 20, 66)

            // Draw recursive fractal tree
            drawBranch(
                g2d = g2d,
                x = startX,
                y = startY,
                length = baseLength,
                angle = -PI / 2 + sin(driftPhase * 0.5) * 0.04,
                depth = maxDepth,
                currentDepth = 0,
                driftAngle = angleSpread,
                wither = witherFactor
            )
        }

        private fun drawBranch(
            g2d: Graphics2D,
            x: Double,
            y: Double,
            length: Double,
            angle: Double,
            depth: Int,
            currentDepth: Int,
            driftAngle: Double,
            wither: Double
        ) {
            if (currentDepth >= depth || length < 2.0) return

            val endX = x + length * cos(angle)
            val endY = y + length * sin(angle)

            // Shift colors dynamically from energetic green/amber to withered red/gray
            val green = (210 - currentDepth * 18 - (wither * 140).toInt()).coerceIn(30, 255)
            val red = (90 + currentDepth * 22 + (wither * 120).toInt()).coerceIn(30, 255)
            val blue = (70 + (1.0 - wither) * 110).toInt().coerceIn(30, 255)
            val alpha = (255 - (wither * 130).toInt()).coerceIn(40, 255)

            val strokeWidth = ((depth - currentDepth) * 1.6 * (1.0 - wither * 0.4)).coerceAtLeast(1.0).toFloat()
            g2d.stroke = BasicStroke(strokeWidth, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)
            g2d.color = Color(red, green, blue, alpha)

            g2d.drawLine(x.toInt(), y.toInt(), endX.toInt(), endY.toInt())

            val nextLength = length * (0.72 - wither * 0.18)
            val angleVariance = driftAngle * (1.0 + wither * 0.4)

            // Recursive branch splits
            drawBranch(g2d, endX, endY, nextLength, angle - angleVariance, depth, currentDepth + 1, driftAngle, wither)
            drawBranch(g2d, endX, endY, nextLength, angle + angleVariance, depth, currentDepth + 1, driftAngle, wither)

            // High CPU heat enables central sub-branch growth
            if (depth > 7 && currentDepth % 2 == 0) {
                drawBranch(g2d, endX, endY, nextLength * 0.55, angle + sin(driftAngle) * 0.1, depth, currentDepth + 2, driftAngle, wither)
            }
        }
    }
}

fun main() {
    SwingUtilities.invokeLater {
        FractalClockTree().isVisible = true
    }
}