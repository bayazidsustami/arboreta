import javax.sound.sampled.*
import kotlin.math.*

/**
 * Visual Esoteric Language Interpreter: Dynamic ASCII Fractal IP Navigator
 * 
 * Instruction pointers (IP) navigate dynamic Julia set fractals.
 * Character brightness alters the IP's trajectory angle.
 * Executing opcodes mutates state and synthesizes real-time chiptune audio via Java Sound.
 */

class FractalChiptuneInterpreter {
    private val width = 80
    private val height = 28
    private val chars = " .:-=+*#%@"
    
    // Instruction Pointer & Memory State
    private var ipX = width / 2.0
    private var ipY = height / 2.0
    private var ipAngle = 0.0
    private val memory = IntArray(16)
    private var ptr = 0
    private var time = 0.0

    // Audio synth setup (8-bit PCM square wave @ 44.1kHz for classic chiptune sound)
    private val sampleRate = 44100f
    private val format = AudioFormat(sampleRate, 8, 1, true, false)
    private val audioLine = AudioSystem.getSourceDataLine(format).apply {
        open(format, 2048)
        start()
    }

    fun run() {
        print("\u001B[2J\u001B[?25l") // Clear terminal screen & hide cursor
        
        try {
            while (true) {
                time += 0.04
                val grid = generateJuliaFractal(time)
                
                // Calculate grid bounds and read brightness at instruction pointer position
                val gridX = (ipX.toInt() % width + width) % width
                val gridY = (ipY.toInt() % height + height) % height
                val currentChar = grid[gridY][gridX]
                val brightness = chars.indexOf(currentChar).coerceAtLeast(0)

                // Trajectory alteration based on brightness level
                ipAngle += (brightness - 4) * (PI / 7.0)
                val dx = cos(ipAngle)
                val dy = sin(ipAngle)

                // Execute opcode & determine audio frequency
                val freq = executeOpcode(currentChar, brightness)
                playSquareWave(freq, 35)

                // Render terminal frame with IP overlaid as 'O'
                val display = Array(height) { y -> grid[y].toCharArray() }
                display[gridY][gridX] = 'O'
                
                print("\u001B[H") // Reset cursor position to top-left
                println("=== ESONAVIGATOR === IP: ($gridX, $gridY) | Angle: ${"%.2f".format(ipAngle)} | Mem[$ptr]: ${memory[ptr]}")
                for (row in display) {
                    println(String(row))
                }

                // Advance Instruction Pointer
                ipX += dx * 1.4
                ipY += dy * 1.4
                
                Thread.sleep(40)
            }
        } finally {
            print("\u001B[?25h") // Restore cursor on exit
            audioLine.close()
        }
    }

    private fun generateJuliaFractal(t: Double): Array<String> {
        val cx = -0.7 + 0.1 * cos(t * 0.5)
        val cy = 0.27015 + 0.05 * sin(t * 0.7)
        
        return Array(height) { y ->
            CharArray(width) { x ->
                var zr = (x - width / 2.0) / (width / 3.2)
                var zi = (y - height / 2.0) / (height / 2.0)
                var iter = 0
                val maxIter = chars.length - 1
                
                while (zr * zr + zi * zi < 4.0 && iter < maxIter) {
                    val tmp = zr * zr - zi * zi + cx
                    zi = 2.0 * zr * zi + cy
                    zr = tmp
                    iter++
                }
                chars[iter]
            }.concatToString()
        }
    }

    private fun executeOpcode(ch: Char, brightness: Int): Double {
        when (ch) {
            '+' -> memory[ptr] = (memory[ptr] + 1) % 256
            '-' -> memory[ptr] = (memory[ptr] - 1 + 256) % 256
            '>' -> ptr = (ptr + 1) % memory.size
            '<' -> ptr = (ptr - 1 + memory.size) % memory.size
            else -> memory[ptr] = (memory[ptr] + brightness * 3) % 256
        }
        // Map current cell value & memory state to pentatonic musical scale pitch
        val pentatonicScale = intArrayOf(0, 2, 4, 7, 9)
        val octave = (memory[ptr] / 32) % 4 + 3
        val noteDegree = pentatonicScale[(memory[ptr] + brightness) % pentatonicScale.size]
        val midiNote = octave * 12 + noteDegree
        
        return 440.0 * 2.0.pow((midiNote - 69) / 12.0)
    }

    private fun playSquareWave(freq: Double, durationMs: Int) {
        val numSamples = (sampleRate * (durationMs / 1000.0)).toInt()
        val buffer = ByteArray(numSamples)
        val period = sampleRate / freq
        
        for (i in 0 until numSamples) {
            val phase = (i % period) / period
            // 8-bit signed square wave with 50% pulse width
            buffer[i] = if (phase < 0.5) 48.toByte() else (-48).toByte()
        }
        audioLine.write(buffer, 0, buffer.size)
    }
}

fun main() {
    FractalChiptuneInterpreter().run()
}