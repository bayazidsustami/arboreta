import java.awt.*
import java.awt.event.*
import java.lang.ref.Cleaner
import java.util.concurrent.CopyOnWriteArrayList
import javax.swing.*

// A node representing a live call frame in the recursive execution tree
class ExecutionNode(
    val id: Long,
    val depth: Int,
    val angle: Double,
    val length: Double,
    val parent: ExecutionNode?
) {
    val children = CopyOnWriteArrayList<ExecutionNode>()
    var progress: Float = 0f // Smooth growth animation (0.0 to 1.0)
}

class FractalTreePanel : JPanel() {
    val rootNodes = CopyOnWriteArrayList<ExecutionNode>()
    private var nodeCounter = 0L

    init {
        background = Color(15, 18, 25)
        isFocusable = true

        // 60 FPS animation loop for growth updates and rendering
        Timer(16) {
            animateGrowth(rootNodes)
            repaint()
        }.start()

        // Setup GC listener using Cleaner to shed leaf nodes when GC fires
        setupGarbageCollectionSensing()

        // Click to trigger a new live recursive execution visual trace
        addMouseListener(object : MouseAdapter() {
            override fun mouseClicked(e: MouseEvent) {
                spawnRecursiveExecution(e.x.toDouble(), height.toDouble() - 50)
            }
        })
    }

    private fun setupGarbageCollectionSensing() {
        val cleaner = Cleaner.create()
        fun registerGCSentinel() {
            var sentinel: Any? = Any()
            cleaner.register(sentinel) {
                // GC Triggered: Shed all current terminal leaf nodes
                shedLeafNodes(rootNodes)
                registerGCSentinel() // Re-register for the next GC event
            }
            @Suppress("UNUSED_VALUE")
            sentinel = null // Make eligible for garbage collection
        }
        registerGCSentinel()
    }

    private fun animateGrowth(nodes: List<ExecutionNode>) {
        for (node in nodes) {
            if (node.progress < 1f) {
                node.progress = (node.progress + 0.08f).coerceAtMost(1f)
            }
            animateGrowth(node.children)
        }
    }

    // Recursively removes nodes that currently have no children (leaf nodes)
    private fun shedLeafNodes(nodes: MutableList<ExecutionNode>) {
        val iterator = nodes.iterator()
        while (iterator.hasNext()) {
            val node = iterator.next()
            if (node.children.isEmpty()) {
                nodes.remove(node)
            } else {
                shedLeafNodes(node.children)
            }
        }
    }

    // Traces recursion live by adding nodes and yielding execution momentarily
    fun traceRecursiveExecution(
        parent: ExecutionNode?,
        depth: Int,
        maxDepth: Int,
        angle: Double,
        length: Double
    ) {
        if (depth > maxDepth) return

        val node = ExecutionNode(++nodeCounter, depth, angle, length, parent)
        if (parent == null) {
            rootNodes.add(node)
        } else {
            parent.children.add(node)
        }

        // Live delay to visualize call stack expansion step-by-step
        Thread.sleep(25)

        // Recursive branching (simulating divide-and-conquer function trace)
        traceRecursiveExecution(node, depth + 1, maxDepth, angle - 0.38, length * 0.78)
        traceRecursiveExecution(node, depth + 1, maxDepth, angle + 0.38, length * 0.78)
    }

    fun spawnRecursiveExecution(startX: Double, startY: Double) {
        Thread {
            traceRecursiveExecution(null, 0, 8, -Math.PI / 2, 85.0)
        }.start()
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        val g2 = g as Graphics2D
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        // HUD Info
        g2.color = Color(180, 200, 220)
        g2.font = Font("Monospaced", Font.BOLD, 13)
        g2.drawString("• Click anywhere to trigger recursive call trace", 20, 30)
        g2.drawString("• Press 'G' to trigger manual GC (Shed Leaves)", 20, 50)

        // Draw fractal tree hierarchy
        val centerX = width / 2.0
        val startY = height - 50.0
        for (root in rootNodes) {
            drawBranch(g2, root, centerX, startY)
        }
    }

    private fun drawBranch(g2: Graphics2D, node: ExecutionNode, x: Double, y: Double) {
        val currentLength = node.length * node.progress
        val endX = x + currentLength * Math.cos(node.angle)
        val endY = y + currentLength * Math.sin(node.angle)

        val strokeWidth = (9f - node.depth * 0.9f).coerceAtLeast(1.2f)
        g2.stroke = BasicStroke(strokeWidth, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)

        // Color shifts with depth in execution stack
        val hue = (0.33f + node.depth * 0.04f) % 1.0f
        g2.color = Color.getHSBColor(hue, 0.7f, 0.9f)

        g2.drawLine(x.toInt(), y.toInt(), endX.toInt(), endY.toInt())

        // Render leaf nodes at stack termination points
        if (node.children.isEmpty() && node.progress >= 0.9f) {
            g2.color = Color(255, 110, 130, 220)
            g2.fillOval(endX.toInt() - 5, endY.toInt() - 5, 10, 10)
        }

        for (child in node.children) {
            drawBranch(g2, child, endX, endY)
        }
    }
}

fun main() {
    SwingUtilities.invokeLater {
        val frame = JFrame("Interactive Execution Trace Fractal Tree")
        val panel = FractalTreePanel()

        frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
        frame.setSize(1000, 750)
        frame.add(panel)
        frame.setLocationRelativeTo(null)

        // Global key shortcut to trigger GC explicitly
        panel.addKeyListener(object : KeyAdapter() {
            override fun keyPressed(e: KeyEvent) {
                if (e.keyCode == KeyEvent.VK_G) {
                    System.gc()
                }
            }
        })

        frame.isVisible = true

        // Spawn initial tree build
        panel.spawnRecursiveExecution(500.0, 700.0)
    }
}