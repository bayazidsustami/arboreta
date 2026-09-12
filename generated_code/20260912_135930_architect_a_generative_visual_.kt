import java.awt.Canvas
import java.awt.Color
import java.awt.Dimension
import java.awt.Graphics
import java.awt.Graphics2D
import java.awt.RenderingHints
import java.awt.event.KeyAdapter
import java.awt.event.KeyEvent
import java.io.File
import javax.swing.JFrame
import javax.swing.SwingUtilities
import javax.swing.Timer
import kotlin.math.cos
import kotlin.math.sin

/**
 * Structural Metrics extracted from a code snippet.
 */
data class CodeMetrics(
    val cyclomaticComplexity: Int = 1,
    val nestingDepth: Int = 0,
    val totalLines: Int = 0,
    val branchCount: Int = 0
)

/**
 * Analyzes code string syntax to compute complexity metrics.
 */
object CodeAnalyzer {
    private val DECISION_KEYWORDS = setOf(
        "if", "else", "when", "for", "while", "do", "catch", "&&", "||", "?"
    )

    fun analyze(code: String): CodeMetrics {
        val lines = code.lines().map { it.trim() }.filter { it.isNotEmpty() }
        var complexity = 1
        var maxDepth = 0
        var currentDepth = 0
        var branches = 0

        for (line in lines) {
            // Count nesting depth based on braces
            for (char in line) {
                if (char == '{') {
                    currentDepth++
                    if (currentDepth > maxDepth) maxDepth = currentDepth
                } else if (char == '}') {
                    if (currentDepth > 0) currentDepth--
                }
            }

            // Estimate complexity from decision keywords
            val tokens = line.split(Regex("\\W+"))
            for (token in tokens) {
                if (token in DECISION_KEYWORDS) {
                    complexity++
                    branches++
                }
            }
        }

        return CodeMetrics(
            cyclomaticComplexity = complexity,
            nestingDepth = maxDepth,
            totalLines = lines.size,
            branchCount = branches
        )
    }
}

/**
 * Node representing a branch segment in the living fractal tree.
 */
data class BranchNode(
    val startX: Double,
    val startY: Double,
    val angle: Double,
    val targetLength: Double,
    val depth: Int,
    val maxDepth: Int
) {
    var currentLength: Double = 0.0
    var children: MutableList<BranchNode> = mutableListOf()
    var life: Double = 1.0 // 1.0 = alive, decays down to 0.0
    var decayRate: Double = 0.005

    fun update(growthSpeed: Double, decayFactor: Double) {
        // Grow branch towards target length
        if (currentLength < targetLength) {
            currentLength += (targetLength - currentLength) * growthSpeed + 0.1
            if (currentLength > targetLength) currentLength = targetLength
        }

        // Apply decay
        life -= decayRate * decayFactor
        if (life < 0) life = 0.0

        // Update child nodes recursively
        children.forEach { it.update(growthSpeed, decayFactor) }
    }

    fun isDead(): Boolean = life <= 0 && children.all { it.isDead() }

    fun draw(g: Graphics2D, baseHue: Float) {
        if (life <= 0) return

        val endX = startX + currentLength * sin(angle)
        val endY = startY - currentLength * cos(angle)

        // Dynamic styling based on depth and decay life
        val strokeWidth = ((maxDepth - depth + 1) * 1.2 * life).toFloat().coerceAtLeast(0.5f)
        val hue = (baseHue + depth * 0.05f) % 1.0f
        val alpha = (life * 255).toInt().coerceIn(0, 255)

        g.stroke = java.awt.BasicStroke(strokeWidth, java.awt.BasicStroke.CAP_ROUND, java.awt.BasicStroke.JOIN_ROUND)
        g.color = Color.getHSBColor(hue, 0.7f, (0.4f + 0.6f * (life.toFloat())).coerceIn(0f, 1f))
        g.color = Color(g.color.red, g.color.green, g.color.blue, alpha)

        g.drawLine(startX.toInt(), startY.toInt(), endX.toInt(), endY.toInt())

        // Render leaf or blossom at tips
        if (children.isEmpty() && currentLength >= targetLength * 0.8) {
            val leafSize = (6 * life).toInt()
            g.color = Color(100, 255, 180, alpha)
            g.fillOval((endX - leafSize / 2).toInt(), (endY - leafSize / 2).toInt(), leafSize, leafSize)
        }

        children.forEach { it.draw(g, baseHue) }
    }
}

/**
 * Generates fractal structure based on observed CodeMetrics.
 */
class FractalTree(private var rootX: Double, private var rootY: Double) {
    var root: BranchNode? = null
    private var currentMetrics = CodeMetrics()
    private var baseHue = 0.33f // Starts around green

    fun rebuild(metrics: CodeMetrics) {
        this.currentMetrics = metrics
        val maxDepth = metrics.nestingDepth.coerceIn(3, 10)
        val initialLength = (metrics.totalLines * 1.5).coerceIn(40.0, 120.0)
        val spreadAngle = (metrics.cyclomaticComplexity * 0.05).coerceIn(0.2, 0.8)

        root = buildBranch(
            startX = rootX,
            startY = rootY,
            angle = 0.0,
            length = initialLength,
            depth = 1,
            maxDepth = maxDepth,
            spreadAngle = spreadAngle
        )
        baseHue = (metrics.cyclomaticComplexity * 0.03f) % 1.0f
    }

