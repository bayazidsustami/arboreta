import java.io.InputStream
import java.net.URL
import javax.sound.sampled.AudioFormat
import javax.sound.sampled.AudioSystem
import javax.sound.sampled.SourceDataLine
import kotlin.concurrent.thread
import kotlin.math.PI
import kotlin.math.sin
import kotlin.math.sqrt

// --- DOMAIN MODELS ---

data class SeismicEvent(
    val magnitude: Double,
    val depth: Double,
    val latitude: Double,
    val longitude: Double
)

// --- LIVE USGS DATA STREAM INGESTION ---

class SeismicStreamIngester(
    private val onEventFetched: (SeismicEvent) -> Unit
) {
    private val usgsUrl = "[https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.csv](https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.csv)"

    fun start() {
        thread(isDaemon = true, name = "USGS-Ingester") {
            val seenIds = mutableSetOf<String>()
            while (!Thread.currentThread().isInterrupted) {
                try {
                    val connection = URL(usgsUrl).openConnection()
                    connection.setConnectTimeout(5000)
                    connection.setReadTimeout(5000)
                    val stream: InputStream = connection.getInputStream()
                    
                    stream.bufferedReader().useLines { lines ->
                        lines.drop(1).forEach { line ->
                            val tokens = line.split(",")
                            if (tokens.size >= 5) {
                                val id = tokens.getOrNull(11) ?: line.hashCode().toString()
                                if (seenIds.add(id)) {
                                    val lat = tokens.getOrNull(1)?.toDoubleOrNull() ?: 0.0
                                    val lon = tokens.getOrNull(2)?.toDoubleOrNull() ?: 0.0
                                    val depth = tokens.getOrNull(3)?.toDoubleOrNull() ?: 10.0
                                    val mag = tokens.getOrNull(4)?.toDoubleOrNull() ?: 1.0
                                    
                                    onEventFetched(SeismicEvent(mag, depth, lat, lon))
                                }
                            }
                        }
                    }
                } catch (e: Exception) {
                    // Fallback to simulated organic noise if offline/throttled
                    onEventFetched(
                        SeismicEvent(
                            magnitude = 1.0 + Math.random() * 4.0,
                            depth = 5.0 + Math.random() * 50.0,
                            latitude = (Math.random() - 0.5) * 180.0,
                            longitude = (Math.random() - 0.5) * 360.0
                        )
                    )
                }
                Thread.sleep(15000) // Poll USGS feed every 15s
            }
        }
    }
}

// --- SYNTHESIS CORE: GRANULAR ENGINE ---

class Grain(
    private val sampleRate: Float,
    private val baseFreq: Double,
    private val durationSec: Double,
    private val amplitude: Double,
    private val pan: Double // 0.0 (Left) to 1.0 (Right)
) {
    private val totalFrames = (sampleRate * durationSec).toInt()
    private var currentFrame = 0
    val isFinished: Boolean get() = currentFrame >= totalFrames

    fun renderNextSample(): Pair<Double, Double> {
        if (isFinished) return 0.0 to 0.0

        // Hann Window Envelope for smooth granular overlap
        val envelope = 0.5 * (1.0 - Math.cos(2.0 * PI * currentFrame / (totalFrames - 1)))
        
        // Sine wave with slight harmonic detuning (simulating tectonic friction)
        val phase = 2.0 * PI * baseFreq * currentFrame / sampleRate
        val wave = sin(phase) + 0.25 * sin(phase * 1.5) + 0.1 * sin(phase * 0.5)
        
        val sample = wave * envelope * amplitude
        currentFrame++

        // Equal power panning
        val left = sample * Math.cos(pan * PI / 2.0)
        val right = sample * Math.sin(pan * PI / 2.0)
        return left to right
    }
}

