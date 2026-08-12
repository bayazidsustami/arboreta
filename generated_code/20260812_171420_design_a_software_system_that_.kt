import java.awt.*
import java.awt.geom.*
import java.util.concurrent.ConcurrentHashMap
import javax.swing.*
import kotlin.math.*
import kotlin.random.Random

/**
 * Git Flora Ecosystem Simulator
 * Represents Git authors as symbiotic digital plants whose traits evolve with commit metadata:
 * - Velocity (Commit frequency) -> Growth speed and size (Bloom)
 * - Complexity (Lines added/deleted) -> Fractal branching depth and leaf mutation
 * - Sentiment (Commit message analysis) -> Flora color spectrum and petal vibrancy
 * - Symbiosis (Co-authors / temporal proximity) -> Interconnected mycelial networks
 */

data class GitCommit(
    val author: String,
    val message: String,
    val insertions: Int,
    val deletions: Int,
    val timestamp: Long = System.currentTimeMillis()
)

data class Plant(
    val author: String,
    var energy: Double = 50.0,
    var maxEnergy: Double = 100.0,
    var mutationIndex: Int = 2,
    var sentimentScore: Double = 0.5, // 0.0 (negative) to 1.0 (positive)
    var hue: Float = 0.33f, // Green default
    var x: Double = 0.0,
    var y: Double = 0.0,
    var age: Int = 0
)

class GitFloraEcosystem : JPanel() {
    private val plants = ConcurrentHashMap<String, Plant>()
    private val activeCommits = mutableListOf<GitCommit>()
    private val sentimentPositive = setOf("fix", "feat", "refactor", "improve", "perf", "clean", "love", "solve")
    private val sentimentNegative = setOf("bug", "hack", "broken", "oops", "revert", "fail", "crash", "todo")

    init {
        preferredSize = Dimension(1000, 700)
        background = Color(15, 18, 25)

        // Animation loop (~60 FPS)
        Timer(16) {
            decayAndMutate()
            repaint()
        }.start()

        // Live Git commit simulation stream
        Thread {
            val authors = listOf("Alice", "Bob", "Charlie", "Diana", "Eve")
            val verbs = listOf("Fix memory leak in engine", "Refactor core loop", "Hack fix for bug", "Revert broken build", "Feature: add bloom effect", "Clean up debt")
            while (true) {
                Thread.sleep(1200)
                val author = authors.random()
                val msg = verbs.random()
                val ins = Random.nextInt(5, 250)
                val del = Random.nextInt(1, 100)
                ingestCommit(GitCommit(author, msg, ins, del))
            }
        }.start()
    }

    fun ingestCommit(commit: GitCommit) {
        activeCommits.add(commit)
        if (activeCommits.size > 20) activeCommits.removeAt(0)

        // Sentiment analysis
        val words = commit.message.lowercase().split("\\s+".toRegex())
        val posCount = words.count { it in sentimentPositive }
        val negCount = words.count { it in sentimentNegative }
        val sentiment = when {
            posCount > negCount -> 0.85
            negCount > posCount -> 0.15
            else -> 0.5
        }

        val complexity = commit.insertions + commit.deletions

        plants.compute(commit.author) { name, existing ->
            val p = existing ?: Plant(
                author = name,
                x = Random.nextDouble(150.0, 850.0),
                y = Random.nextDouble(450.0, 550.0)
            )

            // Dynamic Evolution Rules
            p.energy = (p.energy + 20.0).coerceAtMost(150.0)
            p.mutationIndex = (p.mutationIndex + (complexity / 80)).coerceIn(2, 6)
            p.sentimentScore = (p.sentimentScore * 0.6) + (sentiment * 0.4)
            p.hue = (p.sentimentScore * 0.4f + 0.15f).coerceIn(0f, 1f) // Red/Purple for bug/hack, Green/Cyan for feat/fix
            p
        }

        // Symbiotic Energy Transfer: nearby plants share energy
        plants.values.forEach { p1 ->
            plants.values.forEach { p2 ->
                if (p1.author != p2.author) {
                    val dist = hypot(p1.x - p2.x, p1.y - p2.y)
                    if (dist < 200) {
                        p1.energy += 1.5 // Symbiotic bloom benefit
                    }
                }
            }
        }
    }

