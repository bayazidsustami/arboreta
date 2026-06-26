import javafx.animation.AnimationTimer
import javafx.application.Application
import javafx.embed.swing.SwingFXUtils
import javafx.scene.*
import javafx.scene.canvas.Canvas
import javafx.scene.canvas.GraphicsContext
import javafx.scene.image.WritableImage
import javafx.scene.paint.Color
import javafx.stage.Stage
import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import org.opencv.videoio.VideoCapture
import java.awt.image.BufferedImage
import java.util.*
import javax.sound.midi.*

class AudioVisualSynth : Application() {

    // ---------- OpenCV ----------
    private lateinit var capture: VideoCapture
    private val frameMat = Mat()

    // ---------- MIDI ----------
    private val synth = MidiSystem.getSynthesizer()
    private val channel: MidiChannel
    private val tempoBPM = 120
    private var chordStartTime = System.currentTimeMillis()

    // ---------- UI ----------
    private val width = 800.0
    private val height = 800.0
    private lateinit var gc: GraphicsContext

    init {
        synth.open()
        channel = synth.channels[0]
        channel.programChange(0) // Acoustic Grand Piano
    }

    override fun start(primaryStage: Stage) {
        System.loadLibrary(Core.NATIVE_LIBRARY_NAME)

        capture = VideoCapture(0)
        if (!capture.isOpened) {
            println("Cannot open webcam")
            System.exit(1)
        }

        val canvas = Canvas(width, height)
        gc = canvas.graphicsContext2D

        val root = Group(canvas)
        val scene = Scene(root, width, height, Color.BLACK)
        primaryStage.title = "Mandala Symphony"
        primaryStage.scene = scene
        primaryStage.show()

        val timer = object : AnimationTimer() {
            override fun handle(now: Long) {
                if (capture.read(frameMat)) {
                    val dominant = dominantColor(frameMat)
                    val chord = mapColorToChord(dominant)
                    val nowMs = System.currentTimeMillis()
                    if (nowMs - chordStartTime > (60_000 / tempoBPM)) {
                        playChord(chord)
                        chordStartTime = nowMs
                    }
                    drawMandala(dominant, chord)
                }
            }
        }
        timer.start()
    }

    /** Simple dominant color: average of the frame, converted to HSV hue */
    private fun dominantColor(mat: Mat): DoubleArray {
        val blurred = Mat()
        Imgproc.GaussianBlur(mat, blurred, Size(25.0, 25.0), 0.0)
        val mean = Core.mean(blurred)
        val rgb = doubleArrayOf(mean.`val`[2], mean.`val`[1], mean.`val`[0]) // BGR -> RGB
        val hsv = DoubleArray(3)
        Color.RGBtoHSB(
            rgb[0].toInt(),
            rgb[1].toInt(),
            rgb[2].toInt(),
            hsv
        )
        return doubleArrayOf(hsv[0] * 360, hsv[1], hsv[2]) // hue in degrees
    }

    /** Map hue wheel to a diatonic chord set */
    private fun mapColorToChord(hsv: DoubleArray): IntArray {
        // 0-360 divided into 7 zones → C D E F G A B (major)
        val zones = arrayOf(
            intArrayOf(60, 64, 67),   // C major
            intArrayOf(62, 65, 69),   // Dm
            intArrayOf(64, 67, 71),   // Em
            intArrayOf(65, 69, 72),   // F
            intArrayOf(67, 71, 74),   // G
            intArrayOf(69, 72, 76),   // Am
            intArrayOf(71, 74, 77)    // Bdim
        )
        val idx = ((hsv[0] / 360.0) * zones.size).toInt() % zones.size
        return zones[idx]
    }

    /** Play a triad chord */
    private fun playChord(notes: IntArray) {
        notes.forEach { note ->
            channel.noteOn(note, 80)
        }
        // schedule noteOff after a short duration
        Timer().schedule(object : TimerTask() {
            override fun run() {
                notes.forEach { note -> channel.noteOff(note) }
            }
        }, 200L)
    }

    /** Draw mandala petals driven by chord tension & color */
    private fun drawMandala(hsv: DoubleArray, chord: IntArray) {
        gc.clearRect(0.0, 0.0, width, height)

        val centerX = width / 2
        val centerY = height / 2
        val petalCount = chord.size * 2
        val baseRadius = 100.0 + hsv[2] * 200   // brightness controls size
        val rotationSpeed = hsv[0] / 360.0 * 2 * Math.PI // hue drives rotation

        for (i in 0 until petalCount) {
            val angle = i * (2 * Math.PI / petalCount) + rotationSpeed * (System.currentTimeMillis() % 10000) / 10000
            val x = centerX + Math.cos(angle) * baseRadius
            val y = centerY + Math.sin(angle) * baseRadius

            val opacity = 0.3 + (chord[i % chord.size] % 12) / 12.0 * 0.7
            gc.fill = Color.hsb(hsv[0], hsv[1], hsv[2], opacity)

            gc.save()
            gc.translate(x, y)
            gc.rotate(Math.toDegrees(angle))
            drawPetal(gc, baseRadius * 0.6)
            gc.restore()
        }
    }

    /** Simple petal shape */
    private fun drawPetal(g: GraphicsContext, size: Double) {
        g.beginPath()
        g.moveTo(0.0, 0.0)
        g.quadraticCurveTo(size / 2, -size / 2, size, 0.0)
        g.quadraticCurveTo(size / 2, size / 2, 0.0, 0.0)
        g.closePath()
        g.fill()
    }

    override fun stop() {
        capture.release()
        synth.close()
        System.exit(0)
    }
}

fun main() {
    Application.launch(AudioVisualSynth::class.java)
}