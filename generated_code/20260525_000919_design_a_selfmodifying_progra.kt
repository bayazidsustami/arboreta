import java.io.File
import java.util.Random

// ------------------------------------------------------------
// Self-modifying Kotlin script
// It reads its own source, extracts the drawing block,
// generates a new colorful Unicode picture, replaces the block,
// and writes the updated source back to disk.
// ------------------------------------------------------------

val sourceFile = File(object {}.javaClass.protectionDomain.codeSource.location.toURI())
val lines = sourceFile.readLines()

// markers that delimit the generated drawing
val startMarker = "// BEGIN DRAW"
val endMarker = "// END DRAW"

fun generateMandelbrotLines(): List<String> {
    // tiny ASCII Mandelbrot, size 8x8, used only to derive N
    val w = 8; val h = 8
    val maxIter = 20
    return List(h) { y ->
        val imag = (y - h / 2) * 4.0 / h
        StringBuilder().apply {
            for (x in 0 until w) {
                val real = (x - w / 2) * 4.0 / w
                var zr = 0.0; var zi = 0.0
                var i = 0
                while (zr * zr + zi * zi <= 4.0 && i < maxIter) {
                    val tmp = zr * zr - zi * zi + real
                    zi = 2 * zr * zi + imag
                    zr = tmp
                    i++
                }
                append(if (i == maxIter) '@' else ' ')
            }
        }.toString()
    }
}

// N = number of lines in the tiny Mandelbrot picture
val N = generateMandelbrotLines().size

fun randomUnicodeGlyph(rand: Random): String {
    // pick a printable Unicode character in a pleasant range
    val ranges = listOf(0x263A..0x2654, 0x2660..0x269C, 0x1F300..0x1F320)
    val range = ranges[rand.nextInt(ranges.size)]
    val code = range.start + rand.nextInt(range.endInclusive - range.start + 1)
    return String(Character.toChars(code))
}

fun ansiColor(code: Int) = "\u001B[38;5;${code}m"
val reset = "\u001B[0m"

fun generateDrawing(): List<String> {
    val rand = Random()
    return List(N) {
        val lineLen = 20 + rand.nextInt(10)
        buildString {
            repeat(lineLen) {
                val color = 16 + rand.nextInt(216) // 256‑color palette
                append(ansiColor(color))
                append(randomUnicodeGlyph(rand))
            }
            append(reset)
        }
    }
}

// extract parts before, inside, after the drawing block
val startIdx = lines.indexOfFirst { it.trim() == startMarker }
val endIdx = lines.indexOfFirst { it.trim() == endMarker }

if (startIdx == -1 || endIdx == -1 || endIdx <= startIdx) {
    println("Markers not found in source.")
    return
}

val before = lines.subList(0, startIdx + 1)          // include start marker
val after = lines.subList(endIdx, lines.size)       // include end marker

val newDrawing = generateDrawing()

// compose new source
val newSource = (before + newDrawing + after).joinToString("\n")

// write back (overwrites the script file)
sourceFile.writeText(newSource)

// Also output the drawing for this run
println(newDrawing.joinToString("\n"))