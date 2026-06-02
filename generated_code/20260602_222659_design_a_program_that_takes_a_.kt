import java.awt.*
import java.awt.event.*
import java.awt.geom.*
import javax.sound.sampled.*
import javax.swing.*
import kotlin.math.*

// Simple FFT implementation (radix-2, in-place)
private fun fft(real: DoubleArray, imag: DoubleArray) {
    val n = real.size
    var j = 0
    // Bit-reverse copy
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
    // Danielson-Lanczos
    var len = 2
    while (len <= n) {
        val half = len shr 1
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
                val tr = wr * real[j2] - wi * imag[j2]
                val ti = wr * imag[j2] + wi * real[j2]
                real[j2] = real[i] - tr
                imag[j2] = imag[i] - ti
                real[i] += tr
                imag[i] += ti
                i += len
            }
            val wtemp2 = wr
            wr = wtemp2 * wpr - wi * wpi + wr
            wi = wi * wpr + wtemp2 * wpi + wi
        }
        len = len shl 1
    }
}

// Convert audio bytes to double array (mono, normalized)
private fun bytesToDoubles(buf: ByteArray, bytesRead: Int): DoubleArray {
    val len = bytesRead / 2
    val d = DoubleArray(len)
    var i = 0
    var idx = 0
    while (i < len) {
        val low = buf[idx].toInt() and 0xff
        val high = buf[idx + 1].toInt()
        val sample = (high shl 8) or low
        d[i] = sample / 32768.0
        i++; idx += 2
    }
    return d
}

// Mapping magnitude to brushstroke parameters
private fun drawBrush(g2: Graphics2D, width: Int, height: Int, magnitudes: DoubleArray, time: Long) {
    val bands = 32
    val bandSize = magnitudes.size / bands
    for (b in 0 until bands) {
        var sum = 0.0
        for (i in 0 until bandSize) sum += magnitudes[b * bandSize + i]
        val amp = sum / bandSize
        val hue = (b.toFloat() / bands + (time % 10000) / 10000f) % 1f
        val sat = 0.6f + 0.4f * amp.toFloat()
        val bright = 0.4f + 0.6f * amp.toFloat()
        g2.color = Color.getHSBColor(hue, sat, bright)

        val radius = (amp * 300).coerceAtLeast(5.0).toFloat()
        val angle = (2 * Math.PI * b / bands).toFloat()
        val cx = width / 2 + cos(angle) * 100
        val cy = height / 2 + sin(angle) * 100

        val path = Path2D.Float()
        path.moveTo(cx, cy)
        path.curveTo(
            cx + radius * cos(angle - Math.PI / 4).toFloat(),
            cy + radius * sin(angle - Math.PI / 4).toFloat(),
            cx + radius * cos(angle + Math.PI / 4).toFloat(),
            cy + radius * sin(angle + Math.PI / 4).toFloat(),
            cx, cy
        )
        g2.stroke = BasicStroke(radius / 10f, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)
        g2.draw(path)

        // Hidden Morse: toggle background on specific bands
        if (b == 5 && amp > 0.6) { // dot
            g2.composite = AlphaComposite.getInstance(AlphaComposite.SRC_OVER, 0.1f)
            g2.fillRect(0, 0, width, height)
            g2.composite = AlphaComposite.SrcOver
        }
        if (b == 15 && amp > 0.6) { // dash
            g2.composite = AlphaComposite.getInstance(AlphaComposite.SRC_OVER, 0.3f)
            g2.fillRect(0, 0, width, height)
            g2.composite = AlphaComposite.SrcOver
        }
    }
}

// Main canvas panel
class AudioCanvas : JPanel() {
    private var magnitudes = DoubleArray(0)
    private var lastTime = System.currentTimeMillis()

    init {
        background = Color.BLACK
        preferredSize = Dimension(800, 600)
        // Repaint loop
        Timer(33) { repaint() }.start()
    }

    fun updateMagnitudes(mags: DoubleArray) {
        this.magnitudes = mags
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        val g2 = g as Graphics2D
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)
        val now = System.currentTimeMillis()
        if (magnitudes.isNotEmpty()) drawBrush(g2, width, height, magnitudes, now)
        lastTime = now
    }
}

// Audio capture thread
class AudioProcessor(private val canvas: AudioCanvas) : Thread() {
    private val format = AudioFormat(44100f, 16, 1, true, false)
    private val line: TargetDataLine = AudioSystem.getTargetDataLine(format)

    init {
        line.open(format, 4096)
        line.start()
    }

    override fun run() {
        val buffer = ByteArray(4096)
        while (true) {
            val bytesRead = line.read(buffer, 0, buffer.size)
            if (bytesRead > 0) {
                val samples = bytesToDoubles(buffer, bytesRead)
                val n = 1 shl (log2(samples.size.toDouble()).toInt())
                val real = DoubleArray(n)
                val imag = DoubleArray(n)
                System.arraycopy(samples, 0, real, 0, min(samples.size, n))
                fft(real, imag)
                val mags = DoubleArray(n / 2) { i -> sqrt(real[i] * real[i] + imag[i] * imag[i]) }
                canvas.updateMagnitudes(mags)
            }
        }
    }
}

// Helper log2
private fun log2(x: Double) = ln(x) / ln(2.0)

// Entry point
fun main() {
    SwingUtilities.invokeLater {
        val frame = JFrame("Audio‑Driven Generative Canvas")
        val canvas = AudioCanvas()
        frame.contentPane.add(canvas)
        frame.pack()
        frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
        frame.isVisible = true
        AudioProcessor(canvas).start()
    }
}