import java.awt.*
import java.awt.event.MouseAdapter
import java.awt.event.MouseEvent
import java.awt.geom.Line2D
import java.awt.geom.Path2D
import java.awt.geom.Point2D
import javax.swing.*

// Represents a 2D Vector for light ray positions and directions
data class Vec2(val x: Double, val y: Double) {
    operator fun plus(v: Vec2) = Vec2(x + v.x, y + v.y)
    operator fun minus(v: Vec2) = Vec2(x - v.x, y - v.y)
    operator fun times(s: Double) = Vec2(x * s, y * s)
    fun dot(v: Vec2) = x * v.x + y * v.y
    fun length() = Math.hypot(x, y)
    fun normalize() = length().let { if (it == 0.0) Vec2(0.0, 0.0) else Vec2(x / it, y / it) }
    fun rotate(angle: Double) = Vec2(
        x * Math.cos(angle) - y * Math.sin(angle),
        x * Math.sin(angle) + y * Math.cos(angle)
    )
}

// Commands encoded by stained glass pane colors
enum class PaneColor(val color: Color, val opName: String) {
    RED(Color(220, 50, 40, 180), "ADD (+1)"),
    BLUE(Color(40, 120, 220, 180), "SUB (-1)"),
    GREEN(Color(50, 200, 80, 180), "PRINT"),
    YELLOW(Color(240, 210, 40, 180), "SELECT NEXT VAR"),
    PURPLE(Color(160, 50, 200, 180), "REFRACT (+45°)"),
    CYAN(Color(50, 200, 220, 180), "SPLIT RAY");

    fun apply(interpreter: StainedGlassInterpreter) {
        when (this) {
            RED -> interpreter.vars[interpreter.activeVarIndex]++
            BLUE -> interpreter.vars[interpreter.activeVarIndex]--
            GREEN -> interpreter.outputLog.add("Var[${interpreter.activeVarIndex}] = ${interpreter.vars[interpreter.activeVarIndex]}")
            YELLOW -> interpreter.activeVarIndex = (interpreter.activeVarIndex + 1) % interpreter.vars.size
            PURPLE -> {} // Direction modification handled directly in ray propagation physics
            CYAN -> {}   // Ray splitting handled directly in ray propagation physics
        }
    }
}

// Polygon-shaped glass pane
data class GlassPane(val polygon: Polygon, val type: PaneColor) {
    fun contains(p: Point2D) = polygon.contains(p)
}

// Light ray state
data class Ray(var pos: Vec2, var dir: Vec2, var intensity: Double = 1.0)

// The Stained Glass Interpreter engine and visualizer
class StainedGlassInterpreter : JFrame("LuxScript - Stained Glass Visual Interpreter") {
    val panes = mutableListOf<GlassPane>()
    val vars = IntArray(4) { 0 }
    var activeVarIndex = 0
    val outputLog = mutableListOf<String>()

    private var lightSource = Vec2(50.0, 50.0)
    private var initialDirection = Vec2(1.0, 0.5).normalize()
    private val rayPath = mutableListOf<Pair<Vec2, Vec2>>() // Segments for rendering

    private val canvas = object : JPanel() {
        init {
            preferredSize = Dimension(800, 600)
            background = Color(20, 20, 25)

            // Click canvas to move the light emitter source
            addMouseListener(object : MouseAdapter() {
                override fun mousePressed(e: MouseEvent) {
                    lightSource = Vec2(e.x.toDouble(), e.y.toDouble())
                    runProgram()
                    repaint()
                }
            })
        }

        override fun paintComponent(g: Graphics) {
            super.paintComponent(g)
            val g2 = g as Graphics2D
            g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

            // Draw Stained Glass Panes
            for (pane in panes) {
                g2.color = pane.type.color
                g2.fill(pane.polygon)
                g2.color = Color(40, 40, 40)
                g2.stroke = BasicStroke(4f)
                g2.draw(pane.polygon)

                // Label pane operation
                val bounds = pane.polygon.bounds
                g2.color = Color.WHITE
                g2.font = Font("SansSerif", Font.BOLD, 10)
                g2.drawString(pane.type.opName, bounds.centerX.toInt() - 15, bounds.centerY.toInt())
            }

            // Draw Light Rays
            g2.stroke = BasicStroke(2f)
            for ((start, end) in rayPath) {
                g2.color = Color(255, 255, 200, 220)
                g2.draw(Line2D.Double(start.x, start.y, end.x, end.y))
            }

            // Draw Light Emitter
            g2.color = Color.YELLOW
            g2.fillOval((lightSource.x - 6).toInt(), (lightSource.y - 6).toInt(), 12, 12)

            // Render Output Console Overlay
            g2.color = Color(0, 0, 0, 190)
            g2.fillRect(10, 10, 260, 180)
            g2.color = Color.GREEN
            g2.drawRect(10, 10, 260, 180)
            g2.font = Font("Monospaced", Font.PLAIN, 12)
            g2.drawString("--- LUXSCRIPT EXECUTOR ---", 20, 30)
            g2.drawString("Vars: ${vars.joinToString(", ")} [Active: $activeVarIndex]", 20, 50)
            g2.drawString("Log Output:", 20, 70)

            var y = 90
            val visibleLogs = outputLog.takeLast(6)
            for (log in visibleLogs) {
                g2.drawString(log, 20, y)
                y += 16
            }
        }
    }

