import kotlin.random.Random

// Simple 1‑dimensional cellular automaton (Elementary Cellular Automaton)
// Uses Rule 30 by default, but any 8‑bit rule can be supplied via command line.

fun main(args: Array<String>) {
    // Parameters: width of the line, number of generations, rule number (0‑255)
    val width = if (args.size > 0) args[0].toInt() else 79
    val generations = if (args.size > 1) args[1].toInt() else 40
    val ruleNumber = if (args.size > 2) args[2].toInt() else 30
    require(width > 0 && generations > 0 && ruleNumber in 0..255) {
        "Invalid arguments"
    }

    // Convert rule number to a map of neighbourhood (3 bits) -> new state (0/1)
    val ruleMap = IntArray(8) { i -> (ruleNumber shr i) and 1 }

    // Initialise first line with a single live cell in the centre
    var current = BooleanArray(width) { false }
    current[width / 2] = true

    // Helper to render a line
    fun render(cells: BooleanArray): String =
        cells.joinToString("") { if (it) "█" else " " }

    // Print initial state
    println(render(current))

    // Generate subsequent generations
    repeat(generations - 1) {
        val next = BooleanArray(width)
        for (i in 0 until width) {
            // neighbourhood: left, centre, right (wrap‑around)
            val left = current[(i - 1 + width) % width]
            val centre = current[i]
            val right = current[(i + 1) % width]
            // Build 3‑bit index: left is MSB, right is LSB
            val idx = (if (left) 4 else 0) + (if (centre) 2 else 0) + (if (right) 1 else 0)
            next[i] = ruleMap[idx] == 1
        }
        current = next
        println(render(current))
    }
}