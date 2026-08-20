import javax.sound.sampled.AudioFormat
import javax.sound.sampled.AudioSystem
import java.awt.Canvas
import java.awt.Color
import java.awt.Dimension
import java.awt.Graphics2D
import java.awt.RenderingHints
import java.awt.image.BufferedImage
import java.util.Random
import javax.swing.JFrame
import kotlin.math.pow
import kotlin.math.sin

// --- AUDIO ENGINE ---
class EsotericAudioEngine(private val sampleRate: Float = 44100f) {
    private val line = AudioSystem.getSourceDataLine(AudioFormat(sampleRate, 16, 1, true, true))
    private val bufferSize = 1024
    private val buffer = ByteArray(bufferSize * 2)

    data class Voice(var freq: Double, var amp: Double, var decay: Double)
    private val activeVoices = mutableListOf<Voice>()
    private var noiseAmp = 0.0
    private var noiseDecay = 0.95
    private val random = Random()

    init {
        line.open(line.format, bufferSize * 4)
        line.start()
    }

    // Maps memory pointer/hash codes to a microtonal frequency scale (24-TET / Quarter-tone)
    fun triggerTone(addressHash: Long) {
        val baseFreq = 110.0 // A2
        val quarterToneIndex = (addressHash borderAndShift 0x7FFFFFFF) % 96
        val microtonalFreq = baseFreq * 2.0.pow(quarterToneIndex / 48.0)
        synchronized(activeVoices) {
            activeVoices.add(Voice(microtonalFreq, 0.4, 0.998))
        }
    }

    // Converts memory errors into glitchy percussive white noise pops
    fun triggerPercussion(severity: Int) {
        noiseAmp = (0.3 + (severity % 5) * 0.15).coerceAtMost(1.0)
        noiseDecay = 0.85 + (severity % 10) * 0.01
    }

    private infix fun Long.borderAndShift(mask: Long): Int = (this and mask).toInt()

    fun renderChunk(visualizer: VisualizerWindow) {
        var phase = 0.0
        val out = DoubleArray(bufferSize)

        synchronized(activeVoices) {
            val iterator = activeVoices.iterator()
            while (iterator.hasNext()) {
                val voice = iterator.next()
                val phaseIncrement = 2.0 * Math.PI * voice.freq / sampleRate
                var currentPhase = 0.0
                for (i in 0 until bufferSize) {
                    out[i] += sin(currentPhase) * voice.amp
                    currentPhase += phaseIncrement
                }
                voice.amp *= voice.decay
                if (voice.amp < 0.001) iterator.remove()
            }
        }

        // Add glitch noise
        if (noiseAmp > 0.001) {
            for (i in 0 until bufferSize) {
                out[i] += (random.nextDouble() * 2.0 - 1.0) * noiseAmp
            }
            noiseAmp *= noiseDecay
        }

        // Convert double samples to 16-bit PCM bytes
        var byteIdx = 0
        var maxAmplitudeSum = 0.0
        for (i in 0 until bufferSize) {
            val sample = out[i].coerceIn(-1.0, 1.0)
            val pcm = (sample * 32767.0).toInt()
            buffer[byteIdx++] = (pcm shr 8).toByte()
            buffer[byteIdx++] = pcm.toByte()
            maxAmplitudeSum += Math.abs(sample)
        }

        line.write(buffer, 0, buffer.size)
        visualizer.updateFrame(maxAmplitudeSum / bufferSize, activeVoices.size)
    }
}

// --- VISUALIZER ---
class VisualizerWindow(width: Int = 800, height: Int = 600) : JFrame("Stack Trace Audio-Visualizer") {
    private val canvas = Canvas()
    private val img = BufferedImage(width, height, BufferedImage.TYPE_INT_RGB)
    private var energy = 0.0
    private var activeCount = 0
    private var currentMessage = "System Nominal"

    init {
        defaultCloseOperation = EXIT_ON_CLOSE
        canvas.preferredSize = Dimension(width, height)
        add(canvas)
        pack()
        isVisible = true
        canvas.createBufferStrategy(2)
    }

    fun setStatusMessage(msg: String) {
        currentMessage = msg
    }

    fun updateFrame(avgEnergy: Double, count: Int) {
        this.energy = avgEnergy
        this.activeCount = count

        val bs = canvas.bufferStrategy ?: return
        val g = bs.drawGraphics as Graphics2D
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        // Fade effect for ambient trail visuals
        g.color = Color(10, 8, 15, 40)
        g.fillRect(0, 0, canvas.width, canvas.height)

        val cx = canvas.width / 2
        val cy = canvas.height / 2
        val radius = (energy * 400.0).toInt().coerceAtLeast(10)

        // Draw dynamic audio-visual ripples based on pointer energy
        g.color = Color(
            (energy * 255).toInt().coerceIn(0, 255),
            (100 + activeCount * 20).coerceIn(0, 255),
            (200 - energy * 100).toInt().coerceIn(0, 255),
            180
        )
        g.drawOval(cx - radius / 2, cy - radius / 2, radius, radius)
        g.drawRect(cx - radius, cy - radius, radius * 2, radius * 2)

        // Overlay current stack/error message
        g.color = Color.CYAN
        g.drawString("ACTIVE HARMONICS: $activeCount", 20, 30)
        g.color = Color.MAGENTA
        g.drawString("TRACE: $currentMessage", 20, 50)

        bs.show()
        g.dispose()
    }
}

// --- MAIN ENGINE & RUNTIME EXCEPTION GENERATOR ---
fun main() {
    val audio = EsotericAudioEngine()
    val visualizer = VisualizerWindow()

    // Background thread continuously driving audio rendering
    Thread {
        while (true) {
            audio.renderChunk(visualizer)
        }
    }.apply { isDaemon = true; start() }

    // Synthesize stack traces and simulated memory failures into the audio-visual engine
    val simulatedErrors = listOf(
        NullPointerException("Attempted to dereference null pointer at 0x7FFF5FBFF040"),
        StackOverflowError("Call stack depth exceeded memory boundary at 0x00007FA8"),
        OutOfMemoryError("Failed to allocate 1048576 bytes at 0xDEADBEEF"),
        IndexOutOfBoundsException("Pointer offset outside valid range at 0x00000000")
    )

    var step = 0
    while (true) {
        val err = simulatedErrors[step % simulatedErrors.size]
        visualizer.setStatusMessage(err.toString())

        // Extract raw object pointer hashes and stack frame addresses
        val stackTrace = err.stackTrace
        val pointerHash = System.identityHashCode(err).toLong() xor System.currentTimeMillis()

        // 1. Map memory pointer hashes to microtonal ambient harmonic frequencies
        audio.triggerTone(pointerHash)

        // 2. Map structural stack trace depth and memory error types to glitchy percussion
        audio.triggerPercussion(err.message?.length ?: 10)

        for (element in err.stackTrace) {
            val frameHash = element.className.hashCode().toLong() + element.lineNumber
            audio.triggerTone(frameHash)
            Thread.sleep(150)
        }

        step++
        Thread.sleep(1000)
    }
}