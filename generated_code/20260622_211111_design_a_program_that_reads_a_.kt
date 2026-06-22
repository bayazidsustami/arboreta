import javafx.application.Application
import javafx.application.Platform
import javafx.scene.*
import javafx.scene.canvas.Canvas
import javafx.scene.canvas.GraphicsContext
import javafx.scene.image.WritableImage
import javafx.scene.paint.Color
import javafx.stage.Stage
import org.opencv.core.Core
import org.opencv.videoio.VideoCapture
import be.tarsos.dsp.AudioDispatcher
import be.tarsos.dsp.io.jvm.JVMAudioInputStream
import be.tarsos.dsp.pitch.PitchDetectionHandler
import be.tarsos.dsp.pitch.PitchProcessor
import be.tarsos.dsp.pitch.PitchDetectionResult
import java.awt.image.BufferedImage
import java.io.ByteArrayInputStream
import java.util.concurrent.atomic.AtomicReference
import javax.imageio.ImageIO
import kotlin.math.*

/**
 * Simple real‑time audio‑visual poem.
 * - Webcam feed is displayed on a canvas (background)
 * - Audio stream is analysed for pitch, volume & onset rate
 * - These parameters drive an L‑system that draws a fractal tree
 *   * pitch → angle of branching
 *   * volume → branch thickness
 *   * onset rate → curvature factor
 *   * pitch class → branch colour (timbre hint)
 */
class AudioVisualPoem : Application() {

    private val cam = VideoCapture()
    private val canvas = Canvas(800.0, 600.0)
    private val gc: GraphicsContext = canvas.graphicsContext2D
    private val pitchRef = AtomicReference(440.0)          // Hz
    private val volumeRef = AtomicReference(0.0)          // RMS
    private val onsetRateRef = AtomicReference(0.0)       // onsets per sec

    // L‑system state
    private var angle = Math.toRadians(30.0)
    private var thickness = 8.0
    private var curvature = 0.0

    override fun start(primaryStage: Stage) {
        System.loadLibrary(Core.NATIVE_LIBRARY_NAME)

        // UI
        val root = Group(canvas)
        primaryStage.scene = Scene(root)
        primaryStage.title = "Audio‑Visual Poem"
        primaryStage.show()

        // start webcam thread
        Thread { runWebcam() }.apply { isDaemon = true; start() }

        // start audio analysis thread
        Thread { runAudio() }.apply { isDaemon = true; start() }

        // render loop (60 fps)
        val timer = javafx.animation.AnimationTimer {
            render()
        }
        timer.start()
    }

    private fun runWebcam() {
        cam.open(0)
        if (!cam.isOpened) return
        val mat = org.opencv.core.Mat()
        while (true) {
            cam.read(mat)
            if (!mat.empty()) {
                val img = matToImage(mat)
                Platform.runLater {
                    gc.drawImage(img, 0.0, 0.0, canvas.width, canvas.height)
                }
            }
            Thread.sleep(33) // ~30 fps
        }
    }

    private fun matToImage(mat: org.opencv.core.Mat): WritableImage {
        val buffer = org.opencv.imgcodecs.Imgcodecs.imencode(".png", mat).toArray()
        val bais = ByteArrayInputStream(buffer)
        val buffered: BufferedImage = ImageIO.read(bais)
        return javafx.embed.swing.SwingFXUtils.toFXImage(buffered, null)
    }

    private fun runAudio() {
        val format = javax.sound.sampled.AudioSystem.getAudioFileFormat(
            javax.sound.sampled.AudioSystem.getTargetDataLine(javax.sound.sampled.AudioFormat(44100f, 16, 1, true, false)).lineInfo
        ).type // placeholder to force loading; real code would query TargetDataLine

        val line = javax.sound.sampled.AudioSystem.getTargetDataLine(
            javax.sound.sampled.AudioFormat(44100f, 16, 1, true, false)
        )
        line.open()
        line.start()
        val dispatcher = AudioDispatcher(JVMAudioInputStream(line), 1024, 0)

        // pitch detection
        dispatcher.addAudioProcessor(PitchProcessor(
            PitchProcessor.PitchEstimationAlgorithm.YIN,
            44100f,
            1024,
            PitchDetectionHandler { res: PitchDetectionResult, _: AudioEvent ->
                if (res.pitch != -1f) pitchRef.set(res.pitch.toDouble())
                volumeRef.set(res.getProbability()) // using probability as proxy for loudness
            }
        ))

        // simple onset detection (energy rise)
        dispatcher.addAudioProcessor { audioEvent ->
            val rms = audioEvent.getRMS()
            // naive rate estimator
            val now = System.nanoTime()
            if (rms > 0.02 && now - lastOnset > 300_000_000) { // 300 ms min interval
                onsetCount++
                lastOnset = now
            }
            // update rate every second
            if (now - lastRateCalc > 1_000_000_000) {
                onsetRateRef.set(onsetCount.toDouble())
                onsetCount = 0
                lastRateCalc = now
            }
            true
        }

        dispatcher.run()
    }

    private var lastOnset = 0L
    private var lastRateCalc = 0L
    private var onsetCount = 0

    // render background + fractal tree
    private fun render() {
        // update L‑system parameters from audio
        angle = Math.toRadians(20 + (pitchRef.get() % 400) / 400 * 40) // 20‑60°
        thickness = 4 + volumeRef.get() * 20
        curvature = onsetRateRef.get() * 0.05 // subtle curvature with activity

        // draw tree over webcam image
        gc.save()
        gc.translate(canvas.width / 2, canvas.height) // base centre
        gc.stroke = Color.hsb((pitchRef.get() % 12) * 30.0, 0.8, 0.9) // colour by pitch class
        gc.lineWidth = thickness
        drawBranch(100.0, 0.0, 10)
        gc.restore()
    }

    // recursive L‑system like drawing
    private fun drawBranch(len: Double, dir: Double, depth: Int) {
        if (depth == 0) return
        val x2 = len * cos(dir)
        val y2 = -len * sin(dir)
        gc.beginPath()
        gc.moveTo(0.0, 0.0)
        // curvature via a simple quadratic bezier
        val ctrlX = x2 / 2 + curvature * len * cos(dir + Math.PI / 2)
        val ctrlY = y2 / 2 + curvature * len * sin(dir + Math.PI / 2)
        gc.quadraticCurveTo(ctrlX, ctrlY, x2, y2)
        gc.stroke()
        gc.translate(x2, y2)

        // left branch
        gc.save()
        gc.rotate(Math.toDegrees(angle))
        drawBranch(len * 0.7, 0.0, depth - 1)
        gc.restore()

        // right branch
        gc.save()
        gc.rotate(Math.toDegrees(-angle))
        drawBranch(len * 0.7, 0.0, depth - 1)
        gc.restore()

        gc.translate(-x2, -y2)
    }
}

fun main() {
    Application.launch(AudioVisualPoem::class.java)
}