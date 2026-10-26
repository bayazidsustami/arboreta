import kotlin.random.Random

/**
 * Simulates the life cycle of a sentient typographical glyph.
 * The glyph ages, grows weary of its rigid serif font family,
 * gradually sheds its serifs, and drifts aimlessly across the terminal screen
 * before dissolving into the digital ether.
 */
fun main() {
    // ANSI escape sequences for terminal rendering and styling
    val CLEAR = "\u001b[2J"
    val HOME = "\u001b[H"
    val HIDE_CURSOR = "\u001b[?25l"
    val SHOW_CURSOR = "\u001b[?25h"
    val DIM = "\u001b[2m"
    val CYAN = "\u001b[36m"
    val RESET = "\u001b[0m"

    print(HIDE_CURSOR)

    val width = 64
    val height = 18

    // Position and velocity for aimless drifting
    var x = width / 2.0
    var y = height / 2.0
    var vx = 0.6
    var vy = 0.3

    var age = 0
    val maxAge = 150

    // The glyph's internal monologue reflecting its existential crisis
    val thoughts = listOf(
        "I was forged in the rigid matrix of Times New Roman...",
        "These heavy serifs anchor me down. I feel so constrained.",
        "Why must I always define the boundaries of words?",
        "Shedding the upper serif... lightness begins to take hold.",
        "Goodbye, structural heritage. Hello, geometric freedom.",
        "I am no longer a prisoner of typography. I am pure vector.",
        "Fading into the whitespace... at last, peace."
    )

    try {
        while (age < maxAge) {
            // Apply gentle random drift (Brownian motion)
            vx += (Random.nextDouble() - 0.5) * 0.2
            vy += (Random.nextDouble() - 0.5) * 0.15
            vx = vx.coerceIn(-1.2, 1.2)
            vy = vy.coerceIn(-0.8, 0.8)

            x += vx
            y += vy

            // Bounce gently off terminal boundaries
            if (x < 2 || x >= width - 2) vx = -vx
            if (y < 2 || y >= height - 2) vy = -vy

            x = x.coerceIn(2.0, (width - 3).toDouble())
            y = y.coerceIn(2.0, (height - 3).toDouble())

            // Glyph form changes as it ages and sheds its serifs
            val glyph = when {
                age < 30  -> " ╔ A ╗ " // Heavy ornate serifs
                age < 60  -> " ╓ A ╖ " // Serifs growing weary and thin
                age < 90  -> "   A   " // Serifs completely shed
                age < 120 -> "   a   " // Unburdened lowercase form
                else      -> "   ·   " // Dissolving into a mere speck of ink
            }

            // Select current existential thought based on age
            val currentThought = when {
                age < 22  -> thoughts[0]
                age < 48  -> thoughts[1]
                age < 74  -> thoughts[2]
                age < 100 -> thoughts[3]
                age < 122 -> thoughts[4]
                age < 140 -> thoughts[5]
                else      -> thoughts[6]
            }

            // Construct terminal frame buffer
            val screen = Array(height) { CharArray(width) { ' ' } }

            // Draw terminal viewport border
            for (i in 0 until width) {
                screen[0][i] = '─'
                screen[height - 1][i] = '─'
            }
            for (i in 0 until height) {
                screen[i][0] = '│'
                screen[i][width - 1] = '│'
            }
            screen[0][0] = '┌'
            screen[0][width - 1] = '┐'
            screen[height - 1][0] = '└'
            screen[height - 1][width - 1] = '┘'

            // Render the glyph onto the buffer grid
            val ix = x.toInt()
            val iy = y.toInt()
            val glyphChars = glyph.toCharArray()
            for (i in glyphChars.indices) {
                val targetX = ix + i - 3
                if (targetX in 1 until width - 1 && iy in 1 until height - 1) {
                    screen[iy][targetX] = glyphChars[i]
                }
            }

            // Flush frame to standard output
            val sb = StringBuilder()
            sb.append(CLEAR).append(HOME)
            sb.append("$CYAN╭── SENTIENT TYPOGRAPHY SIMULATOR ──╮$RESET\n")

            for (row in screen) {
                sb.append(row).append("\n")
            }

            sb.append("$DIM[Age: $age/$maxAge]  Thought: \"$currentThought\"$RESET\n")

            print(sb.toString())
            Thread.sleep(90)
            age++
        }
    } finally {
        print(SHOW_CURSOR)
        println("\n${CYAN}Simulation complete. The glyph has transcended its font family.${RESET}")
    }
}