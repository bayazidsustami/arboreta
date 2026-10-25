import javax.sound.sampled.*
import kotlin.math.*
import kotlin.random.Random

/**
 * An ambient audio-reactive cellular automaton that weaves dying cells into
 * typographic echoes of forgotten poetry.
 */
class PoeticCA(val width: Int = 80, val height: Int = 24) {
    
    private class Cell(
        var isAlive: Boolean = false,
        var char: Char = ' ',
        var age: Int = 0
    )

    private var grid = Array(height) { Array(width) { Cell() } }
    private val poetryCorpus = listOf(
        "forgotten stars", "silent tides", "whispers in ash", 
        "time fades", "ghosts of light", "dust and memory", "unwritten"
    )
    private var corpusIndex = 0
    private var charPointer = 0

    fun update(audioEnergy: Float, frequencyMod: Float) {
        // 1. Inject life based on live audio frequencies/energy
        if (audioEnergy > 0.05f) {
            val sparkCount = (audioEnergy * 20).toInt().coerceIn(1, 15)
            for (i in 0 until sparkCount) {
                val rx = Random.nextInt(width)
                val ry = Random.nextInt(height)
                grid[ry][rx].isAlive = true
            }
        }

        // 2. Compute next generation (Conway's Game of Life with audio mutation)
        val nextGrid = Array(height) { r -> Array(width) { c -> Cell() } }
        val currentPoetryWord = poetryCorpus[corpusIndex]

        for (r in 0 until height) {
            for (c in 0 until width) {
                val cell = grid[r][c]
                val neighbors = countAliveNeighbors(r, c)
                
                // Mutation chance influenced by frequency modulation
                val survivalChance = if (frequencyMod > 0.7f) Random.nextFloat() > 0.1f else true

                if (cell.isAlive) {
                    if ((neighbors == 2 || neighbors == 3) && survivalChance) {
                        nextGrid[r][c] = Cell(isAlive = true, char = '█', age = 0)
                    } else {
                        // Cell dies: leave behind a typographic echo from forgotten poetry
                        val echoChar = currentPoetryWord[charPointer % currentPoetryWord.length]
                        charPointer++
                        if (charPointer >= currentPoetryWord.length) {
                            charPointer = 0
                            corpusIndex = (corpusIndex + 1) % poetryCorpus.size
                        }
                        nextGrid[r][c] = Cell(isAlive = false, char = echoChar, age = 15)
                    }
                } else {
                    if (neighbors == 3) {
                        nextGrid[r][c] = Cell(isAlive = true, char = '█', age = 0)
                    } else {
                        // Fade existing typographic echoes
                        if (cell.age > 0) {
                            val fadedAge = cell.age - 1
                            val fadedChar = if (fadedAge < 5) '.' else cell.char
                            nextGrid[r][c] = Cell(isAlive = false, char = fadedChar, age = fadedAge)
                        } else {
                            nextGrid[r][c] = Cell(isAlive = false, char = ' ', age = 0)
                        }
                    }
                }
            }
        }
        grid = nextGrid
    }

    private fun countAliveNeighbors(row: Int, col: Int): Int {
        var count = 0
        for (r in -1..1) {
            for (c in -1..1) {
                if (r == 0 && c == 0) continue
                val nr = (row + r + height) % height
                val nc = (col + c + width) % width
                if (grid[nr][nc].isAlive) count++
            }
        }
        return count
    }

    fun render(): String {
        val sb = StringBuilder()
        sb.append("\u001b[H") // ANSI home cursor
        sb.append("=== AUDIO CELLULAR AUTOMATON: TYPOGRAPHIC ECHOES ===\n")
        for (r in 0 until height) {
            for (c in 0 until width) {
                sb.append(grid[r][c].char)
            }
            sb.append("\n")
        }
        return sb.toString()
    }
}

fun main() {
    val ca = PoeticCA(80, 22)
    print("\u001b[2J") // Clear screen

    // Attempt to capture microphone input for real-time ambient frequencies
    var targetLine: TargetDataLine? = null
    try {
        val format = AudioFormat(44100f, 16, 1, true, true)
        val info = DataLine.Info(TargetDataLine::class.java, format)
        if (AudioSystem.isLineSupported(info)) {
            targetLine = AudioSystem.getLine(info) as TargetDataLine
            targetLine.open(format)
            targetLine.start()
        }
    } catch (e: Exception) {
        // Fallback if microphone is unavailable (simulates ambient audio waves)
    }

    val buffer = ByteArray(512)
    var step = 0

    println("Initializing audio listener & automaton... Press Ctrl+C to exit.")
    Thread.sleep(1000)

    try {
        while (true) {
            var energy = 0f
            var freqMod = 0.5f

            if (targetLine != null && targetLine.isOpen) {
                val bytesRead = targetLine.read(buffer, 0, buffer.size)
                if (bytesRead > 0) {
                    var sum = 0.0
                    for (i in 0 until bytesRead step 2) {
                        val sample = ((buffer[i].toInt() shl 8) or (buffer[i + 1].toInt() and 0xFF)).toShort()
                        sum += (sample * sample).toDouble()
                    }
                    val rms = sqrt(sum / (bytesRead / 2))
                    energy = (rms / 32768.0).toFloat().coerceIn(0f, 1f)
                    freqMod = abs(sin(step * 0.1)) .toFloat()
                }
            } else {
                // Procedural fallback simulator if no mic is present
                step++
                energy = (abs(sin(step * 0.2)) * 0.3 + Random.nextFloat() * 0.1).toFloat()
                freqMod = Random.nextFloat()
            }

            ca.update(energy, freqMod)
            print(ca.render())
            Thread.sleep(120)
        }
    } finally {
        targetLine?.close()
    }
}