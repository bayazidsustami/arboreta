import javafx.application.Application
import javafx.application.Platform
import javafx.scene.*
import javafx.scene.canvas.*
import javafx.scene.input.KeyCode
import javafx.scene.paint.Color
import javafx.stage.Stage
import javafx.animation.AnimationTimer
import java.util.concurrent.*
import javax.sound.sampled.*
import kotlin.math.*

// ---------- Audio capture & simple FFT ----------
class AudioAnalyzer {
    private val format = AudioFormat(44100f, 16, 1, true, false)
    private val line: TargetDataLine = AudioSystem.getLine(DataLine.Info(TargetDataLine::class.java, format)) as TargetDataLine
    private val buffer = ByteArray(1024)
    private val window = DoubleArray(512) { 0.5 * (1 - cos(2 * Math.PI * it / 1023)) } // Hann
    var amplitude = 0.0
        private set
    var dominantFreq = 0.0
        private set

    init {
        line.open(format, buffer.size)
        line.start()
        Executors.newSingleThreadExecutor().submit { process() }
    }

    private fun process() {
        while (true) {
            val read = line.read(buffer, 0, buffer.size)
            if (read <= 0) continue
            // convert to double array
            val samples = DoubleArray(512)
            var idx = 0
            for (i in 0 until read step 2) {
                val low = buffer[i].toInt() and 0xFF
                val high = buffer[i + 1].toInt()
                var sample = (high shl 8) or low
                if (sample > 32767) sample -= 65536
                samples[idx++] = sample / 32768.0 * window[idx - 1]
                if (idx >= samples.size) break
            }
            // simple magnitude & dominant frequency (peak naive)
            var maxMag = 0.0
            var maxBin = 0
            for (k in 0 until samples.size / 2) {
                var re = 0.0
                var im = 0.0
                for (n in samples.indices) {
                    val angle = 2.0 * Math.PI * k * n / samples.size
                    re += samples[n] * cos(angle)
                    im -= samples[n] * sin(angle)
                }
                val mag = sqrt(re * re + im * im)
                if (mag > maxMag) {
                    maxMag = mag
                    maxBin = k
                }
            }
            amplitude = samples.map { abs(it) }.average()
            dominantFreq = maxBin * format.sampleRate / samples.size
        }
    }
}

// ---------- Cellular automaton rule ----------
data class Cell(var hue: Double, var speed: Double)

class Automaton(width: Int, height: Int) {
    private val cols = width
    private val rows = height
    private val cells = Array(rows) { Array(cols) { Cell(Math.random() * 360, Math.random() * 0.5 + 0.1) } }

    // simple rule: neighbors average hue, speed modulated by external factor
    fun step(freqFactor: Double, ampFactor: Double) {
        val next = Array(rows) { Array(cols) { Cell(0.0, 0.0) } }
        for (y in 0 until rows) {
            for (x in 0 until cols) {
                var sumHue = 0.0
                var cnt = 0
                for (dy in -1..1) for (dx in -1..1) {
                    if (dx == 0 && dy == 0) continue
                    val nx = (x + dx + cols) % cols
                    val ny = (y + dy + rows) % rows
                    sumHue += cells[ny][nx].hue
                    cnt++
                }
                val avgHue = sumHue / cnt
                val newHue = (avgHue + freqFactor * 30) % 360
                val newSpeed = cells[y][x].speed * (1 + ampFactor * 0.5)
                next[y][x] = Cell(newHue, newSpeed)
            }
        }
        for (y in 0 until rows) for (x in 0 until cols) cells[y][x] = next[y][x]
    }

    fun getCells(): Array<Array<Cell>> = cells
}

// ---------- Voronoi rendering ----------
class VoronoiCanvas(private val width: Int, private val height: Int) : Canvas(width.toDouble(), height.toDouble()) {
    private val points = mutableListOf<Pair<Double, Double>>()
    private val colors = mutableListOf<Color>()
    private val rand = java.util.Random()

    init {
        // seed random points
        repeat(50) {
            points.add(rand.nextDouble() * width to rand.nextDouble() * height)
            colors.add(Color.hsb(rand.nextDouble() * 360, 0.7, 0.9))
        }
        graphicsContext2D.imageSmoothing = false
    }

    fun update(cells: Array<Array<Cell>>, time: Double) {
        // move points according to cell speeds
        for (i in points.indices) {
            val cell = cells[i % cells.size][i % cells[0].size]
            var (x, y) = points[i]
            val angle = Math.toRadians(cell.hue)
            x = (x + cos(angle) * cell.speed * 2).mod(width.toDouble())
            y = (y + sin(angle) * cell.speed * 2).mod(height.toDouble())
            points[i] = x to y
            colors[i] = Color.hsb(cell.hue, 0.7, 0.9, 0.6 + 0.4 * sin(time * cell.speed))
        }
        draw()
    }

    private fun draw() {
        val gc = graphicsContext2D
        gc.clearRect(0.0, 0.0, width.toDouble(), height.toDouble())
        val img = WritableImage(width, height)
        val pixelWriter = img.pixelWriter
        for (y in 0 until height) {
            for (x in 0 until width) {
                var best = Double.MAX_VALUE
                var bestIdx = 0
                for (i in points.indices) {
                    val (px, py) = points[i]
                    val d = (x - px).pow(2) + (y - py).pow(2)
                    if (d < best) {
                        best = d
                        bestIdx = i
                    }
                }
                pixelWriter.setColor(x, y, colors[bestIdx])
            }
        }
        gc.drawImage(img, 0.0, 0.0)
    }
}

// ---------- Main Application ----------
class AudioVoronoiApp : Application() {
    private lateinit var analyzer: AudioAnalyzer
    private lateinit var automaton: Automaton
    private lateinit var voronoi: VoronoiCanvas
    private var startTime = 0L

    override fun start(primaryStage: Stage) {
        val w = 800
        val h = 600
        analyzer = AudioAnalyzer()
        automaton = Automaton(20, 15)
        voronoi = VoronoiCanvas(w, h)

        val root = Group(voronoi)
        val scene = Scene(root, w.toDouble(), h.toDouble(), Color.BLACK)

        // simple phoneme trigger: space toggles random rule seed
        scene.setOnKeyPressed { e ->
            if (e.code == KeyCode.SPACE) {
                // reseed automaton with fresh random hues
                automaton = Automaton(20, 15)
            }
        }

        primaryStage.title = "Audio‑Reactive Voronoi"
        primaryStage.scene = scene
        primaryStage.show()

        startTime = System.nanoTime()
        val timer = object : AnimationTimer() {
            override fun handle(now: Long) {
                val t = (now - startTime) / 1e9
                val freqFactor = analyzer.dominantFreq / 500.0
                val ampFactor = analyzer.amplitude * 2
                automaton.step(freqFactor, ampFactor)
                voronoi.update(automaton.getCells(), t)
            }
        }
        timer.start()
    }

    override fun stop() {
        Platform.exit()
        System.exit(0)
    }
}

fun main() {
    Application.launch(AudioVoronoiApp::class.java)
}