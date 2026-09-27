import java.io.File
import javax.sound.sampled.AudioFileFormat
import javax.sound.sampled.AudioFormat
import javax.sound.sampled.AudioInputStream
import javax.sound.sampled.AudioSystem
import kotlin.math.exp
import kotlin.math.sin

fun main() {
    // 1. Gather repository vitals: commit timestamps and unmerged pull request count
    val (timestamps, unmergedPrs) = fetchRepoVitals()
    println("Analyzing repository... Found ${timestamps.size} recent commits and $unmergedPrs unmerged PRs.")

    // 2. Configure audio parameters (44.1kHz, 16-bit mono PCM)
    val sampleRate = 44100f
    val durationSeconds = 5.0
    val totalSamples = (sampleRate * durationSeconds).toInt()
    val audioData = ByteArray(totalSamples * 2)

    // 3. Establish base harmonic frequencies (Root, Perfect Fifth, Octave)
    val baseFreqs = listOf(196.0, 293.66, 392.0) // G3, D4, G4
    
    // Harmonic dissonance scales directly with the number of unmerged PRs
    val dissonanceFactor = unmergedPrs * 0.04

    // Calculate repository stagnation decay rate based on commit recency
    val now = System.currentTimeMillis() / 1000
    val lastCommit = timestamps.maxOrNull() ?: now
    val stagnationSeconds = (now - lastCommit).coerceAtLeast(1L)
    val stagnationDecay = 1.0 / (1.0 + (stagnationSeconds / 86400.0) * 0.05)

    // 4. Synthesize the audio landscape sample by sample
    for (i in 0 until totalSamples) {
        val t = i / sampleRate
        val envelope = exp(-t * 0.7) * stagnationDecay

        var sampleValue = 0.0
        baseFreqs.forEachIndexed { index, freq ->
            // Modulate frequency deviation using the dissonance factor from unmerged PRs
            val detunedFreq = freq * (1.0 + (index * dissonanceFactor))
            
            // Add rich harmonic waves; introduce a jarring tritone overlay if PR debt is high
            val wave = sin(2.0 * Math.PI * detunedFreq * t) + 
                       if (unmergedPrs > 3) 0.4 * sin(2.0 * Math.PI * (detunedFreq * 1.414) * t) else 0.0
            
            sampleValue += wave / baseFreqs.size
        }

        // Scale amplitude, apply envelope, and clamp to 16-bit PCM range
        val amplitude = (sampleValue * envelope * 32767.0).coerceIn(-32768.0, 32767.0).toInt()

        // Write little-endian 16-bit sample bytes
        audioData[i * 2] = (amplitude and 0xFF).toByte()
        audioData[i * 2 + 1] = ((amplitude shr 8) and 0xFF).toByte()
    }

    // 5. Render and export the generated landscape to a WAV file
    val format = AudioFormat(sampleRate, 16, 1, true, false)
    val audioInputStream = AudioInputStream(audioData.inputStream(), format, totalSamples.toLong())
    val outputFile = File("stagnant_landscape.wav")
    
    AudioSystem.write(audioInputStream, AudioFileFormat.Type.WAVE, outputFile)
    println("Audio landscape successfully rendered to '${outputFile.absolutePath}'")
}

fun fetchRepoVitals(): Pair<List<Long>, Int> {
    val timestamps = mutableListOf<Long>()
    var unmergedPrs = 0
    try {
        // Read recent git commit timestamps
        val logProc = ProcessBuilder("git", "log", "--format=%ct", "-n", "30").start()
        logProc.inputStream.bufferedReader().useLines { lines ->
            lines.forEach { line -> line.toLongOrNull()?.let { timestamps.add(it) } }
        }
        logProc.waitFor()

        // Query open PRs via GitHub CLI
        val prProc = ProcessBuilder("gh", "pr", "list", "--state", "open", "--json", "number").start()
        val prOutput = prProc.inputStream.bufferedReader().readText()
        unmergedPrs = prOutput.split("number").size - 1
        if (unmergedPrs < 0) unmergedPrs = 0
    } catch (e: Exception) {
        // Fallback simulation data if not in a valid git repository or CLI tools are missing
        timestamps.addAll(listOf(1710000000L, 1709200000L, 1708000000L))
        unmergedPrs = 5
    }
    if (timestamps.isEmpty()) timestamps.add(System.currentTimeMillis() / 1000)
    return Pair(timestamps, unmergedPrs)
}