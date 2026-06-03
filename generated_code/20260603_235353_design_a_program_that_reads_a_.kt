import javafx.application.Application
import javafx.application.Platform
import javafx.embed.swing.SwingFXUtils
import javafx.scene.Scene
import javafx.scene.canvas.Canvas
import javafx.scene.canvas.GraphicsContext
import javafx.scene.image.WritableImage
import javafx.scene.layout.StackPane
import javafx.scene.media.AudioClip
import javafx.stage.Stage
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.imgcodecs.Imgcodecs
import org.opencv.videoio.VideoCapture
import java.awt.Color
import java.awt.image.BufferedImage
import java.util.*
import javax.sound.midi.*

/**
 * Minimal demo:
 * - grabs webcam frames via OpenCV
 * - converts each pixel to a MIDI note (pitch = average of RGB)
 * - plays a short note using the built‑in synthesizer
 * - draws a Voronoi diagram whose cell colors are derived from the note velocity
 * - updates continuously in the JavaFX UI thread
 */
class AudioVisualVoronoi : Application() {

    private val width = 640
    private val height = 480
    private lateinit var canvas: Canvas
    private lateinit var gc: GraphicsContext
    private lateinit var capture: VideoCapture
    private lateinit var synth: Synthesizer
    private lateinit var midiChannel: MidiChannel
    private val rand = Random()

    // Simple point class for Voronoi seeds
    data class Seed(val x: Int, val y: Int, var color: Color)

    private val seeds = mutableListOf<Seed>()

    override fun start(primaryStage: Stage) {
        System.loadLibrary(org.opencv.core.Core.NATIVE_LIBRARY_NAME)

        // --- init video ---
        capture = VideoCapture(0)
        if (!capture.isOpened) {
            println("Cannot open webcam")
            Platform.exit()
            return
        }

        // --- init MIDI ---
        synth = MidiSystem.getSynthesizer()
        synth.open()
        midiChannel = synth.channels[0]
        midiChannel.programChange(0) // piano

        // --- UI ---
        canvas = Canvas(width.toDouble(), height.toDouble())
        gc = canvas.graphicsContext2D
        val root = StackPane(canvas)
        primaryStage.scene = Scene(root)
        primaryStage.title = "Audio‑Visual Voronoi"
        primaryStage.show()

        // start loop
        Timer().scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                processFrame()
            }
        }, 0, 33) // ~30 FPS
    }

    private fun processFrame() {
        val frame = Mat()
        if (!capture.read(frame)) return

        // Convert Mat to BufferedImage
        val img = matToBufferedImage(frame)

        // pick random pixel, map to MIDI note
        val px = rand.nextInt(width)
        val py = rand.nextInt(height)
        val rgb = Color(img.getRGB(px, py))
        val note = ((rgb.red + rgb.green + rgb.blue) / 3 * 127 / 255).toInt().coerceIn(0, 127)
        val velocity = ((rgb.red + rgb.green + rgb.blue) / 3 * 127 / 255).toInt().coerceIn(30, 127)

        // play note
        midiChannel.noteOn(note, velocity)
        // quick release
        Timer().schedule(object : TimerTask() {
            override fun run() {
                midiChannel.noteOff(note)
            }
        }, 100)

        // add new seed for Voronoi
        seeds.add(Seed(px, py, rgb))

        // keep seed count reasonable
        if (seeds.size > 200) seeds.removeAt(0)

        // draw Voronoi on FX canvas
        Platform.runLater {
            drawVoronoi()
        }
    }

    private fun drawVoronoi() {
        val img = WritableImage(width, height)
        val pixelWriter = img.pixelWriter

        for (y in 0 until height) {
            for (x in 0 until width) {
                var bestDist = Int.MAX_VALUE
                var col = Color.BLACK
                for (seed in seeds) {
                    val dx = x - seed.x
                    val dy = y - seed.y
                    val d = dx * dx + dy * dy
                    if (d < bestDist) {
                        bestDist = d
                        col = seed.color
                    }
                }
                pixelWriter.setColor(x, y, javafx.scene.paint.Color.rgb(col.red, col.green, col.blue))
            }
        }
        gc.drawImage(img, 0.0, 0.0)
    }

    private fun matToBufferedImage(mat: Mat): BufferedImage {
        val bytes = ByteArray(mat.cols() * mat.rows() * mat.channels())
        mat.get(0, 0, bytes)
        val image = BufferedImage(mat.cols(), mat.rows(), BufferedImage.TYPE_3BYTE_BGR)
        val targetPixels = (image.raster.dataBuffer as java.awt.image.DataBufferByte).data
        System.arraycopy(bytes, 0, targetPixels, 0, bytes.size)
        return image
    }

    override fun stop() {
        capture.release()
        synth.close()
    }
}

fun main() {
    Application.launch(AudioVisualVoronoi::class.java)
}