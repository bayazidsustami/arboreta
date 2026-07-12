// Whispering code, a poem of bits and beats
// Each line a verse, each char a note, each loop a breath

import java.awt.Color
import java.awt.image.BufferedImage
import java.io.File
import javax.imageio.ImageIO
import javax.sound.sampled.AudioFormat
import javax.sound.sampled.AudioSystem

// map a char to a frequency: A4 = 440 Hz, shift by code point
fun charToFreq(c: Char): Double = 440.0 * Math.pow(2.0, (c.code - 69) / 12.0)

// generate a tone for given frequency and duration (seconds)
fun tone(freq: Double, dur: Double, sampleRate: Int = 44100): ShortArray {
    val sampleCount = (dur * sampleRate).toInt()
    val data = ShortArray(sampleCount)
    for (i in 0 until sampleCount) {
        val t = i.toDouble() / sampleRate
        // simple sine wave, gently faded
        val amplitude = Math.sin(2 * Math.PI * freq * t) * Math.exp(-3 * t / dur)
        data[i] = (amplitude * Short.MAX_VALUE).toInt().toShort()
    }
    return data
}

// cellular automaton: each cell holds a frequency, evolves by averaging neighbours
fun evolve(grid: Array<DoubleArray>): Array<DoubleArray> {
    val rows = grid.size
    val cols = grid[0].size
    val next = Array(rows) { DoubleArray(cols) }
    for (r in 0 until rows) {
        for (c in 0 until cols) {
            var sum = 0.0
            var cnt = 0
            for (dr in -1..1) {
                for (dc in -1..1) {
                    val nr = r + dr
                    val nc = c + dc
                    if (nr in 0 until rows && nc in 0 until cols) {
                        sum += grid[nr][nc]
                        cnt++
                    }
                }
            }
            // self‑modulating: blend with original tone
            next[r][c] = (sum / cnt + grid[r][c]) / 2
        }
    }
    return next
}

// paint the grid as a fractal‑like image
fun render(grid: Array<DoubleArray>, size: Int = 1024): BufferedImage {
    val img = BufferedImage(size, size, BufferedImage.TYPE_INT_RGB)
    val rows = grid.size
    val cols = grid[0].size
    for (y in 0 until size) {
        for (x in 0 until size) {
            val rIdx = y * rows / size
            val cIdx = x * cols / size
            val freq = grid[rIdx][cIdx]
            // map frequency to a colour hue
            val hue = ((Math.log(freq / 440.0) / Math.log(2.0) + 9) % 1.0).toFloat()
            val rgb = Color.HSBtoRGB(hue, 0.6f, 0.9f)
            img.setRGB(x, y, rgb)
        }
    }
    return img
}

// main: read text, build initial grid, run automaton, output sound and picture
fun main() {
    // read any piece of text from stdin
    val text = generateSequence(::readLine).joinToString("\n")
    // dimensions proportional to sqrt of length
    val dim = Math.ceil(Math.sqrt(text.length.toDouble())).toInt()
    val grid = Array(dim) { DoubleArray(dim) }
    // fill grid with frequencies derived from characters
    for (i in text.indices) {
        val r = i / dim
        val c = i % dim
        grid[r][c] = charToFreq(text[i])
    }

    // evolve a few generations, collecting audio samples
    val sampleRate = 44100
    val audioBuffer = mutableListOf<Short>()
    var current = grid
    repeat(8) { gen ->
        // each cell emits a short tone
        for (r in current.indices) {
            for (c in current[0].indices) {
                audioBuffer.addAll(tone(current[r][c], 0.05, sampleRate).asList())
            }
        }
        current = evolve(current)
    }

    // write audio file (WAV)
    val format = AudioFormat(sampleRate.toFloat(), 16, 1, true, false)
    val byteBuf = ByteArray(audioBuffer.size * 2)
    for (i in audioBuffer.indices) {
        val v = audioBuffer[i].toInt()
        byteBuf[i * 2] = (v and 0xFF).toByte()
        byteBuf[i * 2 + 1] = ((v shr 8) and 0xFF).toByte()
    }
    val ais = AudioSystem.getAudioInputStream(AudioFormat.Encoding.PCM_SIGNED, 
        AudioSystem.getAudioInputStream(format, AudioSystem.getAudioInputStream(
            javax.sound.sampled.AudioInputStream(byteBuf.inputStream(), format, audioBuffer.size.toLong()))))
    AudioSystem.write(ais, javax.sound.sampled.AudioFileFormat.Type.WAVE, File("output.wav"))

    // render final fractal
    val finalImg = render(current, 2048)
    ImageIO.write(finalImg, "png", File("fractal.png"))
}

// End of poetic program, where silence meets color.