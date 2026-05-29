import java.io.Console
import java.util.*
import kotlin.math.*

// Simple real‑time audio visualizer (mocked with random data)
// Maps frequency bands to Unicode glyphs and scrolls them across the console.
// Press 'c' to change the glyph palette while running.

fun main() {
    val console: Console = System.console() ?: throw IllegalStateException("No console")
    val width = 80
    val height = 20
    val bands = 16
    val sampleRate = 44100
    val fps = 20
    val paletteSets = listOf(
        listOf('░','▒','▓','█'),
        listOf('·','*','✱','✦','✧','✩'),
        listOf('⬤','◯','◐','◑','◒','◓','◔','◕'),
        listOf('♩','♪','♫','♬','♭','♯')
    )
    var paletteIdx = 0
    var palette = paletteSets[paletteIdx]

    // scrolling buffer of characters
    val buffer = Array(height) { CharArray(width) { ' ' } }

    // timer loop
    val period = 1000L / fps
    while (true) {
        val start = System.currentTimeMillis()

        // --- Mock audio capture & FFT -------------------------------------------------
        // Generate random amplitudes for each frequency band
        val amplitudes = DoubleArray(bands) { Random().nextDouble() }

        // --- Map amplitudes to glyphs ------------------------------------------------
        val glyphLine = CharArray(width)
        for (x in 0 until width) {
            // pick band based on x position
            val band = (x.toDouble() / width * bands).toInt().coerceIn(0, bands - 1)
            val amp = amplitudes[band]
            // select glyph according to amplitude (0..1)
            val glyphIdx = (amp * (palette.size - 1)).roundToInt()
            glyphLine[x] = palette[glyphIdx]
        }

        // --- Scroll buffer -----------------------------------------------------------
        // shift everything up by one row
        for (y in 0 until height - 1) {
            buffer[y] = buffer[y + 1]
        }
        // put new line at bottom
        buffer[height - 1] = glyphLine

        // --- Render -------------------------------------------------------------------
        val sb = StringBuilder()
        for (y in 0 until height) {
            sb.append(buffer[y].concatToString())
            sb.append('\n')
        }
        console.writer().apply {
            print("\u001b[H\u001b[2J") // clear screen
            write(sb.toString())
            flush()
        }

        // --- Handle user input -------------------------------------------------------
        if (console.reader().ready()) {
            val ch = console.reader().read()
            if (ch == 'c'.code) {
                // cycle palette
                paletteIdx = (paletteIdx + 1) % paletteSets.size
                palette = paletteSets[paletteIdx]
            } else if (ch == 27) { // ESC to quit
                break
            }
        }

        // --- Timing -------------------------------------------------------------------
        val elapsed = System.currentTimeMillis() - start
        if (elapsed < period) Thread.sleep(period - elapsed)
    }
}