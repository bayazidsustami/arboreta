import java.awt.*
import java.awt.event.KeyAdapter
import java.awt.event.KeyEvent
import javax.swing.*
import kotlin.math.*
import kotlin.random.Random

// Text Analysis Metrics driving the Cellular Automata parameters
data class TextMetrics(
    val sentiment: Double,          // Range -1.0 (Negative) to +1.0 (Positive)
    val lexicalDiversity: Double,  // Type-Token Ratio (0.0 to 1.0)
    val avgWordLength: Double      // Average characters per word
) {
    companion object {
        private val POSITIVE_WORDS = set.p("good", "great", "love", "light", "bright", "growth", "bloom", "life", "sweet", "happy", "sun", "beautiful", "joy", "calm", "vibrant")
        private val NEGATIVE_WORDS = set.p("dark", "shadow", "death", "decay", "cold", "pain", "gloom", "fear", "rot", "storm", "sad", "bitter", "stagnant", "hate", "ruin")

        private fun Array<out String>.p(vararg items: String) = items.toSet()

        fun analyze(text: String): TextMetrics {
            val words = text.lowercase().replace(Regex("[^a-z0-9\\s]"), "").split("\\s+".toRegex()).filter { it.isNotBlank() }
            if (words.isEmpty()) return TextMetrics(0.0, 0.5, 5.0)

            val totalWords = words.size.toDouble()
            val uniqueWords = words.toSet().size.toDouble()
            val lexicalDiversity = (uniqueWords / totalWords).coerceIn(0.1, 1.0)

            var posCount = 0
            var negCount = 0
            var totalCharLength = 0

            for (word in words) {
                totalCharLength += word.length
                if (POSITIVE_WORDS.contains(word)) posCount++
                if (NEGATIVE_WORDS.contains(word)) negCount++
            }

            val rawSentiment = if (posCount + negCount > 0) {
                (posCount - negCount).toDouble() / (posCount + negCount)
            } else 0.0

            val avgWordLength = totalCharLength / totalWords
            return TextMetrics(rawSentiment, lexicalDiversity, avgWordLength)
        }
    }
}

// Cell state in the Lichen CA Grid
class Cell(
    var age: Int = 0,
    var energy: Double = 0.0,
    var maxAge: Int = 100,
    var branchFactor: Double = 0.0,
    var colorIndex: Float = 0.0f
)

class LichenCanvas(private val widthCells: Int, private val heightCells: Int, private var metrics: TextMetrics) : JPanel() {
    private var grid = Array(widthCells) { Array(heightCells) { Cell() } }
    private var nextGrid = Array(widthCells) { Array(heightCells) { Cell() } }
    private val cellSize = 4
    private val rand = Random(System.currentTimeMillis())

    // Derived parameters from Text Metrics
    private var growthProbability = 0.3
    private var branchingTendency = 0.5
    private var maxLichenAge = 120
    private var hueBase = 0.33f // Green base
    private var hueVariance = 0.2f

    init {
        preferredSize = Dimension(widthCells * cellSize, heightCells * cellSize)
        background = Color(18, 20, 24)
        applyMetrics(metrics)

        // Seed initial lichen spores in the center and surrounding locations
        val centerX = widthCells / 2
        val centerY = heightCells / 2
        seedSpores(centerX, centerY, 5)
    }

    fun applyMetrics(newMetrics: TextMetrics) {
        this.metrics = newMetrics
        
        // Growth probability mapped from sentiment (-1..1 -> 0.15..0.85)
        growthProbability = ((metrics.sentiment + 1.0) / 2.0).coerceIn(0.1, 0.9) * 0.7 + 0.15
        
        // Branching tendency driven by lexical diversity
        branchingTendency = metrics.lexicalDiversity.coerceIn(0.1, 0.95)
        
        // Age of lichen patches driven by average word length
        maxLichenAge = (metrics.avgWordLength * 25.0).toInt().coerceIn(40, 300)

        // Palette mapping: Positive = Vibrant Greens/Cyans/Yellows, Negative = Deep Purples/Red-Browns
        hueBase = when {
            metrics.sentiment > 0.2 -> 0.25f + (metrics.sentiment * 0.2f).toFloat() // Yellow-green to cyan
            metrics.sentiment < -0.2 -> 0.8f + (metrics.sentiment * 0.15f).toFloat() // Red-violet to magenta
            else -> 0.12f // Earthy Ochre / Moss Brown
        }
        hueVariance = (metrics.lexicalDiversity * 0.3).toFloat()
    }

    private fun seedSpores(cx: Int, cy: Int, count: Int) {
        for (i in 0 until count) {
            val rx = (cx + rand.nextInt(-15, 16)).coerceIn(0, widthCells - 1)
            val ry = (cy + rand.nextInt(-15, 16)).coerceIn(0, heightCells - 1)
            grid[rx][ry].apply {
                age = 1
                energy = 1.0
                maxAge = maxLichenAge + rand.nextInt(-20, 21)
                branchFactor = branchingTendency
                colorIndex = rand.nextFloat()
            }
        }
    }

