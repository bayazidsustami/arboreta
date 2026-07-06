import java.awt.*
import java.awt.geom.*
import java.awt.image.*
import java.io.*
import javax.imageio.ImageIO
import javax.sound.sampled.*
import kotlin.math.*

/**
 * Simple audio‑visual ouroboros generator.
 * Reads a mono WAV, computes short‑time FFT, maps frequency bands to brush strokes,
 * draws a series of frames, and writes them as a looping animated GIF.
 */
fun main() {
    val audioFile = File("input.wav")                     // → place a wav file here
    val frames = 120                                      // number of GIF frames
    val width = 800
    val height = 600
    val fps = 30

    // ----- 1. Load audio data -------------------------------------------------
    val audioInput = AudioSystem.getAudioInputStream(audioFile)
    val format = audioInput.format
    require(format.encoding == AudioFormat.Encoding.PCM_SIGNED) { "Only PCM WAV supported" }
    val bytes = audioInput.readBytes()
    val samples = ByteArrayInputStream(bytes).readShorts(format.isBigEndian)
    audioInput.close()

    // ----- 2. Prepare FFT -----------------------------------------------------
    val fftSize = 1024
    val hopSize = fftSize / 2
    val window = DoubleArray(fftSize) { i -> 0.5 * (1 - cos(2 * Math.PI * i / (fftSize - 1))) } // Hann

    // ----- 3. Prepare GIF writer ------------------------------------------------
    val output = ImageOutputStream(File("output.gif"))
    val gifWriter = GifSequenceWriter(output, BufferedImage.TYPE_INT_ARGB, 1000 / fps, true)

    // ----- 4. Generate frames --------------------------------------------------
    var phase = 0.0
    var canvas = BufferedImage(width, height, BufferedImage.TYPE_INT_ARGB)
    val gCanvas = canvas.createGraphics()
    gCanvas.paint = Color(0, 0, 0, 0)
    gCanvas.fillRect(0, 0, width, height)

    for (frameIdx in 0 until frames) {
        // Determine which audio slice corresponds to this frame
        val startSample = (frameIdx * hopSize) % samples.size
        val slice = DoubleArray(fftSize) { i ->
            val idx = (startSample + i) % samples.size
            samples[idx] * window[i]
        }

        // FFT (radix‑2 Cooley‑Tukey, naive for brevity)
        val (real, imag) = fft(slice)

        // Magnitude spectrum
        val mags = DoubleArray(fftSize / 2) { i -> sqrt(real[i] * real[i] + imag[i] * imag[i]) }

        // ----- 5. Paint strokes ------------------------------------------------
        val g = canvas.createGraphics()
        g.composite = AlphaComposite.getInstance(AlphaComposite.SRC_OVER, 0.15f) // fade previous strokes
        g.color = Color(0, 0, 0, 10)
        g.fillRect(0, 0, width, height)

        for (band in 0 until mags.size step 4) {
            val amp = mags[band] / (fftSize * 32768.0)            // normalise
            val hue = (band.toFloat() / mags.size) * 360f
            val sat = 0.7f
            val bri = (0.3 + 0.7 * amp).toFloat().coerceIn(0f, 1f)
            val col = Color.getHSBColor(hue / 360f, sat, bri)

            val size = (20 + 200 * amp).toInt()
            val angle = phase + band * 0.01
            val x = (width / 2 + cos(angle) * (width / 3)).toInt()
            val y = (height / 2 + sin(angle) * (height / 3)).toInt()

            // Brush style varies by band index
            when (band % 3) {
                0 -> {
                    g.paint = GradientPaint(x.toFloat(), y.toFloat(), col, (x + size).toFloat(), (y + size).toFloat(), Color.WHITE, true)
                    g.fillOval(x - size / 2, y - size / 2, size, size)
                }
                1 -> {
                    g.stroke = BasicStroke((size / 30).coerceAtLeast(1f), BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)
                    g.color = col
                    g.draw(newLine(x, y, size, angle))
                }
                else -> {
                    g.stroke = BasicStroke((size / 10).coerceAtLeast(2f))
                    g.color = col
                    g.drawArc(x - size / 2, y - size / 2, size, size, (angle * 180 / Math.PI).toInt(), 120)
                }
            }
        }
        g.dispose()
        phase += 0.05

        // ----- 6. Add frame to GIF --------------------------------------------
        gifWriter.writeToSequence(canvas)
    }

    // ----- 7. Finalise ---------------------------------------------------------
    gifWriter.close()
    output.close()
    println("Animation saved to output.gif")
}

/** Reads all remaining bytes from an AudioInputStream */
private fun AudioInputStream.readBytes(): ByteArray {
    val bos = ByteArrayOutputStream()
    val buf = ByteArray(4096)
    var n: Int
    while (read(buf).also { n = it } != -1) bos.write(buf, 0, n)
    return bos.toByteArray()
}

