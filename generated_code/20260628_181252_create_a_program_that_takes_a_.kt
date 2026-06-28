import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.Size
import org.opencv.imgproc.Imgproc
import org.opencv.videoio.VideoCapture
import java.awt.Color
import java.awt.image.BufferedImage
import java.util.*
import javax.sound.midi.*
import javafx.application.Application
import javafx.application.Platform
import javafx.embed.swing.SwingFXUtils
import javafx.scene.Scene
import javafx.scene.canvas.Canvas
import javafx.scene.canvas.GraphicsContext
import javafx.scene.image.WritableImage
import javafx.scene.paint.Paint
import javafx.stage.Stage
import kotlinx.coroutines.*
import kotlin.math.*

/**
 * Minimal demo: webcam → dominant color → chord → visual kaleido.
 * Uses OpenCV for video, Java MIDI synth for sound, JavaFX for graphics.
 * Requires OpenCV native libraries on classpath.
 */
class SynestheticKaleido : Application() {
    private val capture = VideoCapture()
    private lateinit var synth: Synthesizer
    private lateinit var channel: MidiChannel
    private val scope = CoroutineScope(Dispatchers.Default + Job())
    private val canvas = Canvas(800.0, 600.0)
    private var hueShift = 0.0

    override fun start(primaryStage: Stage) {
        System.loadLibrary(Core.NATIVE_LIBRARY_NAME)
        capture.open(0) // default webcam
        if (!capture.isOpened) {
            println("Cannot open webcam")
            Platform.exit()
            return
        }

        // MIDI setup
        synth = MidiSystem.getSynthesizer()
        synth.open()
        channel = synth.channels[0]
        channel.programChange(0) // acoustic grand piano

        // JavaFX scene
        val gc = canvas.graphicsContext2D
        val root = javafx.scene.Group(canvas)
        primaryStage.scene = Scene(root)
        primaryStage.title = "Synesthetic Kaleidoscope"
        primaryStage.show()

        // Main loop
        scope.launch {
            while (capture.isOpened) {
                val frame = Mat()
                if (!capture.read(frame) || frame.empty()) continue
                Imgproc.resize(frame, frame, Size(320.0, 240.0))
                val dominant = extractDominantColor(frame)
                val chord = mapColorToChord(dominant)
                playChord(chord)
                updateVisuals(gc, dominant, chord)
                delay(33) // ~30 FPS
            }
        }
    }

    // Extracts a simple dominant color by averaging hues
    private fun extractDominantColor(mat: Mat): Color {
        val hsv = Mat()
        Imgproc.cvtColor(mat, hsv, Imgproc.COLOR_BGR2HSV)
        val hue = Mat()
        Core.extractChannel(hsv, hue, 0)
        val histSize = MatOfInt(180)
        val ranges = MatOfFloat(0f, 180f)
        val hist = Mat()
        Imgproc.calcHist(listOf(hue), MatOfInt(0), Mat(), hist, histSize, ranges)
        Core.MinMaxLocResult(mm = Core.minMaxLoc(hist))
        val dominantHue = mm.maxLoc.y.toInt()
        val saturation = 200.0
        val brightness = 200.0
        return Color.getHSBColor(dominantHue / 180f, (saturation / 255).toFloat(), (brightness / 255).toFloat())
    }

    // Maps hue to a triad chord (MIDI note numbers)
    private fun mapColorToChord(c: Color): IntArray {
        val hue = (c.hue).toInt()
        val root = 60 + (hue / 30) * 2 // C4 + steps
        return intArrayOf(root, root + 4, root + 7) // major triad
    }

    private fun playChord(notes: IntArray) {
        notes.forEach { channel.noteOn(it, 80) }
        // schedule note off after short duration
        scope.launch {
            delay(200)
            notes.forEach { channel.noteOff(it) }
        }
    }

    // Draws a rotating kaleido pattern whose speed depends on chord intervals
    private fun updateVisuals(gc: GraphicsContext, color: Color, chord: IntArray) {
        val speed = chord.map { it % 12 }.average() / 12.0
        hueShift = (hueShift + speed) % 360
        Platform.runLater {
            gc.fill = Paint.valueOf(color.toHexString())
            gc.fillRect(0.0, 0.0, canvas.width, canvas.height)
            // simple kaleido: concentric circles with hue shift
            for (i in 0..10) {
                val radius = canvas.width / 2 * (1 - i / 10.0)
                val hue = (hueShift + i * 30) % 360
                gc.fill = Paint.valueOf(Color.hsb(hue, 0.7, 0.9).toHexString())
                gc.fillOval(
                    canvas.width / 2 - radius,
                    canvas.height / 2 - radius,
                    radius * 2,
                    radius * 2
                )
            }
        }
    }

    override fun stop() {
        capture.release()
        synth.close()
        scope.cancel()
    }

    // Utility to convert java.awt.Color to hex string
    private fun Color.toHexString(): String {
        return String.format("#%02X%02X%02X", red, green, blue)
    }
}

fun main() {
    Application.launch(SynestheticKaleido::class.java)
}