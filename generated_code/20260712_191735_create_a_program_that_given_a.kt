import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.Random

// Simple sentiment: +1 for each "good"/"happy", -1 for each "bad"/"sad"
fun sentimentScore(text: String): Int {
    val pos = listOf("good", "happy", "joy", "love", "great")
    val neg = listOf("bad", "sad", "pain", "hate", "terrible")
    var score = 0
    val words = text.lowercase().split(Regex("\\W+"))
    for (w in words) {
        if (w in pos) score++
        if (w in neg) score--
    }
    return score
}

// Generate a tiny poem in Shakespearean style
fun generatePoem(text: String, score: Int): String {
    val mood = when {
        score > 2 -> "joyful"
        score < -2 -> "melancholy"
        else -> "neutral"
    }
    return """
        |To $mood thoughts I speak,
        |From words that rise and leak.
        |The text, "${text.replace("\n", " ")}",
        |Doth paint a scene unique.
    """.trimMargin()
}

// Build a tiny Befunge-93 program that prints a static heat‑map frame
fun buildBefunge(text: String, score: Int): String {
    // Create a simple heat map: higher score → more '+' chars
    val width = 40
    val height = 10
    val intensity = ((score + 5).coerceIn(0, 10)) // 0..10
    val rows = mutableListOf<String>()
    for (y in 0 until height) {
        val line = StringBuilder()
        for (x in 0 until width) {
            line.append(if (y < intensity) '+' else '-')
        }
        rows.add(line.toString())
    }
    // Befunge program: push each row, print with newline
    val sb = StringBuilder()
    sb.append("0") // start at (0,0)
    var x = 0
    var y = 0
    for (row in rows) {
        for (ch in row) {
            sb.append(ch)
            sb.append('0') // push char
            sb.append('.')
        }
        sb.append('0') // push newline
        sb.append('@') // end of program (will be overwritten later)
        // move to next line in 2D space (simple linear layout)
        sb.append('>') // move right
    }
    // replace last '@' with actual termination
    sb.setCharAt(sb.length - 1, '@')
    return sb.toString()
}

fun main() {
    val reader = BufferedReader(InputStreamReader(System.`in`))
    val input = reader.readText().trim()
    if (input.isEmpty()) {
        println("No input text provided.")
        return
    }

    val score = sentimentScore(input)
    val poem = generatePoem(input, score)
    val befunge = buildBefunge(input, score)

    println("=== Generated Poem ===")
    println(poem)
    println("\n=== Befunge-93 Program ===")
    println(befunge)
    println("\nRun it with: echo \"$befunge\" | bef -r")
}