    fun updateSimulation() {
        for (x in 0 until widthCells) {
            for (y in 0 until heightCells) {
                nextGrid[x][y] = Cell(
                    age = grid[x][y].age,
                    energy = grid[x][y].energy,
                    maxAge = grid[x][y].maxAge,
                    branchFactor = grid[x][y].branchFactor,
                    colorIndex = grid[x][y].colorIndex
                )
            }
        }

        val dx = intArrayOf(-1, 0, 1, -1, 1, -1, 0, 1)
        val dy = intArrayOf(-1, -1, -1, 0, 0, 1, 1, 1)

        for (x in 0 until widthCells) {
            for (y in 0 until heightCells) {
                val current = grid[x][y]
                if (current.age > 0) {
                    // Aging process
                    nextGrid[x][y].age++
                    
                    // Death condition
                    if (nextGrid[x][y].age > current.maxAge) {
                        nextGrid[x][y].age = 0
                        nextGrid[x][y].energy = 0.0
                        continue
                    }

                    // Count living neighbors to steer cellular growth
                    var neighbors = 0
                    for (i in 0 until 8) {
                        val nx = x + dx[i]
                        val ny = y + dy[i]
                        if (nx in 0 until widthCells && ny in 0 until heightCells && grid[nx][ny].age > 0) {
                            neighbors++
                        }
                    }

                    // Cellular Automata Growth Logic
                    if (neighbors in 1..4 && rand.nextDouble() < growthProbability) {
                        // Pick a random direction to grow into
                        val dirIndex = rand.nextInt(8)
                        val targetX = x + dx[dirIndex]
                        val targetY = y + dy[dirIndex]

                        if (targetX in 0 until widthCells && targetY in 0 until heightCells && grid[targetX][targetY].age == 0) {
                            val branchChance = rand.nextDouble()
                            if (branchChance < current.branchFactor) {
                                nextGrid[targetX][targetY].apply {
                                    age = 1
                                    energy = current.energy * 0.9
                                    maxAge = current.maxAge + rand.nextInt(-10, 11)
                                    branchFactor = (current.branchFactor * 0.98).coerceAtLeast(0.05)
                                    colorIndex = (current.colorIndex + rand.nextFloat() * 0.05f) % 1.0f
                                }
                            }
                        }
                    }
                }
            }
        }

        // Swap grids
        val temp = grid
        grid = nextGrid
        nextGrid = temp
        repaint()
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        val g2d = g as Graphics2D
        g2d.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        for (x in 0 until widthCells) {
            for (y in 0 until heightCells) {
                val cell = grid[x][y]
                if (cell.age > 0) {
                    val agePercent = cell.age.toFloat() / cell.maxAge.toFloat()
                    val brightness = (1.0f - agePercent * 0.6f).coerceIn(0.2f, 1.0f)
                    val saturation = (0.5f + (1.0f - agePercent) * 0.5f).coerceIn(0.1f, 1.0f)
                    
                    val hue = (hueBase + (cell.colorIndex - 0.5f) * hueVariance + (1.0f - agePercent) * 0.05f) % 1.0f
                    val finalHue = if (hue < 0) hue + 1.0f else hue

                    g2d.color = Color.getHSBColor(finalHue, saturation, brightness)
                    g2d.fillRect(x * cellSize, y * cellSize, cellSize, cellSize)
                }
            }
        }
    }

    fun resetAndSeed() {
        for (x in 0 until widthCells) {
            for (y in 0 until heightCells) {
                grid[x][y] = Cell()
            }
        }
        seedSpores(widthCells / 2, heightCells / 2, 8)
    }
}

fun main() {
    val initialText = """
        Deep within the ancient, sun-dappled forest, quiet life blooms with vibrant energy. 
        Bright lichen spreads across the damp bark, weaving intricate webs of golden green and turquoise vitality. 
        The air is rich with growth, sweetness, and light.
    """.trimIndent()

    val metrics = TextMetrics.analyze(initialText)

    SwingUtilities.invokeLater {
        val frame = JFrame("Interactive Text-Driven Lichen Colony (Cellular Automata)")
        frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
        frame.layout = BorderLayout()

        val canvas = LichenCanvas(200, 150, metrics)
        frame.add(canvas, BorderLayout.CENTER)

        val controlPanel = JPanel(BorderLayout())
        val inputArea = JTextArea(initialText, 4, 50)
        inputArea.lineWrap = true
        inputArea.wrapStyleWord = true

        val statsLabel = JLabel(
            "  Sentiment: %.2f | Diversity: %.2f | Avg Length: %.1f".format(
                metrics.sentiment, metrics.lexicalDiversity, metrics.avgWordLength
            )
        )

        val updateButton = JButton("Re-parse Text & Regrow")
        updateButton.addActionListener {
            val text = inputArea.text
            val newMetrics = TextMetrics.analyze(text)
            statsLabel.text = "  Sentiment: %.2f | Diversity: %.2f | Avg Length: %.1f".format(
                newMetrics.sentiment, newMetrics.lexicalDiversity, newMetrics.avgWordLength
            )
            canvas.applyMetrics(newMetrics)
            canvas.resetAndSeed()
        }

        val topPanel = JPanel(BorderLayout())
        topPanel.add(JLabel(" Enter any text passage to drive lichen genetics:"), BorderLayout.NORTH)
        topPanel.add(JScrollPane(inputArea), BorderLayout.CENTER)

        val bottomPanel = JPanel(BorderLayout())
        bottomPanel.add(statsLabel, BorderLayout.WEST)
        bottomPanel.add(updateButton, BorderLayout.EAST)

        controlPanel.add(topPanel, BorderLayout.CENTER)
        controlPanel.add(bottomPanel, BorderLayout.SOUTH)
        frame.add(controlPanel, BorderLayout.SOUTH)

        frame.pack()
        frame.setLocationRelativeTo(null)
        frame.isVisible = true

        // Simulation Loop
        Timer(40) {
            canvas.updateSimulation()
        }.start()
    }
}