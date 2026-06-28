import javafx.application.Application
import javafx.application.Platform
import javafx.scene.*
import javafx.scene.canvas.*
import javafx.scene.image.*
import javafx.scene.paint.Color
import javafx.stage.Stage
import javax.sound.sampled.*
import kotlin.math.*

// ---------------------- Audio capture & simple FFT ----------------------
private const val SAMPLE_RATE = 44100
private const val BUFFER_SIZE = 1024 // power of two
private const val BANDS = 64          // number of frequency bands to visualise

class AudioProcessor(private val onSpectrum: (FloatArray) -> Unit) : Thread("AudioProcessor") {
    private val format = AudioFormat(SAMPLE_RATE.toFloat(), 16, 1, true, true)
    private val line: TargetDataLine = AudioSystem.getLine(DataLine.Info(TargetDataLine::class.java, format)) as TargetDataLine

    init { line.open(format, BUFFER_SIZE * 2); line.start() }

    override fun run() {
        val bytes = ByteArray(BUFFER_SIZE * 2) // 16‑bit samples
        val window = FloatArray(BUFFER_SIZE) { i -> (0.5f * (1 - cos(2 * Math.PI * i / (BUFFER_SIZE - 1)))).toFloat() } // Hann
        while (!interrupted()) {
            val read = line.read(bytes, 0, bytes.size)
            if (read < bytes.size) continue
            val samples = FloatArray(BUFFER_SIZE) { i ->
                // convert little‑endian 16‑bit signed
                val hi = bytes[2*i].toInt()
                val lo = bytes[2*i+1].toInt()
                ((hi shl 8) or (lo and 0xFF)).toShort() / 32768f * window[i]
            }
            val spectrum = fftMagnitude(samples)
            onSpectrum(spectrum)
        }
    }

    private fun fftMagnitude(real: FloatArray): FloatArray {
        val n = real.size
        val imag = FloatArray(n)
        // bit‑reversal permutation
        var j = 0
        for (i in 1 until n) {
            var bit = n shr 1
            while (j >= bit) { j -= bit; bit = bit shr 1 }
            j += bit
            if (i < j) {
                val tmpR = real[i]; real[i] = real[j]; real[j] = tmpR
                val tmpI = imag[i]; imag[i] = imag[j]; imag[j] = tmpI
            }
        }
        // Cooley‑Tukey
        var len = 2
        while (len <= n) {
            val half = len / 2
            val theta = -2.0 * Math.PI / len
            val wtemp = sin(0.5 * theta)
            val wpr = -2.0 * wtemp * wtemp
            val wpi = sin(theta)
            var wr = 1.0
            var wi = 0.0
            for (m in 0 until half) {
                var i = m
                while (i < n) {
                    val j2 = i + half
                    val tr = (wr * real[j2] - wi * imag[j2]).toFloat()
                    val ti = (wr * imag[j2] + wi * real[j2]).toFloat()
                    real[j2] = real[i] - tr
                    imag[j2] = imag[i] - ti
                    real[i] += tr
                    imag[i] += ti
                    i += len
                }
                val wtempR = wr
                wr = wtempR * wpr - wi * wpi + wr
                wi = wi * wpr + wtempR * wpi + wi
            }
            len = len shl 1
        }
        // magnitude (only first half needed)
        val mags = FloatArray(BANDS)
        val bandSize = n / 2 / BANDS
        for (b in 0 until BANDS) {
            var sum = 0f
            for (k in 0 until bandSize) {
                val idx = b * bandSize + k
                sum += sqrt(real[idx] * real[idx] + imag[idx] * imag[idx])
            }
            mags[b] = sum / bandSize
        }
        return mags
    }
}

// ---------------------- Fractal colour mapping ----------------------
private fun mandelbrotColor(x: Float, y: Float, z: Float): Color {
    var zx = x
    var zy = y
    var zz = z
    var iter = 0
    val maxIter = 40
    while (zx*zx + zy*zy + zz*zz < 4.0 && iter < maxIter) {
        // 3‑D Mandelbrot‑like iteration
        val nx = zx*zx - zy*zy - zz*zz + x
        val ny = 2*zx*zy + y
        val nz = 2*zx*zz + z
        zx = nx; zy = ny; zz = nz
        iter++
    }
    val hue = (iter.toFloat() / maxIter) * 360f
    val sat = 0.7f
    val bri = 0.6f + 0.4f * (iter.toFloat() / maxIter)
    return Color.hsb(hue, sat, bri)
}

// ---------------------- JavaFX visualisation ----------------------
class KaleidoApp : Application() {
    private lateinit var canvas: Canvas
    private lateinit var gc: GraphicsContext
    private val amplitudes = FloatArray(BANDS) { 0f }

    override fun start(primaryStage: Stage) {
        canvas = Canvas(800.0, 800.0)
        gc = canvas.graphicsContext2D
        val root = Group(canvas)
        primaryStage.scene = Scene(root)
        primaryStage.title = "Audio Kaleidoscope"
        primaryStage.show()

        // start audio thread
        val audio = AudioProcessor { spectrum ->
            System.arraycopy(spectrum, 0, amplitudes, 0, BANDS)
            Platform.runLater { draw() }
        }
        audio.isDaemon = true
        audio.start()

        // initial clear
        gc.fill = Color.BLACK
        gc.fillRect(0.0, 0.0, canvas.width, canvas.height)
    }

    private fun draw() {
        val w = canvas.width.toInt()
        val h = canvas.height.toInt()
        val cols = 8
        val rows = 8
        val tileW = w / cols
        val tileH = h / rows

        for (row in 0 until rows) {
            for (col in 0 until cols) {
                val band = (row * cols + col) % BANDS
                val amp = amplitudes[band]
                // map amplitude (0‑~) to size & opacity
                val scale = 0.3 + 0.7 * (amp / 10f).coerceIn(0f, 1f)
                val sizeW = tileW * scale
                val sizeH = tileH * scale
                val offX = (tileW - sizeW) / 2
                val offY = (tileH - sizeH) / 2

                // fractal colour based on band index as (x,y,z) in [-1,1]
                val fx = (col.toFloat() / cols) * 2f - 1f
                val fy = (row.toFloat() / rows) * 2f - 1f
                val fz = (band.toFloat() / BANDS) * 2f - 1f
                val colr = mandelbrotColor(fx, fy, fz).deriveColor(0.0, 1.0, 1.0, (0.3 + 0.7 * (amp / 10f)).coerceIn(0.2, 1.0))

                gc.fill = colr
                gc.fillRect(
                    col * tileW + offX,
                    row * tileH + offY,
                    sizeW,
                    sizeH
                )
            }
        }
    }
}

fun main() {
    Application.launch(KaleidoApp::class.java)
}