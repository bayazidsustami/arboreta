import java.io.File
import kotlin.random.Random

// 1. Read its own bytecode / source binary or falling back to current class bytes
val classBytes: ByteArray = runCatching {
    val className = "SolutionKt"
    object {}.javaClass.classLoader.getResourceAsStream("$className.class")?.readBytes()
}!!.getOrElse {
    File(object {}.javaClass.protectionDomain.codeSource.location.path).readBytes()
}

// Concrete poetry text: source code snippets to gradually reconstruct
val sourcePoetry = listOf(
    "  01000100  01000001  01010100  01000001  ",
    " val bytes = classBytes.map { it.toInt() } ",
    "   cell = (left xor center xor right)      ",
    "  while (true) { render(binary, poem) }    ",
    "   01000011  01001111  01000100  01000101  "
)

val width = 60
val height = 20
val glyphs = charArrayOf(' ', '.', ':', '-', '=', '+', '*', '#', '%', '@', '█', '▓', '▒', '░')

var caGrid = IntArray(width) { Random.nextInt(0, 2) }
val binarySample = classBytes.take(width).map { Math.abs(it.toInt()) % glyphs.size }

fun main() {
    print("\u001B[2J\u001B[H") // Clear screen
    var step = 0

    while (step < 100) {
        // Shift cursor to top-left for smooth animation
        print("\u001B[H")
        
        // 2. Evolve Cellular Automaton Rule based on binary byte patterns
        val byteInfluence = binarySample[step % binarySample.size]
        val nextGrid = IntArray(width)
        for (i in 0 until width) {
            val left = caGrid[(i - 1 + width) % width]
            val center = caGrid[i]
            val right = caGrid[(i + 1) % width]
            // Self-modifying Wolfram Rule influenced by executable bytes
            val rule = (byteInfluence xor (left shl 2) xor (center shl 1) xor right) % 256
            nextGrid[i] = (rule shr (left * 4 + center * 2 + right)) and 1
        }
        caGrid = nextGrid

        // 3. Render Visual Concrete Poetry merged with Cellular Automaton
        val frame = StringBuilder()
        frame.append("╔" + "═".repeat(width) + "╗\n")

        val poetryLineIdx = (step / 5) % sourcePoetry.size
        val currentPoem = sourcePoetry[poetryLineIdx]

        for (y in 0 until height) {
            frame.append("║")
            for (x in 0 until width) {
                val poemChar = if (y == height / 2 && x < currentPoem.length) currentPoem[x] else ' '
                if (poemChar != ' ' && step > 10) {
                    frame.append(poemChar)
                } else {
                    val caState = caGrid[x]
                    val byteVal = binarySample[(x + y + step) % binarySample.size]
                    val glyphIndex = (caState * 7 + byteVal + step) % glyphs.size
                    frame.append(glyphs[glyphIndex])
                }
            }
            frame.append("║\n")
        }
        frame.append("╚" + "═".repeat(width) + "╝\n")
        frame.append("Binary byte stream: ${binarySample.take(12).joinToString(" ")}...\n")

        print(frame.toString())
        Thread.sleep(120)
        step++
    }
}

main()