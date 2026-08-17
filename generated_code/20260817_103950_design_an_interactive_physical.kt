import java.awt.*
import java.awt.event.*
import javax.swing.*
import kotlin.concurrent.timer
import kotlin.math.*
import kotlin.random.Random

// Git Commit Data Model capturing code contribution metrics
data class Commit(
    val hash: String,
    val message: String,
    val author: String,
    val complexity: Double, // 0.0 (clean) to 1.0 (spaghetti)
    val sentiment: Double   // -1.0 (toxic/frustrated) to +1.0 (joyful)
)

// 3D Point & Projection mathematics
data class Point3D(val x: Double, val y: Double, val z: Double) {
    fun rotateY(angle: Double): Point3D {
        val cosA = cos(angle)
        val sinA = sin(angle)
        return Point3D(x * cosA + z * sinA, y, -x * sinA + z * cosA)
    }

    fun rotateX(angle: Double): Point3D {
        val cosA = cos(angle)
        val sinA = sin(angle)
        return Point3D(x, y * cosA - z * sinA, y * sinA + z * cosA)
    }

    fun project(width: Int, height: Int, fov: Double, distance: Double): Point2D {
        val zEff = max(0.1, z + distance)
        val scale = fov / zEff
        val px = (x * scale) + width / 2.0
        val py = (-y * scale) + height / 1.8
        return Point2D(px, py, scale)
    }
}

data class Point2D(val x: Double, val y: Double, val scale: Double)

// 3D Branch node forming the fractal garden architecture
class Branch(
    val start: Point3D,
    var end: Point3D,
    var thickness: Double,
    val depth: Int,
    var health: Double // 1.0 = Blooming, 0.0 = Withered
) {
    val children = mutableListOf<Branch>()
    var bloomState = 0.0 // 0.0 to 1.0 blossoming progress
    var flowerColor: Color = Color.PINK

    // Growth mutation driven by commit sentiment and complexity
    fun growAndMutate(commit: Commit, maxDepth: Int) {
        val healthDelta = (commit.sentiment * 0.3) - (commit.complexity * 0.2)
        health = (health + healthDelta).coerceIn(0.1, 1.0)
        bloomState = (bloomState + commit.sentiment * 0.4).coerceIn(0.0, 1.0)

        flowerColor = when {
            commit.sentiment > 0.3 -> Color(255, 120 + (commit.sentiment * 135).toInt().coerceIn(0, 135), 180)
            commit.sentiment < -0.3 -> Color(130, 50, 160)
            else -> Color(200, 220, 100)
        }

        // Complex spaghetti commits split chaotic extra sub-branches
        if (depth < maxDepth && children.isEmpty()) {
            val numSubBranches = if (commit.complexity > 0.6) 3 else 2
            val dirX = end.x - start.x
            val dirY = end.y - start.y
            val dirZ = end.z - start.z
            val len = sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ) * 0.75

            for (i in 0 until numSubBranches) {
                val spreadAngle = (0.4 + commit.complexity * 0.5)
                val yaw = (i * (2 * PI / numSubBranches)) + Random.nextDouble(-0.2, 0.2)
                val pitch = spreadAngle + Random.nextDouble(-0.1, 0.1)

                val nx = end.x + len * sin(pitch) * cos(yaw)
                val ny = end.y + len * cos(pitch)
                val nz = end.z + len * sin(pitch) * sin(yaw)

                val newBranch = Branch(end, Point3D(nx, ny, nz), thickness * 0.7, depth + 1, health)
                children.add(newBranch)
            }
        } else {
            children.forEach { it.growAndMutate(commit, maxDepth) }
        }
    }
}

// Interactive Swing Frame with custom double-buffered 3D canvas
class GitFractalGardenFrame : JFrame("3D Git Commit Fractal Garden") {
    private val canvas = FractalCanvas()
    private val commits = mutableListOf<Commit>()
    private val rootBranches = mutableListOf<Branch>()

    private var totalHealth = 0.8
    private var codeComplexityAvg = 0.3

    init {
        defaultCloseOperation = EXIT_ON_CLOSE
        size = Dimension(1100, 800)
        setLocationRelativeTo(null)

        // Seed garden trees in 3D scene space
        for (i in 0 until 3) {
            val offsetX = (i - 1) * 220.0
            val root = Branch(
                Point3D(offsetX, -150.0, 0.0),
                Point3D(offsetX, -50.0, 0.0),
                thickness = 18.0,
                depth = 0,
                health = 0.8
            )
            rootBranches.add(root)
        }

        layout = BorderLayout()
        add(canvas, BorderLayout.CENTER)
        add(createControlPanel(), BorderLayout.SOUTH)

        // Render loop @ 60 FPS & automatic streaming git commits
        Timer(16) { canvas.repaint() }.start()
        startCommitStreamer()
    }

