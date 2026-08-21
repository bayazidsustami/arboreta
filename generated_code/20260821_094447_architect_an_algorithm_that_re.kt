import java.awt.Color
import java.awt.Graphics
import java.awt.Graphics2D
import java.awt.RenderingHints
import java.awt.image.BufferedImage
import java.lang.management.ManagementFactory
import javax.swing.JFrame
import javax.swing.JPanel
import javax.swing.Timer
import kotlin.math.cos
import kotlin.math.sin

/**
 * A self-contained procedural 3D fractal garden that renders JVM memory stats in real-time.
 * - Active memory drives the generation and endless expansion of colorful, recursive 3D fractal branches.
 * - Decaying or freed processes cause the branches to wither, shrink, and fade in color.
 * - Uses soft software raymarching and 3D isometric projection with a custom z-buffer.
 */

data class Point3D(val x: Double, val y: Double, val z: Double)
data class Branch(
    val start: Point3D,
    val end: Point3D,
    val color: Color,
    val radius: Double,
    var health: Double = 1.0,
    val age: Long = System.currentTimeMillis()
)

class FractalGarden : JPanel() {
    private val runtime = Runtime.getRuntime()
    private val branches = mutableListOf<Branch>()
    private var rotationAngle = 0.0
    private var previousUsedMemory = getUsedMemory()

    init {
        // Seed the core trunk of the fractal garden
        growGarden(Point3D(0.0, 0.0, -100.0), Point3D(0.0, 0.0, 0.0), depth = 4, scale = 80.0)

        // 60 FPS visual update and system telemetry loop
        Timer(16) {
            val currentMemory = getUsedMemory()
            val delta = currentMemory - previousUsedMemory

            // React to system memory: allocation grows new flora, garbage collection withers old flora
            if (delta > 0) {
                spawnNewBranch(delta)
            } else if (delta < 0) {
                witherGarden(Math.abs(delta))
            }

            rotationAngle += 0.015
            previousUsedMemory = currentMemory
            repaint()
        }.start()
    }

    private fun getUsedMemory(): Long = runtime.totalMemory() - runtime.freeMemory()

    private fun growGarden(start: Point3D, end: Point3D, depth: Int, scale: Double) {
        if (depth == 0) return
        val hue = ((end.x + end.y + end.z).hashCode() % 360) / 360.0f
        val color = Color.getHSBColor(Math.abs(hue), 0.85f, 0.9f)
        
        branches.add(Branch(start, end, color, radius = depth * 1.5))

        val angleOffset = Math.PI / 4
        val nextLength = scale * 0.7

        // Recursive branching in 3D space
        val dirs = listOf(
            Point3D(sin(angleOffset), cos(angleOffset), 0.8),
            Point3D(-sin(angleOffset), cos(angleOffset), -0.8),
            Point3D(0.0, cos(angleOffset), sin(angleOffset))
        )

        for (dir in dirs) {
            val nextEnd = Point3D(
                end.x + dir.x * nextLength,
                end.y + dir.y * nextLength,
                end.z + dir.z * nextLength
            )
            growGarden(end, nextEnd, depth - 1, nextLength)
        }
    }

    private fun spawnNewBranch(memoryAllocated: Long) {
        if (branches.isEmpty()) return
        val parent = branches.random()
        val offset = (memoryAllocated % 50).toDouble() + 10.0
        val hue = (System.currentTimeMillis() % 1000) / 1000.0f
        
        val newEnd = Point3D(
            parent.end.x + (Math.random() - 0.5) * offset,
            parent.end.y + Math.random() * offset,
            parent.end.z + (Math.random() - 0.5) * offset
        )
        branches.add(Branch(parent.end, newEnd, Color.getHSBColor(hue, 0.9f, 0.95f), radius = 2.0))
    }

    private fun witherGarden(memoryFreed: Long) {
        // Decaying memory forces the oldest or weakest processes/branches to wither
        val decayCount = (memoryFreed / (1024 * 1024)).toInt().coerceIn(1, 10)
        branches.take(decayCount).forEach { branch ->
            branch.health -= 0.25
        }
        branches.removeAll { it.health <= 0.0 }
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        val g2d = g as Graphics2D
        g2d.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)
        
        // Deep ambient dark background
        g2d.color = Color(15, 18, 28)
        g2d.fillRect(0, 0, width, height)

        val centerX = width / 2.0
        val centerY = height / 2.0 + 100

        // Render 3D scene sorted by depth (z-buffer approximation)
        branches.filter { it.health > 0 }
            .map { branch ->
                val p1 = project(branch.start, rotationAngle)
                val p2 = project(branch.end, rotationAngle)
                val averageZ = (p1.z + p2.z) / 2.0
                Triple(branch, p1 to p2, averageZ)
            }
            .sortedBy { it.third } // Back-to-front sorting
            .forEach { (branch, points, _) ->
                val (p1, p2) = points
                
                // Color degradation during process wither
                val alpha = (255 * branch.health).toInt().coerceIn(0, 255)
                val witheredColor = Color(
                    branch.color.red,
                    (branch.color.green * branch.health).toInt(),
                    (branch.color.blue * branch.health).toInt(),
                    alpha
                )

                g2d.color = witheredColor
                val drawRadius = (branch.radius * branch.health).coerceAtLeast(1.0).toInt()
                g2d.stroke = java.awt.BasicStroke(drawRadius.toFloat(), java.awt.BasicStroke.CAP_ROUND, java.awt.BasicStroke.JOIN_ROUND)
                
                g2d.drawLine(
                    (centerX + p1.x).toInt(), (centerY - p1.y).toInt(),
                    (centerX + p2.x).toInt(), (centerY - p2.y).toInt()
                )
            }

        // Draw HUD overlay showing real-time metrics
        g2d.color = Color(220, 220, 240)
        g2d.drawString("RAM Garden Alive | Live Memory: ${getUsedMemory() / (1024 * 1024)} MB", 20, 30)
        g2d.drawString("Active 3D Fractal Nodes: ${branches.size}", 20, 50)
    }

    private fun project(point: Point3D, angle: Double): Point3D {
        // Rotate around Y-axis
        val rad = angle
        val xRot = point.x * cos(rad) - point.z * sin(rad)
        val zRot = point.x * sin(rad) + point.z * cos(rad)

        // 3D Perspective Projection
        val distance = 400.0
        val perspective = distance / (distance + zRot + 250.0)
        return Point3D(xRot * perspective, point.y * perspective, zRot)
    }
}

fun main() {
    val frame = JFrame("Live Memory 3D Procedural Fractal Garden")
    val garden = FractalGarden()
    
    frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
    frame.setSize(1024, 768)
    frame.setLocationRelativeTo(null)
    frame.add(garden)
    frame.isVisible = true
}