import java.io.ByteArrayInputStream
import java.io.File
import javax.sound.sampled.*
import kotlin.math.*

/**
 * Acoustic File System (AFS)
 * Encodes binary data into polyphonic audio tracks (WAV).
 * To retrieve files, the user must provide an audio recording (e.g., humming or singing)
 * that matches the required key harmonic frequencies encoded in the track header.
 */
class AcousticFileSystem(private val sampleRate: Float = 44100f) {

    data class StoredAudioPackage(
        val audioFile: File,
        val requiredFrequencies: List<Double>
    )

    /**
     * Encodes a byte array into a polyphonic WAV audio file.
     * Generates a unique key chord based on file data hash.
     */
    fun store(filename: String, data: ByteArray): StoredAudioPackage {
        val keyFrequencies = generateKeyChord(data)
        val audioBytes = synthesizeAudio(data, keyFrequencies)
        
        val format = AudioFormat(sampleRate, 16, 1, true, false)
        val bais = ByteArrayInputStream(audioBytes)
        val audioInputStream = AudioInputStream(bais, format, audioBytes.size.toLong() / 2)
        
        val outputFile = File("$filename.wav")
        AudioSystem.write(audioInputStream, AudioFileFormat.Type.WAVE, outputFile)
        
        return StoredAudioPackage(outputFile, keyFrequencies)
    }

    /**
     * Unlocks and retrieves data from an encoded audio file if the provided acoustic input
     * (hum/singing sample) contains the target chord frequencies.
     */
    fun retrieve(encodedPackage: StoredAudioPackage, sungInputAudio: ByteArray): ByteArray? {
        val detectedFreqs = detectFrequencies(sungInputAudio)
        val isHarmonicMatch = encodedPackage.requiredFrequencies.all { target ->
            detectedFreqs.any { abs(it - target) < 15.0 } // 15 Hz tolerance
        }

        if (!isHarmonicMatch) {
            println("[AFS Error] Access Denied: Incorrect harmonic chord sung!")
            return null
        }

        println("[AFS Success] Harmonic key matched! File unlocked.")
        return extractDataFromAudio(encodedPackage.audioFile)
    }

    private fun generateKeyChord(data: ByteArray): List<Double> {
        val hash = data.fold(0) { acc, byte -> (acc * 31 + byte.toInt()) and 0x7FFFFFFF }
        val f1 = 200.0 + (hash % 200)
        val f2 = f1 * 1.25 // Major third interval
        val f3 = f1 * 1.50 // Perfect fifth interval
        return listOf(f1, f2, f3)
    }

    private fun synthesizeAudio(data: ByteArray, keyFreqs: List<Double>): ByteArray {
        val durationPerByte = 0.01 // 10ms per byte
        val totalDuration = data.size * durationPerByte
        val totalSamples = (totalDuration * sampleRate).toInt()
        val pcmData = ByteArray(totalSamples * 2)

        for (i in 0 until totalSamples) {
            val t = i / sampleRate.toDouble()
            val byteIndex = (t / durationPerByte).toInt().coerceAtMost(data.size - 1)
            val byteVal = (data[byteIndex].toInt() and 0xFF) / 255.0

            // Mix data byte signal with key chord sine waves
            var signal = byteVal * 0.5
            keyFreqs.forEach { freq ->
                signal += 0.16 * sin(2.0 * PI * freq * t)
            }

            val pcmSample = (signal.coerceIn(-1.0, 1.0) * 32767).toInt().toShort()
            pcmData[i * 2] = (pcmSample.toInt() and 0xFF).toByte()
            pcmData[i * 2 + 1] = ((pcmSample.toInt() shr 8) and 0xFF).toByte()
        }
        return pcmData
    }

    private fun extractDataFromAudio(audioFile: File): ByteArray {
        val audioStream = AudioSystem.getAudioInputStream(audioFile)
        val pcmBytes = audioStream.readAllBytes()
        val durationPerByte = 0.01
        val bytesCount = (pcmBytes.size / (2 * sampleRate * durationPerByte)).toInt()
        
        val extracted = ByteArray(bytesCount)
        val samplesPerByte = (sampleRate * durationPerByte).toInt()

        for (b in 0 until bytesCount) {
            val sampleIndex = b * samplesPerByte
            if (sampleIndex * 2 + 1 < pcmBytes.size) {
                val low = pcmBytes[sampleIndex * 2].toInt() and 0xFF
                val high = pcmBytes[sampleIndex * 2 + 1].toInt() shl 8
                val pcmSample = (high or low).toShort()
                val valNormalized = (pcmSample.toDouble() / 32767.0).coerceIn(0.0, 1.0)
                extracted[b] = (valNormalized * 255).toInt().toByte()
            }
        }
        return extracted
    }

    private fun detectFrequencies(audioInput: ByteArray): List<Double> {
        // Zero-Crossing estimation to measure fundamental input pitch
        var lastSample = 0
        var crossings = 0
        val numSamples = audioInput.size / 2
        
        for (i in 0 until numSamples) {
            val low = audioInput[i * 2].toInt() and 0xFF
            val high = audioInput[i * 2 + 1].toInt() shl 8
            val sample = (high or low).toShort().toInt()
            
            if ((lastSample < 0 && sample >= 0) || (lastSample >= 0 && sample < 0)) {
                crossings++
            }
            lastSample = sample
        }

        val fundamentalFreq = (crossings * sampleRate) / (2.0 * numSamples)
        
        // Generate chord harmonies from detected fundamental frequency
        return listOf(
            fundamentalFreq,
            fundamentalFreq * 1.25,
            fundamentalFreq * 1.50
        )
    }
}

fun main() {
    println("--- Acoustic File System ---")
    val afs = AcousticFileSystem()
    val secretData = "Polyphonic Acoustic Vault Secured".toByteArray()

    // 1. Encode data into audio file with unique harmonic signature
    val pkg = afs.store("secret_vault", secretData)
    println("Stored file: ${pkg.audioFile.name}")
    println("Required Harmonic Frequencies: ${pkg.requiredFrequencies.map { "%.2f Hz".format(it) }}")

    // 2. Simulate correct humming matching the key frequency
    val correctHum = synthesizeHum(pkg.requiredFrequencies[0], durationSec = 1.0)
    println("\n[User Input] Singing/humming fundamental frequency (${pkg.requiredFrequencies[0].toInt()} Hz)...")
    val result = afs.retrieve(pkg, correctHum)
    if (result != null) {
        println("Decoded Content: ${String(result)}")
    }

    // 3. Simulate incorrect hum pitch
    val wrongHum = synthesizeHum(440.0, durationSec = 1.0)
    println("\n[User Input] Singing incorrect pitch (440 Hz)...")
    afs.retrieve(pkg, wrongHum)
    
    pkg.audioFile.delete()
}

fun synthesizeHum(freq: Double, durationSec: Double, sampleRate: Float = 44100f): ByteArray {
    val totalSamples = (durationSec * sampleRate).toInt()
    val bytes = ByteArray(totalSamples * 2)
    for (i in 0 until totalSamples) {
        val t = i / sampleRate.toDouble()
        val pcmSample = (sin(2.0 * PI * freq * t) * 20000).toInt().toShort()
        bytes[i * 2] = (pcmSample.toInt() and 0xFF).toByte()
        bytes[i * 2 + 1] = ((pcmSample.toInt() shr 8) and 0xFF).toByte()
    }
    return bytes
}