    private fun buildBranch(
        startX: Double,
        startY: Double,
        angle: Double,
        length: Double,
        depth: Int,
        maxDepth: Int,
        spreadAngle: Double
    ): BranchNode {
        val node = BranchNode(startX, startY, angle, length, depth, maxDepth)

        if (depth < maxDepth) {
            val endX = startX + length * sin(angle)
            val endY = startY - length * cos(angle)
            val nextLength = length * 0.75

            // Sub-branching depends on code complexity
            val leftChild = buildBranch(endX, endY, angle - spreadAngle, nextLength, depth + 1, maxDepth, spreadAngle)
            val rightChild = buildBranch(endX, endY, angle + spreadAngle, nextLength, depth + 1, maxDepth, spreadAngle)
            node.children.add(leftChild)
            node.children.add(rightChild)

            // Add center branch for higher cyclomatic complexity
            if (currentMetrics.cyclomaticComplexity > 8 && depth % 2 == 0) {
                val centerChild = buildBranch(endX, endY, angle, nextLength * 0.8, depth + 1, maxDepth, spreadAngle)
                node.children.add(centerChild)
            }
        }
        return node
    }

    fun update() {
        val growthRate = 0.05
        val decayFactor = (currentMetrics.cyclomaticComplexity / 5.0).coerceAtLeast(0.5)
        root?.update(growthRate, decayFactor)
    }

    fun draw(g: Graphics2D) {
        root?.draw(g, baseHue)
    }

    fun updatePosition(x: Double, y: Double) {
        rootX = x
        rootY = y
    }
}

/**
 * Interactive Swing visual canvas running the tree rendering loop and observing file changes.
 */
class GenerativeCanvas(private val targetFile: File?) : Canvas() {
    private var tree: FractalTree = FractalTree(400.0, 550.0)
    private var lastModified: Long = -1
    private var metrics = CodeMetrics(cyclomaticComplexity = 3, nestingDepth = 4, totalLines = 50)

    init {
        background = Color(15, 18, 25)
        
        // Initial build from code file or sample fallback
        reloadCodeMetrics()
        tree.rebuild(metrics)

        // Main animation render loop (~60 FPS)
        Timer(16) {
            checkFileUpdates()
            tree.update()
            repaint()
        }.start()

        // Allow manual trigger via key press
        addKeyListener(object : KeyAdapter() {
            override fun keyPressed(e: KeyEvent) {
                if (e.keyCode == KeyEvent.VK_R) {
                    reloadCodeMetrics()
                    tree.rebuild(metrics)
                }
            }
        })
    }

    private fun reloadCodeMetrics() {
        if (targetFile != null && targetFile.exists()) {
            val content = targetFile.readText()
            metrics = CodeAnalyzer.analyze(content)
        } else {
            // Default dynamic sample if no file passed
            metrics = CodeMetrics(
                cyclomaticComplexity = (3..15).random(),
                nestingDepth = (3..7).random(),
                totalLines = (30..100).random(),
                branchCount = (5..20).random()
            )
        }
    }

    private fun checkFileUpdates() {
        if (targetFile != null && targetFile.exists()) {
            val modified = targetFile.lastModified()
            if (modified > lastModified) {
                lastModified = modified
                reloadCodeMetrics()
                tree.rebuild(metrics)
            }
        }
    }

    override fun paint(g: Graphics) {
        val g2d = g as Graphics2D
        g2d.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        // Clear canvas
        g2d.color = background
        g2d.fillRect(0, 0, width, height)

        // Keep tree rooted at center bottom
        tree.updatePosition(width / 2.0, height - 50.0)
        tree.draw(g2d)

        // Render HUD metrics
        g2d.color = Color(200, 200, 220, 180)
        g2d.drawString("Observing: ${targetFile?.name ?: "Internal Generator"}", 20, 30)
        g2d.drawString("Cyclomatic Complexity: ${metrics.cyclomaticComplexity}", 20, 50)
        g2d.drawString("Nesting Depth (Max): ${metrics.nestingDepth}", 20, 70)
        g2d.drawString("Total Observed Lines: ${metrics.totalLines}", 20, 90)
        g2d.drawString("Press 'R' to randomize/force refresh", 20, 110)
    }
}

fun main(args: Array<String>) {
    val observedFile = if (args.isNotEmpty()) File(args[0]) else null

    SwingUtilities.invokeLater {
        val frame = JFrame("Living Code Fractal Canvas")
        val canvas = GenerativeCanvas(observedFile)
        canvas.preferredSize = Dimension(800, 600)

        frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
        frame.add(canvas)
        frame.pack()
        frame.setLocationRelativeTo(null)
        frame.isVisible = true
        canvas.requestFocus()
    }
}