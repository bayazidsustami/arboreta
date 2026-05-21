import javafx.application.Application
import javafx.application.Platform
import javafx.embed.swing.JFXPanel
import javafx.scene.Scene
import javafx.scene.canvas.Canvas
import javafx.scene.canvas.GraphicsContext
import javafx.scene.image.PixelWriter
import javafx.scene.layout.StackPane
import javafx.scene.paint.Color
import javafx.stage.Stage
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import javax.sound.sampled.AudioFormat
import javax.sound.sampled.AudioSystem
import kotlin.math.*

// Simple FFT implementation (radix-2, in-place)
private fun fft(real: DoubleArray, imag: DoubleArray) {
    val n = real.size
    var j = 0
    for (i in 1 until n) {
        var bit = n shr 1
        while (j and bit != 0) {
            j = j xor bit
            bit = bit shr 1
        }
        j = j xor bit
        if (i < j) {
            val tr = real[i]; real[i] = real[j]; real[j] = tr
            val ti = imag[i]; imag[i] = imag[j]; imag[j] = ti
        }
    }
    var len = 2
    while (len <= n) {
        val ang = -2.0 * Math.PI / len
        val wlenCos = cos(ang)
        val wlenSin = sin(ang)
        var i = 0
        while (i < n) {
            var wCos = 1.0
            var wSin = 0.0
            for (k in 0 until len / 2) {
                val uRe = real[i + k]
                val uIm = imag[i + k]
                val vRe = real[i + k + len / 2] * wCos - imag[i + k + len / 2] * wSin
                val vIm = real[i + k + len / 2] * wSin + imag[i + k + len / 2] * wCos
                real[i + k] = uRe + vRe
                imag[i + k] = uIm + vIm
                real[i + k + len / 2] = uRe - vRe
                imag[i + k + len / 2] = uIm - vIm
                val nextWCos = wCos * wlenCos - wSin * wlenSin
                val nextWSin = wCos * wlenSin + wSin * wlenCos
                wCos = nextWCos
                wSin = nextWSin
            }
            i += len
        }
        len = len shl 1
    }
}

// Mapping each frequency bin to a 8‑bit elementary CA rule (0‑255) and a hue
private data class BinRule(val rule: Int, val hue: Double)

// Cellular automaton on a toroidal grid
private class ToroidalCA(val width: Int, val height: Int, val binRules: List<BinRule>) {
    private val cells = Array(height) { IntArray(width) }   // 0 or 1
    private val colors = Array(height) { IntArray(width) } // RGB packed int
    private val rand = java.util.Random()

    init {
        // random initial state
        for (y in 0 until height) for (x in 0 until width) cells[y][x] = rand.nextInt(2)
    }

    // one step using the rule assigned to the column (frequency bin)
    fun step() {
        val newCells = Array(height) { IntArray(width) }
        for (y in 0 until height) {
            for (x in 0 until width) {
                val left = cells[y][(x - 1 + width) % width]
                val center = cells[y][x]
                val right = cells[y][(x + 1) % width]
                val idx = (left shl 2) or (center shl 1) or right
                val rule = binRules[x % binRules.size].rule
                newCells[y][x] = (rule shr idx) and 1
                // assign color based on rule hue
                val hue = binRules[x % binRules.size].hue
                colors[y][x] = Color.hsb(hue, 1.0, if (newCells[y][x] == 1) 1.0 else 0.2).hashCode()
            }
        }
        for (y in 0 until height) System.arraycopy(newCells[y], 0, cells[y], 0, width)
    }

    fun draw(g: GraphicsContext, cellSize: Double) {
        val pw: PixelWriter = g.pixelWriter
        for (y in 0 until height) {
            for (x in 0 until width) {
                val col = Color.web(String.format("#%06X", colors[y][x] and 0xFFFFFF))
                pw.setColor((x * cellSize).toInt(), (y * cellSize).toInt(), col)
            }
        }
    }
}

// Main Application
class SynestheticApp : Application() {
    private val sampleRate = 44100
    private val bufferSize = 1024                      // must be power of two
    private val fftBins = bufferSize / 2
    private val cellSize = 4.0
    private val gridWidth = fftBins
    private val gridHeight = 80
    private lateinit var ca: ToroidalCA
    private lateinit var gc: GraphicsContext
    private val executor = Executors.newSingleThreadScheduledExecutor()

    override fun start(primaryStage: Stage) {
        // Prepare UI
        val canvas = Canvas(gridWidth * cellSize, gridHeight * cellSize)
        gc = canvas.graphicsContext2D
        primaryStage.scene = Scene(StackPane(canvas))
        primaryStage.title = "Audio‑Driven Cellular Automata"
        primaryStage.show()

        // Build bin → rule mapping (random hue per bin)
        val binRules = List(fftBins) { i ->
            val rule = (0..255).random()
            val hue = (i.toDouble() / fftBins) * 360.0
            BinRule(rule, hue)
        }
        ca = ToroidalCA(gridWidth, gridHeight, binRules)

        // Start audio capture thread
        startAudioCapture()

        // Visual update loop (≈30 fps)
        executor.scheduleAtFixedRate({
            Platform.runLater {
                ca.step()
                ca.draw(gc, cellSize)
            }
        }, 0, 33, TimeUnit.MILLISECONDS)
    }

    private fun startAudioCapture() {
        val format = AudioFormat(sampleRate.toFloat(), 16, 1, true, true)
        val line = AudioSystem.getTargetDataLine(format)
        line.open(format, bufferSize * 2)
        line.start()
        val thread = Thread {
            val byteBuf = ByteArray(bufferSize * 2)
            val shortBuf = ShortArray(bufferSize)
            val real = DoubleArray(bufferSize)
            val imag = DoubleArray(bufferSize)
            while (!Thread.interrupted()) {
                val read = line.read(byteBuf, 0, byteBuf.size)
                if (read < byteBuf.size) continue
                // convert bytes → signed shorts → doubles
                val bb = ByteBuffer.wrap(byteBuf)
                for (i in 0 until bufferSize) {
                    shortBuf[i] = bb.short
                    real[i] = shortBuf[i].toDouble()
                    imag[i] = 0.0
                }
                // FFT
                fft(real, imag)
                // compute magnitude and update CA rules dynamically (optional)
                for (i in 0 until fftBins) {
                    val magnitude = sqrt(real[i] * real[i] + imag[i] * imag[i])
                    // modulate the rule of the corresponding column by magnitude (simple approach)
                    val factor = (1.0 + magnitude / 1e5).coerceAtMost(2.0)
                    val bin = ca.binRules[i]
                    val newRule = ((bin.rule * factor).toInt() and 0xFF)
                    ca.binRules[i] = bin.copy(rule = newRule)
                }
            }
            line.close()
        }
        thread.isDaemon = true
        thread.start()
    }

    override fun stop() {
        executor.shutdownNow()
    }
}

// Launch JavaFX from plain Kotlin script
fun main() {
    // Needed to initialise JavaFX toolkit in a pure Kotlin/JVM environment
    JFXPanel()
    Application.launch(SynestheticApp::class.java)
}