    private fun createControlPanel(): JPanel {
        val panel = JPanel().apply {
            background = Color(25, 28, 36)
            layout = FlowLayout(FlowLayout.CENTER, 15, 10)
        }

        val btnFeature = JButton("✨ Clean Feature (+Sentiment, Low Complexity)").apply {
            addActionListener { applyCommit("feat: Add interactive 3D shader engine", sentiment = 0.85, complexity = 0.15) }
        }
        val btnRefactor = JButton("🧹 Refactor (+Sentiment, Low Complexity)").apply {
            addActionListener { applyCommit("refactor: Streamline AST garden parser", sentiment = 0.6, complexity = 0.1) }
        }
        val btnSpaghetti = JButton("🍝 Spaghetti Code (-Sentiment, High Complexity)").apply {
            addActionListener { applyCommit("fix: Patch core crash with nested hacks", sentiment = -0.5, complexity = 0.9) }
        }
        val btnBug = JButton("🐛 Critical Bug (-Sentiment, Med Complexity)").apply {
            addActionListener { applyCommit("fix: Emergency null pointer fix", sentiment = -0.8, complexity = 0.6) }
        }

        panel.add(btnFeature)
        panel.add(btnRefactor)
        panel.add(btnSpaghetti)
        panel.add(btnBug)
        return panel
    }

    private fun applyCommit(message: String, sentiment: Double, complexity: Double) {
        val hash = Integer.toHexString(Random.nextInt(0x100000, 0xffffff))
        val commit = Commit(hash, message, "Dev-${Random.nextInt(1, 9)}", complexity, sentiment)
        commits.add(0, commit)

        val maxDepth = (4 + commits.size / 3).coerceAtMost(7)
        rootBranches.forEach { it.growAndMutate(commit, maxDepth) }

        codeComplexityAvg = (codeComplexityAvg * 0.8) + (complexity * 0.2)
        totalHealth = (totalHealth + (sentiment * 0.15) - (complexity * 0.1)).coerceIn(0.1, 1.0)
    }

    private fun startCommitStreamer() {
        timer(period = 3500) {
            val sampleCommits = listOf(
                Commit("a1b2c3", "feat: implement realtime telemetry", "Alice", 0.2, 0.7),
                Commit("d4e5f6", "chore: update dependencies", "Bot", 0.1, 0.1),
                Commit("789abc", "fix: deadlock in render loop", "Bob", 0.8, -0.6),
                Commit("fedcba", "docs: improve API documentation", "Carol", 0.05, 0.9),
                Commit("112233", "WIP: hacking prototype state", "Dave", 0.85, -0.4)
            )
            val c = sampleCommits.random()
            SwingUtilities.invokeLater { applyCommit(c.message, c.sentiment, c.complexity) }
        }
    }

