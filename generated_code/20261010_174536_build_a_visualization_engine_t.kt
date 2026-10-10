import javax.swing.*
import java.awt.*
import java.nio.file.*
import java.util.concurrent.ConcurrentHashMap
import kotlin.concurrent.thread
import kotlin.random.Random

// Cathedral of Code: Medieval Stained Glass File System Entropy Visualizer
// Renders real-time file system events as glowing stained glass panes,
// igniting newly created files into flickering cobalt flames and melting lead lines on deletion.

fun main() {
    val watchDir = Paths.get(System.getProperty("user.home"), "Desktop")
    val window = StainedGlassWindow(watchDir)
    window.isVisible = true
    window.startWatching()
}

class StainedGlassWindow(private val watchDir: Path) : JFrame("Cathedral of Code: Stained Glass Entropy") {
    private val panel = GlassPanel()

    init {
        defaultCloseOperation = EXIT_ON_CLOSE
        setSize(900, 900)
        setLocationRelativeTo(null)
        add(panel)
    }

    fun startWatching() {
        thread(isDaemon = true) {
            try {
                val watchService = FileSystems.getDefault().newWatchService()
                if (Files.exists(watchDir)) {
                    watchDir.register(
                        watchService,
                        StandardWatchEventKinds.ENTRY_CREATE,
                        StandardWatchEventKinds.ENTRY_DELETE,
                        StandardWatchEventKinds.ENTRY_MODIFY
                    )
                }

                while (true) {
                    val key = watchService.take()
                    for (event in key.pollEvents()) {
                        val kind = event.kind()
                        val filename = event.context().toString()
                        SwingUtilities.invokeLater {
                            panel.triggerEffect(kind, filename)
                        }
                    }
                    key.reset()
                }
            } catch (e: Exception) {
                // Graceful fallback if directory access fails
            }
        }
    }
}

class GlassPanel : JPanel() {
    private val cells = ConcurrentHashMap<String, CellState>()

    init {
        background = Color(20, 15, 25)
        Timer(35) {
            cells.values.forEach { it.update() }
            repaint()
        }.start()
    }

    fun triggerEffect(kind: WatchEvent.Kind<*>, name: String) {
        val state = cells.getOrPut(name) { CellState(name) }
        when (kind) {
            StandardWatchEventKinds.ENTRY_CREATE -> state.igniteCobaltFlame()
            StandardWatchEventKinds.ENTRY_DELETE -> state.meltLead()
            StandardWatchEventKinds.ENTRY_MODIFY -> state.shimmer()
        }
        repaint()
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        val g2d = g as Graphics2D
        g2d.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        val cols = 6
        val rows = 6
        val cellWidth = width / cols
        val cellHeight = height / rows

        var index = 0
        for ((_, state) in cells) {
            if (index >= cols * rows) break
            val col = index % cols
            val row = index / cols
            val x = col * cellWidth
            val y = row * cellHeight

            // Stained glass pane color body
            g2d.color = Color(
                (state.r * 255).toInt().coerceIn(0, 255),
                (state.g * 255).toInt().coerceIn(0, 255),
                (state.b * 255).toInt().coerceIn(0, 255)
            )
            g2d.fillRect(x + 6, y + 6, cellWidth - 12, cellHeight - 12)

            // Flickering Cobalt Flame effect for new files
            if (state.flameIntensity > 0f) {
                g2d.color = Color(0, 102, 255, (state.flameIntensity * 200).toInt().coerceIn(0, 255))
                g2d.fillOval(x + cellWidth / 4, y + cellHeight / 4, cellWidth / 2, cellHeight / 2)
            }

            // Lead lines (thick medieval borders, melting away if deleted)
            val strokeWidth = if (state.isMelting) (4f + state.meltAmount * 8f) else 5f
            g2d.stroke = BasicStroke(strokeWidth)
            g2d.color = if (state.isMelting) {
                Color(50, 30, 20, (255 * (1f - state.meltAmount)).toInt().coerceIn(0, 255))
            } else {
                Color(30, 25, 35)
            }
            g2d.drawRect(x + 4, y + 4, cellWidth - 8, cellHeight - 8)

            index++
        }
    }
}

class CellState(val name: String) {
    var r = Random.nextFloat() * 0.4f + 0.1f
    var g = Random.nextFloat() * 0.3f + 0.1f
    var b = Random.nextFloat() * 0.5f + 0.3f
    var flameIntensity = 0f
    var isMelting = false
    var meltAmount = 0f

    fun igniteCobaltFlame() {
        flameIntensity = 1.0f
        r = 0.05f
        g = 0.2f
        b = 0.95f
    }

    fun meltLead() {
        isMelting = true
        meltAmount = 0f
    }

    fun shimmer() {
        r = (r + 0.2f) % 1.0f
    }

    fun update() {
        if (flameIntensity > 0f) {
            flameIntensity -= 0.04f
        }
        if (isMelting) {
            meltAmount += 0.025f
            if (meltAmount >= 1.0f) {
                meltAmount = 1.0f
            }
        }
    }
}