import java.awt.Color
import java.awt.Dimension
import java.awt.image.BufferedImage
import java.io.ByteArrayOutputStream
import java.util.*
import javax.imageio.ImageIO
import javax.sound.midi.*
import javax.swing.JFrame
import javax.swing.JPanel
import kotlin.math.ln
import kotlin.math.pow
import kotlin.math.sqrt
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.videoio.VideoCapture
import org.opencv.imgcodecs.Imgcodecs
import org.opencv.imgproc.Imgproc

// ---------- OpenCV native loading ----------
init {
    nu.pattern.OpenCV.loadShared()
    System.loadLibrary(org.opencv.core.Core.NATIVE_LIBRARY_NAME)
}

// ---------- Simple k‑means for palette extraction ----------
fun dominantPalette(img: BufferedImage, k: Int = 5): List<Color> {
    val rnd = Random()
    val points = mutableListOf<DoubleArray>()
    for (y in 0 until img.height step 4) {
        for (x in 0 until img.width step 4) {
            val rgb = Color(img.getRGB(x, y))
            points += doubleArrayOf(rgb.red.toDouble(), rgb.green.toDouble(), rgb.blue.toDouble())
        }
    }
    // initialise centroids
    val centroids = mutableListOf<DoubleArray>()
    repeat(k) { centroids += points[rnd.nextInt(points.size)].clone() }

    repeat(10) {
        val groups = Array(k) { mutableListOf<DoubleArray>() }
        for (p in points) {
            val nearest = centroids.indices.minByOrNull { i ->
                val c = centroids[i]
                (p[0] - c[0]).pow(2) + (p[1] - c[1]).pow(2) + (p[2] - c[2]).pow(2)
            }!!
            groups[nearest] += p
        }
        for (i in 0 until k) {
            if (groups[i].isNotEmpty()) {
                val avg = DoubleArray(3)
                for (p in groups[i]) {
                    avg[0] += p[0]; avg[1] += p[1]; avg[2] += p[2]
                }
                avg[0] /= groups[i].size; avg[1] /= groups[i].size; avg[2] /= groups[i].size
                centroids[i] = avg
            }
        }
    }
    return centroids.map { Color(it[0].toInt(), it[1].toInt(), it[2].toInt()) }
}

// ---------- Entropy of palette change ----------
fun paletteEntropy(prev: List<Color>, cur: List<Color>): Double {
    if (prev.isEmpty()) return 0.0
    var sum = 0.0
    for (i in prev.indices) {
        val a = prev[i]; val b = cur[i]
        val d = sqrt((a.red - b.red).toDouble().pow(2) +
                     (a.green - b.green).toDouble().pow(2) +
                     (a.blue - b.blue).toDouble().pow(2))
        sum += d
    }
    // normalise and convert to Shannon entropy like measure
    val p = sum / (prev.size * 255.0 * sqrt(3.0))
    return -p * ln(p.coerceAtLeast(1e-9))
}

// ---------- L‑system grammar ----------
class LSystem(var axiom: String, private val rules: Map<Char, String>) {
    fun iterate(n: Int) = repeat(n) { axiom = axiom.map { rules[it] ?: it.toString() }.joinToString("") }
    fun current() = axiom
}

// ---------- Particle system driven by symbols ----------
data class Particle(var x: Double, var y: Double, var vx: Double, var vy: Double, var col: Color)

fun updateParticles(particles: MutableList<Particle>, symbols: String, width: Int, height: Int) {
    for (s in symbols) {
        when (s) {
            'F' -> particles += Particle(width/2.0, height/2.0,
                                        (Math.random()-0.5)*4, (Math.random()-0.5)*4,
                                        Color((Math.random()*255).toInt(),
                                              (Math.random()*255).toInt(),
                                              (Math.random()*255).toInt()))
        }
    }
    val iter = particles.iterator()
    while (iter.hasNext()) {
        val p = iter.next()
        p.x += p.vx; p.y += p.vy
        p.vx *= 0.99; p.vy *= 0.99
        if (p.x !in 0.0..width.toDouble() || p.y !in 0.0..height.toDouble())
            iter.remove()
    }
}

// ---------- SVG rendering ----------
fun particlesToSVG(particles: List<Particle>, w: Int, h: Int): String {
    val sb = StringBuilder()
    sb.append("""<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h">""")
    for (p in particles) {
        val hex = String.format("#%02x%02x%02x", p.col.red, p.col.green, p.col.blue)
        sb.append("""<circle cx="${p.x}" cy="${p.y}" r="3" fill="$hex"/>""")
    }
    sb.append("</svg>")
    return sb.toString()
}

// ---------- Simple MIDI tempo controller ----------
class MidiTempo(val synth: Synthesizer) {
    private var lastTick = System.currentTimeMillis()
    fun tick(entropy: Double) {
        val now = System.currentTimeMillis()
        val interval = (500.0 / (entropy + 0.1)).coerceIn(100.0, 1000.0).toLong()
        if (now - lastTick > interval) {
            playNote()
            lastTick = now
        }
    }
    private fun playNote() {
        val channel = synth.channels[0]
        channel.programChange(0)
        channel.noteOn(60, 80)
        Thread.sleep(30)
        channel.noteOff(60)
    }
}

// ---------- Main application ----------
fun main() {
    val cam = VideoCapture(0)
    if (!cam.isOpened) {
        println("Cannot open webcam")
        return
    }

    // window for SVG preview
    val frame = JFrame("AV Poem")
    frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
    val panel = object : JPanel() {
        var svg: String = ""
        override fun getPreferredSize() = Dimension(640, 480)
        override fun paintComponent(g: java.awt.Graphics) {
            super.paintComponent(g)
            if (svg.isNotEmpty()) {
                val img = ImageIO.read(svg.byteInputStream())
                g.drawImage(img, 0, 0, null)
            }
        }
    }
    frame.add(panel)
    frame.pack()
    frame.isVisible = true

    val synth = MidiSystem.getSynthesizer()
    synth.open()
    val tempo = MidiTempo(synth)

    var prevPalette = emptyList<Color>()
    val particles = mutableListOf<Particle>()
    val lsystem = LSystem("F", mapOf('F' to "FF+[+F-F-F]-[-F+F+F]"))

    while (true) {
        val mat = Mat()
        cam.read(mat)
        if (mat.empty()) continue
        Imgproc.cvtColor(mat, mat, Imgproc.COLOR_BGR2RGB)
        val buffer = Mat()
        mat.convertTo(buffer, CvType.CV_8U)
        val bytes = MatOfByte()
        Imgcodecs.imencode(".png", buffer, bytes)
        val img = ImageIO.read(ByteArrayInputStream(bytes.toArray()))

        val palette = dominantPalette(img)
        val entropy = paletteEntropy(prevPalette, palette)
        prevPalette = palette

        // evolve L‑system based on entropy
        if (entropy > 0.2) lsystem.iterate(1)

        // update particles
        updateParticles(particles, lsystem.current(), panel.width, panel.height)

        // render SVG
        panel.svg = particlesToSVG(particles, panel.width, panel.height)

        // audio tempo
        tempo.tick(entropy)

        panel.repaint()
        Thread.sleep(30)
    }
}