import javafx.application.Application
import javafx.application.Platform
import javafx.scene.Group
import javafx.scene.Scene
import javafx.scene.canvas.Canvas
import javafx.scene.canvas.GraphicsContext
import javafx.scene.paint.Color
import javafx.stage.Stage
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

// Simple emoji‑based language:
//   🔺 -> turn left 30°
//   🔻 -> turn right 30°
//   🟢 -> forward 20 and draw line
//   🔵 -> forward 20 without drawing
//   🟠 -> draw circle radius 10 at current position
//   🟣 -> change colour (cycles through a list)
//   🟡 -> pause 200 ms
// Any other token is ignored.
class MandalaApp : Application() {
    private val canvas = Canvas(800.0, 800.0)
    private val gc: GraphicsContext = canvas.graphicsContext2D
    private var x = canvas.width / 2
    private var y = canvas.height / 2
    private var angle = 0.0
    private var penDown = true
    private val colors = listOf(Color.RED, Color.ORANGE, Color.YELLOW, Color.GREEN, Color.BLUE, Color.PURPLE)
    private var colorIndex = 0

    // Map emojis to actions
    private val actions: Map<String, () -> Unit> = mapOf(
        "🔺" to { angle -= 30 },
        "🔻" to { angle += 30 },
        "🟢" to { move(20.0, draw = true) },
        "🔵" to { move(20.0, draw = false) },
        "🟠" to { gc.fillOval(x - 10, y - 10, 20.0, 20.0) },
        "🟣" to { colorIndex = (colorIndex + 1) % colors.size; gc.stroke = colors[colorIndex]; gc.fill = colors[colorIndex] },
        "🟡" to { Thread.sleep(200) }
    )

    override fun start(stage: Stage) {
        stage.scene = Scene(Group(canvas))
        stage.title = "Emoji Mandala"
        stage.show()
        gc.stroke = colors[colorIndex]
        gc.fill = colors[colorIndex]
        // Simulated live hashtag stream (replace with real source if needed)
        val simulated = listOf(
            "#art 🔺🟢🔻🟢🟣🟢🔺🟢🔻🟢🟠",
            "#code 🟣🔺🟢🔻🟢🟣🟠🔺🟢",
            "#loop 🟣🔺🟢🔻🟢🟣🟠🟡"
        )
        val executor = Executors.newSingleThreadScheduledExecutor()
        var index = 0
        executor.scheduleAtFixedRate({
            if (index >= simulated.size) {
                executor.shutdown()
                return@scheduleAtFixedRate
            }
            val line = simulated[index++]
            interpret(line)
        }, 0, 2, TimeUnit.SECONDS)
    }

    // Decode a line: keep only emojis, then execute sequentially
    private fun interpret(line: String) {
        val tokens = line.filter { it.isSurrogate() || it.isLetterOrDigit().not() }.trim().split("\\s+".toRegex())
        Platform.runLater {
            for (token in tokens) {
                actions[token]?.invoke()
            }
        }
    }

    private fun move(dist: Double, draw: Boolean) {
        val rad = Math.toRadians(angle)
        val nx = x + dist * Math.cos(rad)
        val ny = y + dist * Math.sin(rad)
        if (penDown && draw) {
            gc.strokeLine(x, y, nx, ny)
        }
        x = nx
        y = ny
    }
}

fun main() {
    Application.launch(MandalaApp::class.java)
}