    init {
        defaultCloseOperation = EXIT_ON_CLOSE
        add(canvas)
        pack()
        setLocationRelativeTo(null)

        setupDefaultWindowProgram()
        runProgram()
    }

    // Creates an abstract stained glass window layout
    private fun setupDefaultWindowProgram() {
        fun makePoly(vararg pts: Pair<Int, Int>) = Polygon(
            pts.map { it.first }.toIntArray(),
            pts.map { it.second }.toIntArray(),
            pts.size
        )

        panes.add(GlassPane(makePoly(100 to 100, 250 to 80, 200 to 220, 120 to 200), PaneColor.RED))
        panes.add(GlassPane(makePoly(250 to 80, 400 to 120, 350 to 250, 200 to 220), PaneColor.PURPLE))
        panes.add(GlassPane(makePoly(400 to 120, 550 to 100, 500 to 300, 350 to 250), PaneColor.YELLOW))
        panes.add(GlassPane(makePoly(120 to 200, 200 to 220, 220 to 380, 100 to 350), PaneColor.BLUE))
        panes.add(GlassPane(makePoly(200 to 220, 350 to 250, 320 to 420, 220 to 380), PaneColor.CYAN))
        panes.add(GlassPane(makePoly(350 to 250, 500 to 300, 480 to 450, 320 to 420), PaneColor.GREEN))
        panes.add(GlassPane(makePoly(220 to 380, 320 to 420, 300 to 520, 180 to 500), PaneColor.RED))
        panes.add(GlassPane(makePoly(320 to 420, 480 to 450, 450 to 550, 300 to 520), PaneColor.GREEN))
    }

    // Simulates ray propagation and code execution
    fun runProgram() {
        vars.fill(0)
        activeVarIndex = 0
        outputLog.clear()
        rayPath.clear()

        val activeRays = mutableListOf(Ray(lightSource, initialDirection))
        var currentPane: GlassPane? = null
        val maxSteps = 150
        var steps = 0

        while (activeRays.isNotEmpty() && steps < maxSteps) {
            steps++
            val ray = activeRays.removeAt(0)
            val stepSize = 3.0
            var pos = ray.pos
            var hitPane: GlassPane? = null

            // Ray march forward until hitting a pane boundary transition
            val segmentStart = pos
            for (i in 0..100) {
                pos += ray.dir * stepSize
                if (pos.x < 0 || pos.x > 800 || pos.y < 0 || pos.y > 600) break

                val point2D = Point2D.Double(pos.x, pos.y)
                val paneAtPoint = panes.firstOrNull { it.contains(point2D) }

                if (paneAtPoint != currentPane) {
                    hitPane = paneAtPoint
                    break
                }
            }

            rayPath.add(segmentStart to pos)

            // Execute semantics when entering a new colored pane
            if (hitPane != null) {
                currentPane = hitPane
                hitPane.type.apply(this)

                when (hitPane.type) {
                    PaneColor.PURPLE -> {
                        // Refract direction by +45 degrees
                        val newDir = ray.dir.rotate(Math.toRadians(45.0))
                        activeRays.add(Ray(pos, newDir))
                    }
                    PaneColor.CYAN -> {
                        // Split light ray into two divergent beams
                        val dir1 = ray.dir.rotate(Math.toRadians(25.0))
                        val dir2 = ray.dir.rotate(Math.toRadians(-25.0))
                        activeRays.add(Ray(pos, dir1))
                        activeRays.add(Ray(pos, dir2))
                    }
                    else -> {
                        // Continue straight through pane
                        activeRays.add(Ray(pos, ray.dir))
                    }
                }
            }
        }
    }
}

fun main() {
    SwingUtilities.invokeLater {
        StainedGlassInterpreter().isVisible = true
    }
}