    inner class FractalCanvas : JPanel() {
        private var rotX = 0.25
        private var rotY = 0.0
        private var zoom = 450.0
        private var prevMouseX = 0
        private var prevMouseY = 0

        init {
            background = Color(15, 18, 24)

            val mouseAdapter = object : MouseAdapter() {
                override fun mousePressed(e: MouseEvent) {
                    prevMouseX = e.x
                    prevMouseY = e.y
                }

                override fun mouseDragged(e: MouseEvent) {
                    rotY += (e.x - prevMouseX) * 0.008
                    rotX += (e.y - prevMouseY) * 0.008
                    rotX = rotX.coerceIn(-0.8, 0.8)
                    prevMouseX = e.x
                    prevMouseY = e.y
                }

                override fun mouseWheelMoved(e: MouseWheelEvent) {
                    zoom = (zoom - e.wheelRotation * 25).coerceIn(200.0, 900.0)
                }
            }
            addMouseListener(mouseAdapter)
            addMouseMotionListener(mouseAdapter)
            addMouseWheelListener(mouseAdapter)
        }

        override fun paintComponent(g: Graphics) {
            super.paintComponent(g)
            val g2 = g as Graphics2D
            g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

            drawGroundGrid(g2, width, height)

            // Render 3D branches sorted by Z depth for back-to-front rendering
            val renderList = mutableListOf<RenderItem>()
            rootBranches.forEach { collectRenderItems(it, renderList) }
            renderList.sortByDescending { it.avgZ }

            renderList.forEach { item ->
                val p1 = item.p1Proj
                val p2 = item.p2Proj

                // Branch color shifts from vibrant wood green/brown (healthy) to dark ash (withered)
                val h = item.branch.health
                val barkColor = Color(
                    (80 * (1 - h) + 60 * h).toInt(),
                    (80 * (1 - h) + 120 * h).toInt(),
                    (80 * (1 - h) + 50 * h).toInt()
                )

                g2.color = barkColor
                val strokeWidth = (item.branch.thickness * p1.scale * 0.025).toFloat().coerceAtLeast(1f)
                g2.stroke = BasicStroke(strokeWidth, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)
                g2.drawLine(p1.x.toInt(), p1.y.toInt(), p2.x.toInt(), p2.y.toInt())

                // Render Blooming Foliage/Flowers at leaf nodes
                if (item.branch.children.isEmpty() || item.branch.bloomState > 0.2) {
                    val bloomSize = (16.0 * item.branch.bloomState * item.branch.health * p2.scale * 0.02).coerceAtLeast(2.0)
                    g2.color = item.branch.flowerColor
                    g2.fillOval(
                        (p2.x - bloomSize / 2).toInt(),
                        (p2.y - bloomSize / 2).toInt(),
                        bloomSize.toInt(),
                        bloomSize.toInt()
                    )
                }
            }

            drawHUD(g2)
        }

        private fun collectRenderItems(branch: Branch, list: MutableList<RenderItem>) {
            val p1Rot = branch.start.rotateX(rotX).rotateY(rotY)
            val p2Rot = branch.end.rotateX(rotX).rotateY(rotY)

            val p1Proj = p1Rot.project(width, height, zoom, distance = 600.0)
            val p2Proj = p2Rot.project(width, height, zoom, distance = 600.0)

            val avgZ = (p1Rot.z + p2Rot.z) / 2.0
            list.add(RenderItem(branch, p1Proj, p2Proj, avgZ))

            branch.children.forEach { collectRenderItems(it, list) }
        }

        private fun drawGroundGrid(g2: Graphics2D, w: Int, h: Int) {
            g2.color = Color(35, 45, 60, 150)
            g2.stroke = BasicStroke(1f)
            val gridSize = 400.0
            val step = 80.0

            var x = -gridSize
            while (x <= gridSize) {
                val ptA = Point3D(x, -150.0, -gridSize).rotateX(rotX).rotateY(rotY).project(w, h, zoom, 600.0)
                val ptB = Point3D(x, -150.0, gridSize).rotateX(rotX).rotateY(rotY).project(w, h, zoom, 600.0)
                g2.drawLine(ptA.x.toInt(), ptA.y.toInt(), ptB.x.toInt(), ptB.y.toInt())

                val ptC = Point3D(-gridSize, -150.0, x).rotateX(rotX).rotateY(rotY).project(w, h, zoom, 600.0)
                val ptD = Point3D(gridSize, -150.0, x).rotateX(rotX).rotateY(rotY).project(w, h, zoom, 600.0)
                g2.drawLine(ptC.x.toInt(), ptC.y.toInt(), ptD.x.toInt(), ptD.y.toInt())

                x += step
            }
        }

        private fun drawHUD(g2: Graphics2D) {
            g2.font = Font("Monospaced", Font.BOLD, 14)
            g2.color = Color(230, 235, 245)
            g2.drawString("🌱 3D GIT FRACTAL GARDEN SIMULATOR", 20, 30)

            g2.font = Font("SansSerif", Font.PLAIN, 12)
            g2.color = Color(180, 190, 210)
            g2.drawString("Controls: Drag mouse to rotate 3D view | Scroll to zoom", 20, 50)

            g2.color = if (totalHealth > 0.5) Color(100, 220, 120) else Color(240, 90, 80)
            g2.drawString(String.format("Garden Health: %.0f%%", totalHealth * 100), 20, 80)

            g2.color = Color(200, 200, 210)
            g2.drawString(String.format("Avg Complexity: %.2f", codeComplexityAvg), 180, 80)

            g2.drawString("Recent Git Commits:", 20, 115)
            commits.take(5).forEachIndexed { i, c ->
                val sentimentIcon = if (c.sentiment > 0) "🌸" else "🥀"
                g2.color = Color(140, 160, 180)
                g2.drawString(
                    "[$sentimentIcon ${c.hash}] ${c.message} (by ${c.author})",
                    25,
                    135 + i * 20
                )
            }
        }
    }

    private data class RenderItem(
        val branch: Branch,
        val p1Proj: Point2D,
        val p2Proj: Point2D,
        val avgZ: Double
    )
}

fun main() {
    SwingUtilities.invokeLater {
        GitFractalGardenFrame().isVisible = true
    }
}