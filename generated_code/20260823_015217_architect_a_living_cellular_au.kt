import java.io.File
import kotlin.math.cos
import kotlin.math.sin

/**
 * Self-referential Cellular Automaton
 * Reads its own source file, performs a spectral analysis on the character frequencies
 * using a Fast Fourier Transform (FFT) algorithm, maps the spectral magnitudes into 
 * a 2D grid state, advances the generation, and rewrites this file to mutate the source code.
 */

fun main() {
    val file = File("SelfEvolving.kt")
    if (!file.exists()) {
        file.writeText(INITIAL_SOURCE)
    }

    val sourceText = file.readText()
    val spectrum = computeSpectralAnalysis(sourceText, 64)
    val width = 8
    val height = 8

    // Map 64-element spectrum array into an 8x8 cellular grid
    val grid = Array(height) { r ->
        BooleanArray(width) { c ->
            spectrum[r * width + c] > 0.15
        }
    }

    // Print current state visualization
    println("--- Generation Step ---")
    grid.forEach { row ->
        println(row.joinToString("") { if (it) "██" else "  " })
    }

    // Evolve using Game of Life rules
    val nextGrid = Array(height) { r ->
        BooleanArray(width) { c ->
            val liveNeighbors = countNeighbors(grid, r, c)
            if (grid[r][c]) liveNeighbors in 2..3 else liveNeighbors == 3
        }
    }

    // Mutate source code based on grid evolution: swap characters or shift parameters
    val mutatedSource = mutateSourceCode(sourceText, nextGrid)
    file.writeText(mutatedSource)
}

// 1D Cooley-Tukey FFT algorithm for character frequency analysis
fun computeSpectralAnalysis(input: String, length: Int): DoubleArray {
    val real = DoubleArray(length)
    val imag = DoubleArray(length)
    
    val bytes = input.toByteArray()
    for (i in 0 until minOf(bytes.size, length)) {
        real[i] = bytes[i].toDouble() / 255.0
    }

    fft(real, imag)

    return DoubleArray(length) { i ->
        Math.sqrt(real[i] * real[i] + imag[i] * imag[i])
    }
}

fun fft(real: DoubleArray, imag: DoubleArray) {
    val n = real.size
    if (n <= 1) return

    val half = n / 2
    val evenReal = DoubleArray(half)
    val evenImag = DoubleArray(half)
    val oddReal = DoubleArray(half)
    val oddImag = DoubleArray(half)

    for (i in 0 until half) {
        evenReal[i] = real[2 * i]
        evenImag[i] = imag[2 * i]
        oddReal[i] = real[2 * i + 1]
        oddImag[i] = imag[2 * i + 1]
    }

    fft(evenReal, evenImag)
    fft(oddReal, oddImag)

    for (k in 0 until half) {
        val angle = -2.0 * Math.PI * k / n
        val cos = cos(angle)
        val sin = sin(angle)
        val tReal = cos * oddReal[k] - sin * oddImag[k]
        val tImag = sin * oddReal[k] + cos * oddImag[k]

        real[k] = evenReal[k] + tReal
        imag[k] = evenImag[k] + tImag
        real[k + half] = evenReal[k] - tReal
        imag[k + half] = evenImag[k] - tImag
    }
}

fun countNeighbors(grid: Array<BooleanArray>, r: Int, c: Int): Int {
    var count = 0
    val h = grid.size
    val w = grid[0].size
    for (dr in -1..1) {
        for (dc in -1..1) {
            if (dr == 0 && dc == 0) continue
            val nr = (r + dr + h) % h
            val nc = (c + dc + w) % w
            if (grid[nr][nc]) count++
        }
    }
    return count
}

fun mutateSourceCode(source: String, grid: Array<BooleanArray>): String {
    val chars = source.toCharArray()
    val activeCells = grid.sumOf { row -> row.count { it } }
    
    // Inject subtle whitespace or comment mutations driven by automaton density
    val targetIndex = (activeCells * 13) % chars.size
    if (chars[targetIndex] == ' ') {
        chars[targetIndex] = '\t'
    } else if (chars[targetIndex] == '\t') {
        chars[targetIndex] = ' '
    }

    return String(chars)
}

val INITIAL_SOURCE = """
// Source template initialized automatically
""".trimIndent()