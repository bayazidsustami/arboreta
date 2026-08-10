import javax.sound.midi.*
import java.io.File
import kotlin.math.ln

/**
 * Esoteric Code Aesthetic Linter & MIDI Harmonizer
 * Analyzes structural entropy (complexity) and indentation whitespace (rhythm & pitch depth) 
 * of source code files to generate a harmonically tuned MIDI composition.
 */

// Harmonically tuned C Major Pentatonic Scale for smooth, consonant melodies
val PENTATONIC_SCALE = intArrayOf(60, 62, 64, 67, 69, 72, 74, 76, 79, 81)
// Low C Pentatonic Bass line for harmonic grounding
val BASS_SCALE = intArrayOf(36, 38, 40, 43, 45, 48)

// Computes Shannon Entropy (information density) of a string line
fun calculateEntropy(s: String): Double {
    if (s.isEmpty()) return 0.0
    val freqMap = s.groupingBy { it }.eachCount()
    val len = s.length.toDouble()
    return freqMap.values.fold(0.0) { acc, count ->
        val p = count / len
        acc - (p * (ln(p) / ln(2.0)))
    }
}

// Measures structural depth via indentation spaces/tabs
fun measureIndentation(line: String): Int {
    var depth = 0
    for (ch in line) {
        when (ch) {
            ' ' -> depth++
            '\t' -> depth += 4
            else -> break
        }
    }
    return depth
}

fun main(args: Array<String>) {
    // Default sample code if no input file path is supplied
    val defaultCode = """
        fun fibonacci(n: Int): Long {
            if (n <= 1) return n.toLong()
            var a = 0L
            var b = 1L
            for (i in 2..n) {
                val temp = a + b
                a = b
                b = temp
            }
            return b
        }

        class FlowMatrix<T>(val capacity: Int) {
            private val items = mutableListOf<T>()

            fun push(item: T): Boolean {
                if (items.size < capacity) {
                    items.add(item)
                    return true
                }
                return false
            }
        }
    """.trimIndent()

    val sourceCode = if (args.isNotEmpty() && File(args[0]).exists()) {
        File(args[0]).readText()
    } else {
        defaultCode
    }

    val lines = sourceCode.lines().filter { it.isNotBlank() }

    // Set up MIDI Sequence (24 ticks per quarter note)
    val ticksPerQuarter = 24
    val sequence = Sequence(Sequence.PPQ, ticksPerQuarter)
    val track = sequence.createTrack()

    // MIDI Program Changes: Channel 0 -> Marimba (12), Channel 1 -> Acoustic Bass (32)
    track.add(MidiEvent(ShortMessage(ShortMessage.PROGRAM_CHANGE, 0, 12, 0), 0))
    track.add(MidiEvent(ShortMessage(ShortMessage.PROGRAM_CHANGE, 1, 32, 0), 0))

    println("=== Esoteric Code Aesthetic Linter Output ===")
    println(String.format("%-5s | %-8s | %-10s | %-6s | %-10s", "Line", "Indent", "Entropy", "Pitch", "Duration"))
    println("--------------------------------------------------")

    var currentTick = 0L

    lines.forEachIndexed { index, line ->
        val indent = measureIndentation(line)
        val entropy = calculateEntropy(line.trim())

        // Map indentation depth to scale degrees
        val noteIndex = (indent / 2) % PENTATONIC_SCALE.size
        val pitch = PENTATONIC_SCALE[noteIndex]

        // Map entropy to dynamic velocity (loudness) and note duration
        val velocity = ((entropy / 4.5).coerceIn(0.2, 1.0) * 127).toInt()
        val durationTicks = when {
            entropy > 3.5 -> ticksPerQuarter * 2 // Half note for high structural entropy
            entropy > 2.0 -> ticksPerQuarter     // Quarter note
            else -> ticksPerQuarter / 2          // Eighth note
        }

        println(String.format("%-5d | %-8d | %-10.2f | %-6d | %-10d", index + 1, indent, entropy, pitch, durationTicks))

        // Trigger Main Melody Note
        track.add(MidiEvent(ShortMessage(ShortMessage.NOTE_ON, 0, pitch, velocity), currentTick))

        // Add harmonic bass accompaniment on indented control structures
        if (indent > 0 && index % 2 == 0) {
            val bassPitch = BASS_SCALE[indent % BASS_SCALE.size]
            val bassVelocity = (velocity * 0.85).toInt()
            track.add(MidiEvent(ShortMessage(ShortMessage.NOTE_ON, 1, bassPitch, bassVelocity), currentTick))
            track.add(MidiEvent(ShortMessage(ShortMessage.NOTE_OFF, 1, bassPitch, 0), currentTick + durationTicks * 2))
        }

        // Turn off Main Melody Note
        track.add(MidiEvent(ShortMessage(ShortMessage.NOTE_OFF, 0, pitch, 0), currentTick + durationTicks))

        currentTick += durationTicks
    }

    // Render composition to standard MIDI file
    val outputFile = File("aesthetic_composition.mid")
    MidiSystem.write(sequence, 1, outputFile)
    
    println("--------------------------------------------------")
    println("Harmonic MIDI composition exported: ${outputFile.absolutePath}")
}