class TectonicGranularEngine(
    private val sampleRate: Float = 44100f
) {
    @Volatile private var currentFrequency = 55.0 // Sub-bass drone root (A1)
    @Volatile private var currentGrainDuration = 0.8
    @Volatile private var currentDensity = 12 // Concurrent grains
    @Volatile private var currentStereoSpread = 0.5

    private val activeGrains = mutableListOf<Grain>()

    fun updateParameters(event: SeismicEvent) {
        // Map magnitude -> Frequency scale (exponential)
        currentFrequency = 30.0 + (event.magnitude * 25.0) 
        // Map depth -> Grain Duration (deeper quakes create longer, suspended textures)
        currentGrainDuration = (event.depth / 10.0).coerceIn(0.2, 3.5)
        // Map coordinates -> Spatial panning spread
        currentStereoSpread = ((event.longitude + 180.0) / 360.0).coerceIn(0.0, 1.0)
        
        println("[TECTONIC PULSE] Mag: ${event.magnitude} | Depth: ${event.depth}km | Drone Pitch: ${"%.2f".format(currentFrequency)}Hz")
    }

    @Synchronized
    fun renderBlock(frames: Int): Pair<FloatArray, FloatArray> {
        val leftBuffer = FloatArray(frames)
        val rightBuffer = FloatArray(frames)

        for (i in 0 until frames) {
            // Spawn new grains to maintain active density
            if (activeGrains.size < currentDensity && Math.random() < 0.05) {
                val detune = (Math.random() - 0.5) * 4.0 // Microtonal pitch shifting
                val pan = (currentStereoSpread + (Math.random() - 0.5) * 0.4).coerceIn(0.0, 1.0)
                
                activeGrains.add(
                    Grain(
                        sampleRate = sampleRate,
                        baseFreq = currentFrequency + detune,
                        durationSec = currentGrainDuration * (0.8 + Math.random() * 0.4),
                        amplitude = 0.15,
                        pan = pan
                    )
                )
            }

            // Sum audio output from all active grains
            var leftSum = 0.0
            var rightSum = 0.0
            val iterator = activeGrains.iterator()
            
            while (iterator.hasNext()) {
                val grain = iterator.next()
                val (l, r) = grain.renderNextSample()
                leftSum += l
                rightSum += r
                if (grain.isFinished) {
                    iterator.remove()
                }
            }

            // Soft-clipping master limiter
            leftBuffer[i] = Math.tanh(leftSum).toFloat()
            rightBuffer[i] = Math.tanh(rightSum).toFloat()
        }

        return leftBuffer to rightBuffer
    }
}

// --- HEADLESS AUDIO HARDWARE OUTPUT ROUTER ---

class AudioRenderer(
    private val engine: TectonicGranularEngine,
    private val sampleRate: Float = 44100f
) {
    fun start() {
        val format = AudioFormat(sampleRate, 16, 2, true, true)
        val line: SourceDataLine = AudioSystem.getSourceDataLine(format)
        line.open(format, 4096)
        line.start()

        println(">>> Headless Audio Engine initialized. Streaming infinite ambient drone from USGS data... <<<")

        thread(isDaemon = false, name = "Audio-Hardware-Output") {
            val bufferSize = 512
            val byteBuffer = ByteArray(bufferSize * 4) // 16-bit stereo = 4 bytes/frame

            while (!Thread.currentThread().isInterrupted) {
                val (left, right) = engine.renderBlock(bufferSize)

                for (i in 0 until bufferSize) {
                    val lSample = (left[i] * 32767.0f).toInt().coerceIn(-32768, 32767)
                    val rSample = (right[i] * 32767.0f).toInt().coerceIn(-32768, 32767)

                    // Big Endian Byte Packing
                    byteBuffer[i * 4 + 0] = (lSample shr 8).toByte()
                    byteBuffer[i * 4 + 1] = lSample.toByte()
                    byteBuffer[i * 4 + 2] = (rSample shr 8).toByte()
                    byteBuffer[i * 4 + 3] = rSample.toByte()
                }

                line.write(byteBuffer, 0, byteBuffer.size)
            }
            line.drain()
            line.close()
        }
    }
}

// --- MAIN EXECUTION ENTRYPOINT ---

fun main() {
    val engine = TectonicGranularEngine()
    val audioRenderer = AudioRenderer(engine)
    val ingester = SeismicStreamIngester { event ->
        engine.updateParameters(event)
    }

    // Launch background live ingestion feed & start high-priority PCM rendering loop
    ingester.start()
    audioRenderer.start()
}