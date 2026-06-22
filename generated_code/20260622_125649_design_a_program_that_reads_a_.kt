import javafx.application.Application
import javafx.application.Platform
import javafx.embed.swing.JFXPanel
import javafx.scene.*
import javafx.scene.canvas.Canvas
import javafx.scene.canvas.GraphicsContext
import javafx.scene.input.KeyCode
import javafx.scene.paint.Color
import javafx.scene.paint.PhongMaterial
import javafx.scene.shape.Box
import javafx.scene.shape.CullFace
import javafx.scene.shape.DrawMode
import javafx.scene.transform.Rotate
import javafx.scene.transform.Translate
import javafx.stage.Stage
import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import org.opencv.videoio.VideoCapture
import java.util.*
import javax.sound.midi.*

/**
 * Simple synesthetic app:
 * - grabs webcam frames with OpenCV
 * - extracts 5 dominant colors via k‑means
 * - maps the first color to a musical scale
 * - generates MIDI notes in that scale
 * - builds a rotating 3‑D terrain whose vertices react to the music
 */
class SynestheticFractal : Application() {

    private val capture = VideoCapture()
    private val midiSynth = MidiSystem.getSynthesizer()
    private var channel: MidiChannel? = null
    private val random = Random()
    private lateinit var root3D: Group
    private lateinit var camera: PerspectiveCamera
    private lateinit var fractal: Group
    private var tempoBPM = 60
    private var currentScale = intArrayOf(0, 2, 4, 5, 7, 9, 11) // C major by default

    override fun start(primaryStage: Stage) {
        // Init OpenCV
        System.loadLibrary(Core.NATIVE_LIBRARY_NAME)
        capture.open(0)
        if (!capture.isOpened) {
            println("Cannot open webcam")
            Platform.exit()
            return
        }

        // Init MIDI
        midiSynth.open()
        channel = midiSynth.channels[0]
        channel?.programChange(0) // Acoustic Grand Piano

        // Build 3‑D scene
        root3D = Group()
        fractal = Group()
        root3D.children.add(fractal)
        camera = PerspectiveCamera(true).apply {
            nearClip = 0.1
            farClip = 10000.0
            transforms.addAll(Translate(0.0, 0.0, -800.0))
        }
        val subScene = SubScene(root3D, 800.0, 600.0, true, SceneAntialiasing.BALANCED).apply {
            fill = Color.BLACK
            camera = this@SynestheticFractal.camera
        }

        // UI overlay for debugging
        val canvas = Canvas(800.0, 600.0)
        val gc = canvas.graphicsContext2D

        val scene = Scene(Group(subScene, canvas))
        scene.setOnKeyPressed { if (it.code == KeyCode.ESCAPE) Platform.exit() }

        primaryStage.scene = scene
        primaryStage.title = "Synesthetic Fractal"
        primaryStage.show()

        // Start background loops
        Timer().schedule(object : TimerTask() {
            override fun run() = processFrameAndMusic(gc)
        }, 0, 33) // ~30 FPS

        Timer().schedule(object : TimerTask() {
            override fun run() = generateMusic()
        }, 0, (60000 / tempoBPM).toLong())
    }

    /** Capture frame, extract palette, update scale, draw debug colors */
    private fun processFrameAndMusic(gc: GraphicsContext) {
        val frame = Mat()
        if (!capture.read(frame)) return
        Imgproc.resize(frame, frame, Size(160.0, 120.0))
        val samples = Mat()
        frame.convertTo(samples, CvType.CV_32F)
        samples.reshape(1, (frame.total() * frame.channels()).toInt())
        val labels = Mat()
        val centers = Mat()
        Core.kmeans(samples, 5, labels,
            TermCriteria(TermCriteria.EPS + TermCriteria.MAX_ITER, 10, 1.0),
            3, Core.KMEANS_PP_CENTERS, centers)

        val palette = ArrayList<Color>()
        for (i in 0 until centers.rows()) {
            val b = centers.get(i, 0)[0] / 255.0
            val g = centers.get(i, 1)[0] / 255.0
            val r = centers.get(i, 2)[0] / 255.0
            palette.add(Color.color(r, g, b))
        }

        // map first dominant color hue to a scale
        val hue = palette[0].hue
        currentScale = hueToScale(hue)

        // draw palette bar
        Platform.runLater {
            gc.clearRect(0.0, 0.0, 800.0, 100.0)
            val w = 800.0 / palette.size
            palette.forEachIndexed { idx, col ->
                gc.fill = col
                gc.fillRect(idx * w, 0.0, w, 100.0)
            }
        }

        // update fractal geometry
        updateFractal()
    }

    /** Simple hue→scale mapper (7‑note major/minor) */
    private fun hueToScale(hue: Double): IntArray {
        return if ((hue / 60).toInt() % 2 == 0) {
            intArrayOf(0, 2, 4, 5, 7, 9, 11) // major
        } else {
            intArrayOf(0, 2, 3, 5, 7, 8, 10) // minor
        }
    }

    /** Generate a note from the current scale each beat */
    private fun generateMusic() {
        val root = 60 // middle C
        val degree = random.nextInt(currentScale.size)
        val pitch = root + currentScale[degree] + 12 * (random.nextInt(2))
        channel?.noteOn(pitch, 100)
        Timer().schedule(object : TimerTask() {
            override fun run() = channel?.noteOff(pitch)
        }, 150) // short note
    }

    /** Build a simple height‑field fractal that reacts to music tempo */
    private fun updateFractal() {
        Platform.runLater {
            fractal.children.clear()
            val size = 200
            val step = 20
            for (x in -size..size step step) {
                for (z in -size..size step step) {
                    val height = (Math.sin((x + System.currentTimeMillis() / 100.0) * 0.05) *
                            Math.cos((z + System.currentTimeMillis() / 100.0) * 0.05) *
                            50 * (tempoBPM / 60.0)).toFloat()
                    val box = Box(step.toDouble(), height.toDouble(), step.toDouble())
                    box.translateX = x.toDouble()
                    box.translateY = -height / 2
                    box.translateZ = z.toDouble()
                    box.drawMode = DrawMode.FILL
                    box.cullFace = CullFace.BACK
                    val mat = PhongMaterial()
                    mat.diffuseColor = Color.hsb(((x + z + System.currentTimeMillis() / 10) % 360).toDouble(), 0.8, 0.9)
                    box.material = mat
                    fractal.children.add(box)
                }
            }
            // rotate whole terrain slowly
            fractal.rotate = Rotate(0.0, Rotate.Y_AXIS)
            fractal.transforms.add(Rotate((System.currentTimeMillis() / 50) % 360, Rotate.Y_AXIS))
        }
    }

    override fun stop() {
        capture.release()
        midiSynth.close()
        Platform.exit()
    }
}

fun main() {
    // Needed to initialise JavaFX Toolkit in a pure Kotlin script
    JFXPanel()
    Application.launch(SynestheticFractal::class.java)
}