    private fun decayAndMutate() {
        plants.values.forEach { plant ->
            plant.energy -= 0.12 // Natural decay over time
            if (plant.energy < 0) plant.energy = 0.0
            plant.age++
        }
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        val g2 = g as Graphics2D
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        drawMycelialNetwork(g2)

        // Render each author's digital plant
        plants.values.forEach { plant ->
            if (plant.energy > 1.0) {
                drawFlora(g2, plant.x, plant.y, plant.energy, plant.mutationIndex, plant.hue, plant.author)
            } else {
                // Withered marker
                g2.color = Color(80, 80, 80, 100)
                g2.drawString("${plant.author} (Withered)", plant.x.toInt() - 25, plant.y.toInt() + 15)
            }
        }

        // HUD / Event Overlay
        drawHUD(g2)
    }

    private fun drawMycelialNetwork(g2: Graphics2D) {
        val plantList = plants.values.filter { it.energy > 5.0 }
        g2.stroke = BasicStroke(1.0f)
        for (i in plantList.indices) {
            for (j in i + 1 until plantList.size) {
                val p1 = plantList[i]
                val p2 = plantList[j]
                val dist = hypot(p1.x - p2.x, p1.y - p2.y)
                if (dist < 250) {
                    val alpha = ((1.0 - dist / 250) * 120).toInt().coerceIn(10, 180)
                    g2.color = Color(100, 220, 255, alpha)
                    val ctrlX = (p1.x + p2.x) / 2 + sin(System.currentTimeMillis() / 500.0 + i) * 30
                    val ctrlY = (p1.y + p2.y) / 2 + cos(System.currentTimeMillis() / 500.0 + j) * 30
                    val path = QuadCurve2D.Double(p1.x, p1.y, ctrlX, ctrlY, p2.x, p2.y)
                    g2.draw(path)
                }
            }
        }
    }

    private fun drawFlora(g2: Graphics2D, x: Double, y: Double, energy: Double, depth: Int, hue: Float, author: String) {
        g2.color = Color.getHSBColor(hue, 0.8f, 0.9f)
        val baseAngle = -Math.PI / 2
        val length = energy * 0.85

        fun drawBranch(bx: Double, by: Double, len: Double, angle: Double, currentDepth: Int) {
            if (currentDepth <= 0 || len < 2.0) return

            val endX = bx + len * cos(angle)
            val endY = by + len * sin(angle)

            g2.stroke = BasicStroke((currentDepth * 1.5).toFloat())
            g2.draw(Line2D.Double(bx, by, endX, endY))

            val spread = 0.35 + (0.05 * sin(System.currentTimeMillis() / 300.0 + currentDepth))
            drawBranch(endX, endY, len * 0.72, angle - spread, currentDepth - 1)
            drawBranch(endX, endY, len * 0.72, angle + spread, currentDepth - 1)

            // Bloom flowers at terminals
            if (currentDepth == 1) {
                val bloomRadius = (energy / 6.0).toFloat()
                g2.color = Color.getHSBColor((hue + 0.1f) % 1.0f, 0.6f, 1.0f)
                g2.fill(Ellipse2D.Double(endX - bloomRadius / 2, endY - bloomRadius / 2, bloomRadius.toDouble(), bloomRadius.toDouble()))
            }
        }

        drawBranch(x, y, length, baseAngle, depth)

        // Author Label & Energy Meter
        g2.color = Color.WHITE
        g2.font = Font("Monospaced", Font.BOLD, 12)
        g2.drawString(author, (x - 20).toInt(), (y + 25).toInt())
        g2.color = Color(100, 255, 150, 180)
        g2.fillRect((x - 20).toInt(), (y + 30).toInt(), (energy * 0.5).toInt().coerceAtMost(60), 4)
    }

    private fun drawHUD(g2: Graphics2D) {
        g2.color = Color(255, 255, 255, 220)
        g2.font = Font("SansSerif", Font.BOLD, 16)
        g2.drawString("Git Commits -> Symbiotic Digital Flora Ecosystem", 20, 30)

        g2.font = Font("Monospaced", Font.PLAIN, 11)
        g2.drawString("Recent Git Stream:", 20, 60)
        activeCommits.takeLast(5).reversed().forEachIndexed { index, commit ->
            val color = if (commit.insertions > commit.deletions) Color(120, 255, 120) else Color(255, 120, 120)
            g2.color = color
            g2.drawString("[${commit.author}] ${commit.message} (+${commit.insertions} -${commit.deletions})", 20, 80 + index * 18)
        }
    }
}

fun main() {
    SwingUtilities.invokeLater {
        val frame = JFrame("Git Flora Symbiosis Ecosystem")
        frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
        frame.contentPane = GitFloraEcosystem()
        frame.pack()
        frame.setLocationRelativeTo(null)
        frame.isVisible = true
    }
}