/** Converts byte array to signed 16‑bit samples */
private fun ByteArray.readShorts(bigEndian: Boolean): ShortArray {
    val shorts = ShortArray(size / 2)
    for (i in shorts.indices) {
        val idx = i * 2
        shorts[i] = if (bigEndian)
            ((this[idx].toInt() shl 8) or (this[idx + 1].toInt() and 0xFF)).toShort()
        else
            ((this[idx + 1].toInt() shl 8) or (this[idx].toInt() and 0xFF)).toShort()
    }
    return shorts
}

/** Naïve recursive FFT returning real & imag parts */
private fun fft(input: DoubleArray): Pair<DoubleArray, DoubleArray> {
    val n = input.size
    require(n and (n - 1) == 0) { "FFT size must be power of two" }
    val real = input.clone()
    val imag = DoubleArray(n)

    var i = 0
    var j = 0
    while (i < n) {
        if (j > i) {
            real[i] = input[j].also { real[j] = input[i] }
            imag[i] = 0.0.also { imag[j] = 0.0 }
        }
        var m = n shr 1
        while (m >= 1 && j >= m) {
            j -= m
            m = m shr 1
        }
        j += m
        i++
    }

    var len = 2
    while (len <= n) {
        val angle = -2.0 * Math.PI / len
        val wlenCos = cos(angle)
        val wlenSin = sin(angle)
        var i = 0
        while (i < n) {
            var wReal = 1.0
            var wImag = 0.0
            for (k in 0 until len / 2) {
                val uReal = real[i + k]
                val uImag = imag[i + k]
                val vReal = real[i + k + len / 2] * wReal - imag[i + k + len / 2] * wImag
                val vImag = real[i + k + len / 2] * wImag + imag[i + k + len / 2] * wReal
                real[i + k] = uReal + vReal
                imag[i + k] = uImag + vImag
                real[i + k + len / 2] = uReal - vReal
                imag[i + k + len / 2] = uImag - vImag
                val nextWReal = wReal * wlenCos - wImag * wlenSin
                wImag = wReal * wlenSin + wImag * wlenCos
                wReal = nextWReal
            }
            i += len
        }
        len = len shl 1
    }
    return Pair(real, imag)
}

/** Helper to create a line shape */
private fun newLine(x: Int, y: Int, length: Int, angle: Double): Shape {
    val x2 = x + (cos(angle) * length).toInt()
    val y2 = y + (sin(angle) * length).toInt()
    return Line2D.Float(x.toFloat(), y.toFloat(), x2.toFloat(), y2.toFloat())
}

/** Minimal GIF writer based on ImageIO */
class GifSequenceWriter(out: ImageOutputStream, type: Int, delay: Int, loop: Boolean) {
    private val writer = ImageIO.getImageWritersBySuffix("gif").next()
    private val params = writer.defaultWriteParam
    private val metadata = writer.getDefaultImageMetadata(ImageTypeSpecifier.createFromBufferedImageType(type), params)

    init {
        val metaFormat = metadata.nativeMetadataFormatName
        val root = metadata.getAsTree(metaFormat) as org.w3c.dom.Node
        val graphicsControlExtension = root.appendChildElement("GraphicControlExtension") {
            setAttribute("disposalMethod", "none")
            setAttribute("userInputFlag", "FALSE")
            setAttribute("transparentColorFlag", "FALSE")
            setAttribute("delayTime", (delay / 10).toString())
            setAttribute("transparentColorIndex", "0")
        }
        val appExtensions = root.appendChildElement("ApplicationExtensions")
        val appExtension = appExtensions.appendChildElement("ApplicationExtension") {
            setAttribute("applicationID", "NETSCAPE")
            setAttribute("authenticationCode", "2.0")
            userObject = byteArrayOf(0x1, 0x0, 0x0) // loop forever
        }
        if (loop) {
            (appExtension.userObject as ByteArray)[1] = 0x0
            (appExtension.userObject as ByteArray)[2] = 0x0
        }
        writer.setOutput(out)
        writer.prepareWriteSequence(null)
    }

    fun writeToSequence(img: BufferedImage) {
        writer.writeToSequence(IIOImage(img, null, metadata), params)
    }

    fun close() {
        writer.endWriteSequence()
    }

    /** utility to append child with attribute lambda */
    private fun org.w3c.dom.Node.appendChildElement(name: String, init: org.w3c.dom.Element.() -> Unit): org.w3c.dom.Element {
        val elem = ownerDocument.createElement(name) as org.w3c.dom.Element
        elem.init()
        appendChild(elem)
        return elem
    }
}