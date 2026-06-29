import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import org.opencv.videoio.VideoCapture
import org.opencv.core.CvType.*
import java.awt.image.BufferedImage
import java.io.ByteArrayInputStream
import javax.imageio.ImageIO
import javax.sound.midi.*
import kotlin.math.roundToInt
import kotlin.random.Random

// Load native OpenCV library
object OpenCVLoader {
    init { System.loadLibrary(Core.NATIVE_LIBRARY_NAME) }
}

// Simple data class for a chord
data class Chord(val name: String, val tension: Int)

// Map hue (0-179) to a chord on the circle of fifths
fun hueToChord(hue: Double): Chord {
    val fifths = listOf(
        "C", "G", "D", "A", "E", "B", "F♯", "C♯",
        "A♭", "E♭", "B♭", "F"
    )
    val idx = ((hue / 180.0) * fifths.size).toInt() % fifths.size
    val name = fifths[idx]
    // tension: 0=consonant, 1=moderate, 2=high
    val tension = when (name) {
        "F♯", "C♯", "A♭", "E♭", "B♭" -> 2
        "F", "B", "E", "A", "D", "G" -> 1
        else -> 0
    }
    return Chord(name, tension)
}

// Convert Mat to BufferedImage for processing
fun matToBufferedImage(mat: Mat): BufferedImage {
    val size = mat.total() * mat.elemSize()
    val buf = ByteArray(size.toInt())
    mat.get(0, 0, buf)
    val image = BufferedImage(mat.cols(), mat.rows(), BufferedImage.TYPE_3BYTE_BGR)
    val targetPixels = (image.raster.dataBuffer as java.awt.image.DataBufferByte).data
    System.arraycopy(buf, 0, targetPixels, 0, buf.size)
    return image
}

// Extract dominant hue using k‑means (k=1 for simplicity)
fun dominantHue(image: BufferedImage): Double {
    val hsv = Mat()
    val src = Mat(image.height, image.width, CV_8UC3)
    val data = (src.raster.dataBuffer as java.awt.image.DataBufferByte).data
    System.arraycopy((image.raster.dataBuffer as java.awt.image.DataBufferByte).data, 0, data, 0, data.size)
    Imgproc.cvtColor(src, hsv, Imgproc.COLOR_BGR2HSV)

    val pixels = mutableListOf<DoubleArray>()
    for (y in 0 until hsv.rows()) {
        for (x in 0 until hsv.cols()) {
            val h = hsv.get(y, x)[0]
            pixels.add(doubleArrayOf(h))
        }
    }
    val criteria = TermCriteria(TermCriteria.EPS + TermCriteria.MAX_ITER, 10, 1.0)
    val labels = Mat()
    val centers = Mat()
    val samples = Mat(pixels.size, 1, CV_32F)
    for (i in pixels.indices) samples.put(i, 0, pixels[i][0].toFloat())
    Core.kmeans(samples, 1, labels, criteria, 1, Core.KMEANS_PP_CENTERS, centers)
    return centers.get(0, 0)[0]
}

// Generate ASCII art based on tension
fun generateAscii(tension: Int, width: Int = 80, height: Int = 20): List<String> {
    val charset = when (tension) {
        0 -> " .`'-"
        1 -> "*+oO#"
        else -> "@%$&8"
    }
    return List(height) {
        (0 until width).joinToString("") {
            charset[Random.nextInt(charset.length)].toString()
        }
    }
}

// Play chord via MIDI (simple major triad)
fun playChord(chord: Chord, synth: Synthesizer) {
    val notes = mapOf(
        "C" to 60, "G" to 67, "D" to 62, "A" to 69,
        "E" to 64, "B" to 71, "F♯" to 66, "C♯" to 61,
        "A♭" to 68, "E♭" to 63, "B♭" to 70, "F" to 65
    )
    val root = notes[chord.name] ?: 60
    val channel = synth.channels[0]
    channel.programChange(0) // acoustic grand piano
    channel.noteOn(root, 80)
    channel.noteOn(root + 4, 80) // major third
    channel.noteOn(root + 7, 80) // perfect fifth
    Thread.sleep(200)
    channel.allNotesOff()
}

// Main loop
fun main() {
    OpenCVLoader // ensure lib loaded
    val cap = VideoCapture(0)
    if (!cap.isOpened) {
        println("Cannot open camera")
        return
    }

    val synth = MidiSystem.getSynthesizer()
    synth.open()

    while (true) {
        val frame = Mat()
        if (!cap.read(frame) || frame.empty()) break

        val img = matToBufferedImage(frame)
        val hue = dominantHue(img)
        val chord = hueToChord(hue)

        // async sound
        Thread { playChord(chord, synth) }.start()

        // clear console (works on most terminals)
        print("\u001b[H\u001b[2J")
        println("Chord: ${chord.name} (tension=${chord.tension})")
        generateAscii(chord.tension).forEach { println(it) }

        // small pause to keep UI responsive
        Thread.sleep(33)
    }

    cap.release()
    synth.close()
}