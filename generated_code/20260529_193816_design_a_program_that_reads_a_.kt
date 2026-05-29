import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.Size
import org.opencv.core.TermCriteria
import org.opencv.imgproc.Imgproc
import org.opencv.videoio.VideoCapture
import java.awt.Color
import java.awt.image.BufferedImage
import java.io.ByteArrayInputStream
import java.util.*
import javax.imageio.ImageIO
import javax.sound.sampled.AudioFormat
import javax.sound.sampled.AudioSystem
import javax.sound.sampled.SourceDataLine
import javafx.animation.AnimationTimer
import javafx.application.Application
import javafx.embed.swing.SwingFXUtils
import javafx.scene.Group
import javafx.scene.Scene
import javafx.scene.canvas.Canvas
import javafx.scene.canvas.GraphicsContext
import javafx.scene.paint.Paint
import javafx.stage.Stage
import kotlin.math.PI
import kotlin.math.sin

// Simple sentiment detector (keyword based)
fun sentimentFromText(text: String): Double {
    val positive = setOf("good","great","happy","love","awesome")
    val negative = setOf("bad","sad","hate","angry","terrible")
    var score = 0.0
    text.lowercase().split("\\s+".toRegex()).forEach {
        when {
            it in positive -> score += 1.0
            it in negative -> score -= 1.0
        }
    }
    return score.coerceIn(-1.0,1.0) // -1 .. 1
}

// Map a BGR color to a note (C, C#, … B) using hue angle
fun colorToMidiNote(bgr: DoubleArray): Int {
    val b = bgr[0]; val g = bgr[1]; val r = bgr[2]
    val max = maxOf(r,g,b); val min = minOf(r,g,b)
    val hue = when {
        max == min -> 0.0
        max == r -> ((g-b)/ (max-min) * 60) % 360
        max == g -> ((b-r)/ (max-min) * 60) + 120
        else -> ((r-g)/ (max-min) * 60) + 240
    }.let { if (it < 0) it + 360 else it }
    // 0..360 -> 12 notes
    val note = ((hue / 30).toInt()) % 12
    // middle C (MIDI 60) offset
    return 60 + note
}

// Simple sine wave generator for a given MIDI note
class SineSynth(val note: Int, val volume: Double = 0.2) : Thread() {
    private val sampleRate = 44100
    private val freq = 440.0 * Math.pow(2.0, (note - 69) / 12.0)
    private val line: SourceDataLine

    init {
        val format = AudioFormat(sampleRate.toFloat(), 16, 1, true, false)
        line = AudioSystem.getSourceDataLine(format)
        line.open(format)
        line.start()
    }

    override fun run() {
        val buf = ByteArray(1024)
        var angle = 0.0
        val inc = 2 * Math.PI * freq / sampleRate
        while (!isInterrupted) {
            for (i in buf.indices step 2) {
                val sample = (Math.sin(angle) * Short.MAX_VALUE * volume).toInt()
                buf[i] = (sample and 0xff).toByte()
                buf[i + 1] = ((sample shr 8) and 0xff).toByte()
                angle += inc
                if (angle > 2 * Math.PI) angle -= 2 * Math.PI
            }
            line.write(buf, 0, buf.size)
        }
        line.drain()
        line.close()
    }
}

// Convert OpenCV Mat to BufferedImage
fun matToBufferedImage(mat: Mat): BufferedImage {
    val buf = Mat()
    Imgproc.cvtColor(mat, buf, Imgproc.COLOR_BGR2RGB)
    val bytes = ByteArray((buf.total() * buf.channels()).toInt())
    buf.get(0, 0, bytes)
    val width = buf.width()
    val height = buf.height()
    val img = BufferedImage(width, height, BufferedImage.TYPE_3BYTE_BGR)
    val raster = img.raster
    raster.setDataElements(0, 0, width, height, bytes)
    return img
}

// Main JavaFX application
class MandalaApp : Application() {
    private lateinit var gc: GraphicsContext
    private val capture = VideoCapture(0.0)
    private var currentNote = 60
    private var synth = SineSynth(currentNote)
    private var sentiment = 0.0

    override fun start(stage: Stage) {
        System.loadLibrary(Core.NATIVE_LIBRARY_NAME)

        val canvas = Canvas(800.0, 600.0)
        gc = canvas.graphicsContext2D
        val root = Group(canvas)
        stage.scene = Scene(root)
        stage.title = "Audio‑Driven Mandala"
        stage.show()

        // start audio thread
        synth.start()

        // animation loop
        object : AnimationTimer() {
            override fun handle(now: Long) {
                val frame = Mat()
                if (capture.read(frame)) {
                    // downscale for speed
                    Imgproc.resize(frame, frame, Size(160.0, 120.0))
                    // k‑means for dominant color
                    val samples = frame.reshape(1, (frame.total()).toInt())
                    samples.convertTo(samples, CvType.CV_32F)
                    val criteria = TermCriteria(TermCriteria.EPS + TermCriteria.MAX_ITER, 10, 1.0)
                    val labels = Mat()
                    val centers = Mat()
                    Core.kmeans(samples, 1, labels, criteria, 1, Core.KMEANS_PP_CENTERS, centers)
                    val dominant = DoubleArray(3)
                    centers.get(0, 0, dominant)

                    // map to note
                    val newNote = colorToMidiNote(dominant)
                    if (newNote != currentNote) {
                        currentNote = newNote
                        synth.interrupt()
                        synth = SineSynth(currentNote)
                        synth.start()
                    }

                    // mock speech sentiment (placeholder)
                    // In real app, capture microphone and run speech‑to‑text + sentiment analysis
                    sentiment = Math.sin(now / 1e9) // oscillates between -1 and 1

                    drawMandala()
                }
            }
        }.start()
    }

    private fun drawMandala() {
        val w = gc.canvas.width
        val h = gc.canvas.height
        gc.clearRect(0.0, 0.0, w, h)
        val petals = 12
        val radius = 200 + 100 * sentiment
        gc.translate(w / 2, h / 2)
        for (i in 0 until petals) {
            val angle = i * 2 * Math.PI / petals + System.currentTimeMillis() % 2000 / 2000.0 * 2 * Math.PI
            val x = Math.cos(angle) * radius
            val y = Math.sin(angle) * radius
            val opacity = 0.5 + 0.5 * Math.abs(Math.sin(angle * 3 + sentiment))
            gc.globalAlpha = opacity
            gc.fill = Paint.valueOf(Color.HSBtoRGB(((currentNote - 60) / 12.0 + i / petals.toDouble()) % 1.0f, 0.8f, 0.9f).let {
                String.format("#%06X", it and 0xFFFFFF)
            })
            gc.fillOval(x - 30, y - 30, 60.0, 60.0)
        }
        gc.globalAlpha = 1.0
        gc.translate(-w / 2, -h / 2)
    }

    override fun stop() {
        capture.release()
        synth.interrupt()
    }
}

fun main() {
    Application.launch(MandalaApp::class.java)
}