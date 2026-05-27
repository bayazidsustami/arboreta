@file:DependsOn("org.openpnp:opencv:4.5.1-2")
@file:DependsOn("org.openjfx:javafx-controls:17")
@file:DependsOn("org.openjfx:javafx-base:17")
@file:DependsOn("org.openjfx:javafx-graphics:17")
@file:DependsOn("org.openjfx:javafx-media:17")
@file:DependsOn("org.openjfx:javafx-fxml:17")
@file:DependsOn("org.jetbrains.kotlinx:kotlinx-coroutines-javafx:1.6.4")

import javafx.application.Application
import javafx.application.Platform
import javafx.embed.swing.SwingFXUtils
import javafx.scene.Scene
import javafx.scene.canvas.Canvas
import javafx.scene.canvas.GraphicsContext
import javafx.scene.image.Image
import javafx.scene.layout.StackPane
import javafx.scene.paint.Color
import javafx.stage.Stage
import kotlinx.coroutines.*
import org.opencv.core.Core
import org.opencv.core.Mat
import org.opencv.core.Scalar
import org.opencv.core.Size
import org.opencv.imgproc.Imgproc
import org.opencv.videoio.VideoCapture
import javax.sound.midi.*

/**
 * Simple audiovisual poem:
 * - Captures webcam frames.
 * - Extracts dominant colors via k‑means (very coarse, 3 clusters).
 * - Maps each cluster to a MIDI note on a custom pentatonic scale.
 * - Plays notes whose velocity depends on facial expression intensity (mouth openness).
 * - Draws a realtime fractal whose colour and zoom react to the same intensity.
 */
class PoemApp : Application() {
    private val capture = VideoCapture(0.0)
    private val canvas = Canvas(800.0, 600.0)
    private val gc: GraphicsContext = canvas.graphicsContext2D
    private var midiReceiver: Receiver? = null
    private var synth: Synthesizer? = null
    private var zoom = 1.0
    private var angle = 0.0

    // custom scale: C D E G A (MIDI notes 60,62,64,67,69)
    private val scale = intArrayOf(60, 62, 64, 67, 69)

    override fun start(primaryStage: Stage) {
        System.loadLibrary(Core.NATIVE_LIBRARY_NAME)
        initMIDI()
        val root = StackPane(canvas)
        primaryStage.scene = Scene(root)
        primaryStage.title = "Audiovisual Poem"
        primaryStage.show()
        startProcessing()
    }

    private fun initMIDI() {
        synth = MidiSystem.getSynthesizer()
        synth?.open()
        midiReceiver = synth?.receiver
    }

    private fun playNote(note: Int, velocity: Int) {
        val msgOn = ShortMessage()
        msgOn.setMessage(ShortMessage.NOTE_ON, 0, note, velocity)
        midiReceiver?.send(msgOn, -1)
        // Note off after 200ms
        GlobalScope.launch {
            delay(200)
            val msgOff = ShortMessage()
            msgOff.setMessage(ShortMessage.NOTE_OFF, 0, note, 0)
            midiReceiver?.send(msgOff, -1)
        }
    }

    private fun startProcessing() {
        GlobalScope.launch(Dispatchers.IO) {
            val frame = Mat()
            while (capture.isOpened) {
                if (!capture.read(frame) || frame.empty()) continue
                // Resize for faster processing
                Imgproc.resize(frame, frame, Size(320.0, 240.0))
                val dominantColors = extractDominantColors(frame, 3)
                val intensity = detectMouthOpen(frame) // 0..1
                // map colors to notes
                dominantColors.forEachIndexed { idx, color ->
                    val note = scale[idx % scale.size]
                    val velocity = (intensity * 127).toInt().coerceIn(0, 127)
                    playNote(note, velocity)
                }
                // update graphics on UI thread
                Platform.runLater {
                    drawFractal(intensity)
                }
                delay(33) // ~30fps
            }
        }
    }

    private fun extractDominantColors(mat: Mat, k: Int): List<Scalar> {
        // Very simple: average every k‑th pixel row/col as a mock‑cluster
        val colors = mutableListOf<Scalar>()
        val stepY = mat.rows() / k
        val stepX = mat.cols() / k
        for (i in 0 until k) {
            val sub = mat.submat(i * stepY, (i + 1) * stepY, i * stepX, (i + 1) * stepX)
            val avg = Core.mean(sub)
            colors.add(avg)
        }
        return colors
    }

    private fun detectMouthOpen(mat: Mat): Double {
        // Placeholder: use average brightness as proxy for expression intensity
        val gray = Mat()
        Imgproc.cvtColor(mat, gray, Imgproc.COLOR_BGR2GRAY)
        val mean = Core.mean(gray).`val`[0] / 255.0
        return mean.coerceIn(0.0, 1.0)
    }

    private fun drawFractal(intensity: Double) {
        // Simple zoom‑based Mandelbrot preview
        val w = canvas.width.toInt()
        val h = canvas.height.toInt()
        val img = javafx.scene.image.WritableImage(w, h)
        val pw = img.pixelWriter
        zoom = 1.5 - intensity * 0.5 // zoom reacts to intensity
        angle += intensity * 0.05
        for (y in 0 until h) {
            for (x in 0 until w) {
                var zx = (x - w / 2.0) * (4.0 / w) / zoom
                var zy = (y - h / 2.0) * (4.0 / h) / zoom
                // rotate
                val cx = zx * Math.cos(angle) - zy * Math.sin(angle)
                val cy = zx * Math.sin(angle) + zy * Math.cos(angle)
                zx = cx; zy = cy
                var i = 0
                var zx2 = zx * zx
                var zy2 = zy * zy
                while (zx2 + zy2 < 4.0 && i < 255) {
                    val tmp = zx2 - zy2 + 0.355
                    zy = 2.0 * zx * zy + 0.355
                    zx = tmp
                    zx2 = zx * zx
                    zy2 = zy * zy
                    i++
                }
                val brightness = i / 255.0
                val color = Color.hsb(brightness * 360, 0.7, brightness)
                pw.setColor(x, y, color)
            }
        }
        gc.drawImage(img, 0.0, 0.0)
    }

    override fun stop() {
        capture.release()
        synth?.close()
    }
}

fun main() {
    Application.launch(PoemApp::class.java)
}