import java.awt.Color
import java.awt.image.BufferedImage
import java.io.File
import javax.imageio.ImageIO
import kotlin.math.abs

/**
 * PaletteToPoem.kt
 * Translates an image's color palette into an evocative poem, 
 * rendered as an animated ASCII book folding itself in the terminal.
 */

// --- Color & Mood Analysis ---
data class HSL(val hue: Float, val saturation: Float, val lightness: Float)

fun Color.toHSL(): HSL {
    val r = red / 255f
    val g = green / 255f
    val b = blue / 255f
    val max = maxOf(r, g, b)
    val min = minOf(r, g, b)
    val delta = max - min
    
    val l = (max + min) / 2f
    var s = 0f
    var h = 0f

    if (delta != 0f) {
        s = if (l > 0.5f) delta / (2f - max - min) else delta / (max + min)
        h = when (max) {
            r -> (g - b) / delta + (if (g < b) 6f else 0f)
            g -> (b - r) / delta + 2f
            else -> (r - g) / delta + 4f
        } / 6f
    }
    return HSL(h * 360f, s, l)
}

fun extractPalette(image: BufferedImage, sampleSize: Int = 100): List<Color> {
    val colors = mutableListOf<Color>()
    val stepX = (image.width / sampleSize).coerceAtLeast(1)
    val stepY = (image.height / sampleSize).coerceAtLeast(1)

    for (x in 0 until image.width step stepX) {
        for (y in 0 until image.height step stepY) {
            colors.add(Color(image.getRGB(x, y)))
        }
    }
    return colors
}

// --- Poem Generation Engine ---
val imagery = mapOf(
    "crimson" to listOf("burning embers", "scarlet silk", "a dying star", "crimson rust"),
    "gold"    to listOf("sunlit dusk", "amber resin", "gilded shadows", "golden wheat"),
    "emerald" to listOf("deep moss", "ancient foliage", "emerald mist", "verdant canopy"),
    "azure"   to listOf("abyssal waves", "frozen ether", "indigo sky", "sapphire frost"),
    "violet"  to listOf("twilight haze", "velvet gloom", "amethyst pulse", "shadowed orchids"),
    "shadow"  to listOf("silent voids", "obsidian dust", "fading whispers", "nocturnal chill"),
    "lunar"   to listOf("pale moonlight", "bleached bones", "silver smoke", "alabaster snow")
)

val verbs = listOf("weaves through", "drifts into", "yields unto", "embraces", "fades inside", "awakens")

fun colorToCategory(color: Color): String {
    val hsl = color.toHSL()
    if (hsl.lightness < 0.2f) return "shadow"
    if (hsl.lightness > 0.8f) return "lunar"
    if (hsl.saturation < 0.15f) return if (hsl.lightness > 0.5f) "lunar" else "shadow"

    return when (hsl.hue) {
        in 0f..25f, in 330f..360f -> "crimson"
        in 26f..70f -> "gold"
        in 71f..165f -> "emerald"
        in 166f..260f -> "azure"
        else -> "violet"
    }
}

fun generatePoem(palette: List<Color>): List<String> {
    val categories = palette.map { colorToCategory(it) }
    val dominant = categories.groupBy { it }.maxByOrNull { it.value.size }?.key ?: "shadow"
    val secondary = categories.distinct().getOrElse(1) { dominant }

    val line1 = "Where " + (imagery[dominant]?.random() ?: "shadows") + " " + verbs.random()
    val line2 = "  the " + (imagery[secondary]?.random() ?: "silence") + ","
    val line3 = "Time slows to a soft fade,"
    val line4 = "  leaving only resonance."

    return listOf(line1, line2, line3, line4)
}

// --- ASCII Book Folding Renderer ---
fun renderAnimatedBook(poem: List<String>) {
    val width = 26
    val height = 8

    // Folding progression frames (percentage from open 1.0 to fully closed 0.0)
    val foldStages = listOf(1.0, 0.8, 0.5, 0.25, 0.05, 0.0)

    print("\u001B[2J\u001B[H") // Clear terminal

    for (stage in foldStages) {
        val pageSpan = (width * stage).toInt().coerceAtLeast(1)
        val leftPadding = " ".repeat((width - pageSpan) + 2)

        val frame = StringBuilder()
        frame.append("\u001B[H") // Move cursor to top-left
        frame.append("\n  === THE COLOR SPECTRUM READS ===\n\n")

        // Top Border
        frame.append(leftPadding).append("┌").append("─".repeat(pageSpan)).append("┬").append("─".repeat(pageSpan)).append("┐\n")

        for (i in 0 until height) {
            val lineText = if (i in 1..4) poem[i - 1] else ""
            val leftContent = if (lineText.length > pageSpan) lineText.substring(0, pageSpan) else lineText.padEnd(pageSpan)
            
            // Mirror back-cover effect on fold
            val rightContent = " ".repeat(pageSpan)

            frame.append(leftPadding)
                .append("│")
                .append(leftContent)
                .append("│")
                .append(rightContent)
                .append("│\n")
        }

        // Bottom Border
        frame.append(leftPadding).append("└").append("─".repeat(pageSpan)).append("┴").append("─".repeat(pageSpan)).append("┘\n")
        
        if (stage > 0.0) {
            frame.append("\n    [ The book folds itself away... ]\n")
        } else {
            frame.append("\n    [ Closed. ]                    \n")
        }

        print(frame.toString())
        Thread.sleep(350)
    }
}

// --- Synthetic Image Generator for Standalone Execution ---
fun createSampleImage(): BufferedImage {
    val img = BufferedImage(100, 100, BufferedImage.TYPE_INT_RGB)
    val g = img.createGraphics()
    g.color = Color(34, 112, 147) // Deep Azure
    g.fillRect(0, 0, 50, 100)
    g.color = Color(230, 175, 46)  // Gold
    g.fillRect(50, 0, 50, 100)
    g.dispose()
    return img
}

fun main(args: Array<String>) {
    val image: BufferedImage = if (args.isNotEmpty() && File(args[0]).exists()) {
        ImageIO.read(File(args[0]))
    } else {
        createSampleImage()
    }

    val palette = extractPalette(image)
    val poem = generatePoem(palette)
    renderAnimatedBook(poem)
}