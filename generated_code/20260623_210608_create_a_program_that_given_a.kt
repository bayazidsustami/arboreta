import java.io.File
import java.time.Instant
import javax.sound.midi.*
import kotlin.concurrent.thread
import kotlin.math.*

// ANSI colour codes for terminal output
val colors = arrayOf(
    "\u001B[31m", // red
    "\u001B[32m", // green
    "\u001B[33m", // yellow
    "\u001B[34m", // blue
    "\u001B[35m", // magenta
    "\u001B[36m", // cyan
    "\u001B[37m"  // white
)
const val RESET = "\u001B[0m"

// Simple data class to hold a note event
data class Note(val pitch: Int, val velocity: Int, val tick: Long, val duration: Long)

// Basic fractal generator – draws a tiny Sierpinski triangle sized by velocity
fun fractalLines(velocity: Int): List<String> {
    val size = 3 + (velocity / 32) // size between 3 and 10
    val lines = mutableListOf<String>()
    for (i in 0 until size) {
        val spaces = " ".repeat(size - i - 1)
        val stars = "*".repeat(2 * i + 1)
        lines.add(spaces + stars + spaces)
    }
    return lines
}

// Map pitch -> colour, shape, speed
fun colourFor(pitch: Int) = colors[(pitch / 12) % colors.size]
fun speedFor(pitch: Int) = 100L + (pitch % 12) * 20L // ms between moves
fun shapeFor(pitch: Int) = when (pitch % 4) {
    0 -> '*'
    1 -> '#'
    2 -> '@'
    else -> '+'
}

// Poetic mood generator based on overall velocity average
fun moodDescription(avgVel: Double): String = when {
    avgVel < 40 -> "A gentle rain of whispers."
    avgVel < 80 -> "Sunlit streams dance lightly."
    else -> "Tempestuous fire erupts fiercely."
}

// Main entry
fun main(args: Array<String>) {
    if (args.isEmpty()) {
        println("Usage: kotlin MidiWallpaper.kts <midi-file>")
        return
    }
    val midiFile = File(args[0])
    if (!midiFile.exists()) {
        println("File not found: ${args[0]}")
        return
    }

    // Parse MIDI and collect Note events
    val notes = mutableListOf<Note>()
    val sequence = MidiSystem.getSequence(midiFile)
    val resolution = sequence.resolution.toDouble()
    for (track in sequence.tracks) {
        var tickPos = 0L
        val onMap = mutableMapOf<Int, Pair<Long, Int>>() // pitch -> (tick, velocity)
        for (event in track) {
            tickPos = event.tick
            val msg = event.message
            if (msg is ShortMessage) {
                when (msg.command) {
                    ShortMessage.NOTE_ON -> {
                        val vel = msg.data2
                        if (vel > 0) onMap[msg.data1] = Pair(tickPos, vel)
                        else {
                            // treat velocity 0 as note off
                            onMap.remove(msg.data1)?.let { (start, v) ->
                                notes.add(Note(msg.data1, v, start, tickPos - start))
                            }
                        }
                    }
                    ShortMessage.NOTE_OFF -> {
                        onMap.remove(msg.data1)?.let { (start, v) ->
                            notes.add(Note(msg.data1, v, start, tickPos - start))
                        }
                    }
                }
            }
        }
    }

    // Sort notes by start tick
    notes.sortBy { it.tick }

    // Compute overall tempo (microseconds per quarter) from first tempo meta event if exists
    var usPerQuarter = 500_000L // default 120 BPM
    for (track in sequence.tracks) {
        for (event in track) {
            val msg = event.message
            if (msg is MetaMessage && msg.type == 0x51) {
                val data = msg.data
                usPerQuarter = ((data[0].toInt() and 0xFF) shl 16) or
                        ((data[1].toInt() and 0xFF) shl 8) or
                        (data[2].toInt() and 0xFF)
                break
            }
        }
    }

    // Compute average velocity for mood
    val avgVel = notes.map { it.velocity }.average()
    var lastMood = ""

    // Rendering thread
    val renderLock = Any()
    var activeFractals = mutableListOf<Pair<Note, Long>>() // note + creation time

    thread {
        while (true) {
            synchronized(renderLock) {
                // clear screen
                print("\u001B[H\u001B[2J")
                // draw each active fractal
                val now = Instant.now().toEpochMilli()
                val buffer = Array(30) { CharArray(80) { ' ' } }
                for ((note, startMs) in activeFractals) {
                    val elapsed = now - startMs
                    val speed = speedFor(note.pitch)
                    val offset = ((elapsed / speed) % 30).toInt()
                    val shape = shapeFor(note.pitch)
                    val fractal = fractalLines(note.velocity)
                    for (i in fractal.indices) {
                        val row = (i + offset) % 30
                        val line = fractal[i]
                        val colStart = (note.pitch % 12) * 6
                        for (j in line.indices) {
                            val col = (colStart + j) % 80
                            if (line[j] != ' ') buffer[row][col] = shape
                        }
                    }
                }
                // render buffer with colours
                for (row in buffer) {
                    for (ch in row) {
                        if (ch == ' ') print(' ')
                        else {
                            val colour = colourFor(ch.code)
                            print(colour + ch + RESET)
                        }
                    }
                    println()
                }
                // mood line
                val mood = moodDescription(avgVel)
                if (mood != lastMood) {
                    println("\n$mood")
                    lastMood = mood
                }
            }
            Thread.sleep(50)
        }
    }

    // Scheduler: add notes as they become due
    val startTime = Instant.now().toEpochMilli()
    for (note in notes) {
        val noteMs = (note.tick / resolution) * usPerQuarter / 1000.0
        val delay = (noteMs - (Instant.now().toEpochMilli() - startTime)).toLong()
        if (delay > 0) Thread.sleep(delay)
        synchronized(renderLock) {
            activeFractals.add(Pair(note, Instant.now().toEpochMilli()))
        }
        // schedule removal after its duration
        thread {
            val durMs = (note.duration / resolution) * usPerQuarter / 1000.0
            Thread.sleep(durMs.toLong())
            synchronized(renderLock) {
                activeFractals.removeIf { it.first == note }
            }
        }
    }

    // keep program alive until all notes finished
    while (true) {
        synchronized(renderLock) {
            if (activeFractals.isEmpty()) break
        }
        Thread.sleep(200)
    }
    println("\nFinished.")
}