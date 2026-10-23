import java.io.File
import javax.sound.midi.*

// Log-to-Jazz Musical Score Compiler in Kotlin
// Parses log files and converts entries into a melancholic jazz MIDI sequence,
// featuring dramatic minor-blues saxophone solos for ERROR levels.

fun main(args: Array<String>) {
    val logFile = if (args.isNotEmpty()) File(args[0]) else createSampleLog()
    println("Compiling log file '${logFile.name}' into a tragic jazz score...")

    val sequence = Sequence(Sequence.PPQ, 4)
    val track = sequence.createTrack()

    // Set tempo (~90 BPM for a smoky jazz club vibe)
    val tempoMeta = MetaMessage(0x51, byteArrayOf(0x0E, 0x46, 0x50), 3)
    track.add(MidiEvent(tempoMeta, 0))

    // Set instrument to Alto Saxophone (Program 65 in General MIDI)
    val pc = ShortMessage(ShortMessage.PROGRAM_CHANGE, 0, 65, 0)
    track.add(MidiEvent(pc, 0))

    var tick = 0L
    for (line in logFile.readLines()) {
        if (line.isBlank()) continue
        val event = parseLogLine(line)
        tick = renderMusicalPhrase(track, event, tick)
    }

    val outputMidi = File("jazz_score.mid")
    MidiSystem.write(sequence, 1, outputMidi)
    println("Musical score compiled successfully to '${outputMidi.absolutePath}'!")
}

data class LogEvent(val level: String, val message: String, val timestamp: String)

fun parseLogLine(line: String): LogEvent {
    val regex = Regex("""^(\S+ \S+)?\s*\[?(INFO|WARN|ERROR|DEBUG)?\]?\s*(.*)$""", RegexOption.IGNORE_CASE)
    val match = regex.find(line)
    val level = match?.groups?.get(2)?.value?.uppercase() ?: "INFO"
    val msg = match?.groups?.get(3)?.value ?: line
    val time = match?.groups?.get(1)?.value ?: "now"
    return LogEvent(level, msg, time)
}

fun renderMusicalPhrase(track: Track, event: LogEvent, startTick: Long): Long {
    var tick = startTick
    val channel = 0
    
    when (event.level) {
        "ERROR" -> {
            // Tragic Jazz Saxophone Solo: D minor blues scale with expressive bends & syncopation
            val soloNotes = listOf(62, 65, 67, 68, 69, 72, 69, 67, 65, 62)
            println("🎷 [TRAGIC SAX SOLO] ${event.message}")
            for (note in soloNotes) {
                track.add(MidiEvent(ShortMessage(ShortMessage.NOTE_ON, channel, note, 95), tick))
                tick += 35 
                track.add(MidiEvent(ShortMessage(ShortMessage.NOTE_OFF, channel, note, 0), tick))
                tick += 10
            }
        }
        "WARN" -> {
            // Suspenseful minor chord warning
            println("⚠️ [SUSPENSE CHORD] ${event.message}")
            val chord = listOf(60, 63, 67)
            for (note in chord) {
                track.add(MidiEvent(ShortMessage(ShortMessage.NOTE_ON, channel, note, 75), tick))
            }
            tick += 60
            for (note in chord) {
                track.add(MidiEvent(ShortMessage(ShortMessage.NOTE_OFF, channel, note, 0), tick))
            }
        }
        else -> {
            // Smooth walking bassline for standard INFO entries
            println("🎵 [WALKING BASS] ${event.message}")
            val note = 48 + (event.message.length % 12)
            track.add(MidiEvent(ShortMessage(ShortMessage.NOTE_ON, channel, note, 60), tick))
            tick += 20
            track.add(MidiEvent(ShortMessage(ShortMessage.NOTE_OFF, channel, note, 0), tick))
            tick += 20
        }
    }
    return tick
}

fun createSampleLog(): File {
    val file = File("sample.log")
    file.writeText("""
        2026-06-06 10:00:01 [INFO] System boot initiated successfully.
        2026-06-06 10:00:05 [INFO] Establishing secure handshake with upstream server.
        2026-06-06 10:01:20 [WARN] High memory utilization detected: 84%.
        2026-06-06 10:02:11 [ERROR] NullPointerException in payment gateway: transaction aborted.
        2026-06-06 10:02:12 [INFO] Attempting fallback circuit breaker routine.
        2026-06-06 10:03:00 [ERROR] Database connection timeout: all retry pools exhausted.
    """.trimIndent())
    return file
}

main(args)