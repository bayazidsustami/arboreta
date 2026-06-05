import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.Scalar
import org.opencv.core.Size
import org.opencv.videoio.VideoCapture
import org.opencv.imgproc.Imgproc
import be.tarsos.dsp.AudioDispatcher
import be.tarsos.dsp.io.jvm.AudioPlayer
import be.tarsos.dsp.io.jvm.JVMAudioInputStream
import be.tarsos.dsp.pitch.PitchProcessor
import be.tarsos.dsp.synthesis.SineWaveSynthesizer
import be.tarsos.dsp.synthesis.Synthesizer
import be.tarsos.dsp.util.fft.FFT
import java.awt.Color
import java.awt.image.BufferedImage
import java.io.ByteArrayInputStream
import java.util.concurrent.ArrayBlockingQueue
import javax.imageio.ImageIO
import javax.sound.sampled.AudioFormat
import javax.sound.sampled.TargetDataLine
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

// Simple demo: capture webcam, extract dominant color, map to pitch, generate tone, draw fractal based on audio amplitude.
fun main() {
    System.loadLibrary(Core.NATIVE_LIBRARY_NAME)

    // ---- Video capture ----
    val cam = VideoCapture(0)
    if (!cam.isOpened) {
        println("Cannot open webcam")
        return
    }
    val frame = Mat()
    // ---- Audio capture ----
    val format = AudioFormat(44100f, 16, 1, true, false)
    val line = javax.sound.sampled.AudioSystem.getTargetDataLine(format)
    line.open(format)
    line.start()
    val audioStream = JVMAudioInputStream(line)
    val dispatcher = AudioDispatcher(audioStream, 1024, 0)

    // Simple synthesizer to play generated notes
    val synth: Synthesizer = SineWaveSynthesizer(44100.0)
    val player = AudioPlayer(format, synth)

    // Queue to pass current amplitude to rendering thread
    val ampQueue = ArrayBlockingQueue<Float>(1)

    // ---- Pitch detection (maps dominant color hue -> pitch) ----
    dispatcher.addAudioProcessor(PitchProcessor(PitchProcessor.PitchEstimationAlgorithm.YIN, 44100f, 1024) { pitch, _ ->
        // pitch in Hz, ignore here – we will generate notes from colors instead
    })
    dispatcher.addAudioProcessor { audioEvent ->
        // compute RMS amplitude
        var sum = 0.0
        val buffer = audioEvent.floatBuffer
        for (sample in buffer) sum += (sample * sample).toDouble()
        val rms = Math.sqrt(sum / buffer.size).toFloat()
        ampQueue.offer(rms)
        true
    }
    dispatcher.addAudioProcessor(player)
    Thread(dispatcher, "AudioThread").start()

    // ---- Main loop ----
    while (true) {
        if (!cam.read(frame) || frame.empty()) break
        // Resize for speed
        Imgproc.resize(frame, frame, Size(320.0, 240.0))
        // Convert to HSV and compute average hue as "dominant"
        val hsv = Mat()
        Imgproc.cvtColor(frame, hsv, Imgproc.COLOR_BGR2HSV)
        val hue = Mat()
        Core.extractChannel(hsv, hue, 0)
        val avgHueScalar = Core.mean(hue)
        val avgHue = avgHueScalar.`val`[0] // 0‑180 range

        // Map hue (0‑180) to midi note (C4=60 .. B4=71) on a chromatic scale
        val midi = 60 + ((avgHue / 180.0) * 12).toInt()
        val freq = 440.0 * Math.pow(2.0, (midi - 69) / 12.0)

        // Trigger a short note
        synth.setFrequency(freq)
        synth.setAmplitude(0.2)
        synth.playNote(0.1)

        // ---- Fractal wallpaper generation ----
        // Simple Mandelbrot‑like iteration where color depends on current audio amplitude
        val amp = ampQueue.poll() ?: 0f
        val img = BufferedImage(640, 480, BufferedImage.TYPE_INT_RGB)
        for (y in 0 until img.height) {
            val cy = (y - img.height / 2.0) * 4.0 / img.height
            for (x in 0 until img.width) {
                val cx = (x - img.width / 2.0) * 4.0 / img.width
                var zx = cx
                var zy = cy
                var iter = 0
                while (zx * zx + zy * zy < 4 && iter < 255) {
                    val tmp = zx * zx - zy * zy + cx
                    zy = 2 * zx * zy + cy
                    zx = tmp
                    // modulate iteration speed with audio amplitude
                    iter += (amp * 255).toInt()
                }
                // hue driven by original dominant hue, brightness by iteration count
                val color = Color.HSBtoRGB((avgHue / 180f), 1f, min(1f, iter / 255f))
                img.setRGB(x, y, color)
            }
        }
        // Show frame + fractal (simple window)
        display(img)
    }
    cam.release()
}

// Very lightweight Swing window that refreshes with the supplied image
private var frameWindow: javax.swing.JFrame? = null
private var imageLabel: javax.swing.JLabel? = null
fun display(img: BufferedImage) {
    if (frameWindow == null) {
        frameWindow = javax.swing.JFrame("Fractal‑Audio Visualiser")
        frameWindow!!.defaultCloseOperation = javax.swing.JFrame.EXIT_ON_CLOSE
        imageLabel = javax.swing.JLabel()
        frameWindow!!.contentPane.add(imageLabel)
        frameWindow!!.setSize(img.width, img.height)
        frameWindow!!.isVisible = true
    }
    val icon = javax.swing.ImageIcon(img)
    imageLabel!!.icon = icon
    frameWindow!!.repaint()
}