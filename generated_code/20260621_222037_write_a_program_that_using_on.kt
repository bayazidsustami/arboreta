import java.util.*
import kotlin.math.*

// Unicode symbols that look like musical notes
private val NOTES = arrayOf('♪', '♫', '♬', '♩', '♭', '♯')

// Simple data class for a note (pitch 0-12, duration in beats)
private data class Note(val pitch: Int, val duration: Int, val timbre: Int)

// Generate a short random melody
private fun composeMelody(length: Int = 8): List<Note> {
    val rnd = Random()
    return List(length) {
        Note(
            pitch = rnd.nextInt(13),          // 0..12 semitones
            duration = rnd.nextInt(3) + 1,   // 1..3 beats
            timbre = rnd.nextInt(NOTES.size) // index into NOTES
        )
    }
}

// Render an animated ASCII spectrogram (very rough)
private fun animateSpectrogram(melody: List<Note>) {
    val maxHeight = 10
    for ((step, note) in melody.withIndex()) {
        // height proportional to pitch
        val height = (note.pitch / 12.0 * maxHeight).roundToInt()
        // clear previous frame
        if (step > 0) print("\u001b[H\u001b[2J") // ANSI clear screen
        // draw columns for each note seen so far
        for (h in maxHeight downTo 0) {
            for (i in 0..step) {
                val n = melody[i]
                val colHeight = (n.pitch / 12.0 * maxHeight).roundToInt()
                if (colHeight >= h) {
                    // choose a character that resembles a note
                    print(NOTES[n.timbre])
                } else {
                    print(' ')
                }
                print(' ')
            }
            println()
        }
        Thread.sleep(300L * note.duration) // simulate duration
    }
}

// Create a poem where each word length encodes pitch, duration, timbre
private fun generatePoem(melody: List<Note>): String {
    val baseWords = listOf(
        "silence", "echo", "whisper", "storm", "dream", "shadow",
        "light", "river", "mountain", "forest", "crystal", "ember"
    )
    val sb = StringBuilder()
    for (note in melody) {
        // target length: 3 + pitch (0..12) + duration (1..3) + timbre (0..5)
        val target = 3 + note.pitch + note.duration + note.timbre
        // pick a base word and pad/truncate to needed length
        var word = baseWords[(note.pitch + note.timbre) % baseWords.size]
        if (word.length < target) {
            word += "a".repeat(target - word.length)
        } else if (word.length > target) {
            word = word.substring(0, target)
        }
        sb.append(word).append(' ')
    }
    return sb.toString().trim()
}

// Main entry point
fun main() {
    val melody = composeMelody()
    // Print the melodic line using only note symbols
    println("Melody: " + melody.joinToString(" ") { NOTES[it.timbre].toString() })
    // Animate spectrogram while “playing”
    animateSpectrogram(melody)
    // Output the encoded poem
    println("\nPoem:")
    println(generatePoem(melody))
}