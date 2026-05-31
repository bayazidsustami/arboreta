import java.awt.Image
import java.awt.image.BufferedImage
import java.io.File
import java.util.Base64
import javax.imageio.ImageIO
import kotlin.math.roundToInt

// Simple list of words grouped by syllable count (1-5 syllables)
val wordsBySyllable = mapOf(
    1 to listOf("sky", "dream", "hope", "light", "star"),
    2 to listOf("river", "mountain", "silence", "whisper", "crystal"),
    3 to listOf("harmony", "eternity", "illusion", "melody", "cascade"),
    4 to listOf("illumination", "tranquility", "reflection", "magnificence", "serenity"),
    5 to listOf("intercommunication", "incomprehensible", "transcendentalism", "uncharacteristically", "hypermetropia")
)

// Mapping of intensity (0‑255) to a combining diacritic
val diacritics = arrayOf(
    '\u0300', // grave
    '\u0301', // acute
    '\u0302', // circumflex
    '\u0303', // tilde
    '\u0304', // macron
    '\u0305', // overline
    '\u0306', // breve
    '\u0307', // dot above
    '\u0308', // diaeresis
    '\u0309', // hook above
    '\u030A', // ring above
    '\u030B', // double acute
    '\u030C', // caron
    '\u030D', // vertical line above
    '\u030E', // double vertical line above
    '\u030F'  // double grave
)

// Convert a pixel intensity to a diacritic (more intense → higher‑index diacritic)
fun intensityToDiacritic(value: Int): Char {
    val idx = (value / 256.0 * diacritics.size).toInt().coerceIn(0, diacritics.lastIndex)
    return diacritics[idx]
}

// Encode a byte as a word whose syllable count equals the byte % 5 + 1, then offset by the high nibble
fun encodeByte(b: Int): String {
    val low = (b and 0x0F) % 5 + 1
    val high = ((b shr 4) and 0x0F) % 5 + 1
    val lowWord = wordsBySyllable[low]!!.random()
    val highWord = wordsBySyllable[high]!!.random()
    return "$highWord $lowWord"
}

// Decode a pair of words back to a byte
fun decodeWords(pair: List<String>): Int {
    val high = wordsBySyllable.entries.first { it.value.contains(pair[0]) }.key - 1
    val low = wordsBySyllable.entries.first { it.value.contains(pair[1]) }.key - 1
    return (high shl 4) or low
}

// Resize image preserving aspect ratio; height is computed to keep characters roughly square
fun resize(img: BufferedImage, targetWidth: Int): BufferedImage {
    val aspect = img.width.toDouble() / img.height
    val targetHeight = (targetWidth / aspect).roundToInt()
    val scaled = img.getScaledInstance(targetWidth, targetHeight, Image.SCALE_SMOOTH)
    val out = BufferedImage(targetWidth, targetHeight, BufferedImage.TYPE_INT_RGB)
    val g = out.createGraphics()
    g.drawImage(scaled, 0, 0, null)
    g.dispose()
    return out
}

// Convert image to a poem where each line visually recreates the row using combining characters.
// After each visual line, append a short “coding” segment that encodes the raw bytes of that row.
fun imageToPoem(img: BufferedImage): String {
    val sb = StringBuilder()
    for (y in 0 until img.height) {
        val visual = StringBuilder()
        val coding = StringBuilder()
        for (x in 0 until img.width) {
            val rgb = img.getRGB(x, y)
            val r = (rgb shr 16) and 0xFF
            val g = (rgb shr 8) and 0xFF
            val b = rgb and 0xFF
            // Simple luminance
            val lum = (0.299 * r + 0.587 * g + 0.114 * b).roundToInt()
            visual.append(' ') // base space
            visual.append(intensityToDiacritic(lum))
            // Encode the three channel bytes as three words (space‑separated)
            coding.append(encodeByte(r)).append(' ')
            coding.append(encodeByte(g)).append(' ')
            coding.append(encodeByte(b)).append(' ')
        }
        sb.append(visual).append(' ') // separate visual from code
        sb.append(coding.toString().trim()).append('\n')
    }
    return sb.toString()
}

// Decode poem back to image (optional demonstration)
fun poemToImage(poem: String, width: Int): BufferedImage {
    val lines = poem.lines().filter { it.isNotBlank() }
    val height = lines.size
    val img = BufferedImage(width, height, BufferedImage.TYPE_INT_RGB)
    for (y in lines.indices) {
        val parts = lines[y].split(' ').filter { it.isNotEmpty() }
        // first part sequence length = width (each char + diacritic), ignore visual.
        val codeStart = width * 2 // space + diacritic per pixel
        val codeWords = parts.subList(codeStart, parts.size)
        var ix = 0
        for (i in 0 until width) {
            val r = decodeWords(listOf(codeWords[ix * 3], codeWords[ix * 3 + 1]))
            val g = decodeWords(listOf(codeWords[ix * 3 + 2], codeWords[ix * 3 + 3]))
            val b = decodeWords(listOf(codeWords[ix * 3 + 4], codeWords[ix * 3 + 5]))
            val color = (r shl 16) or (g shl 8) or b
            img.setRGB(i, y, color)
            ix++
        }
    }
    return img
}

// Entry point: expects an image path, outputs poem to stdout
fun main(args: Array<String>) {
    if (args.isEmpty()) {
        System.err.println("Usage: kotlin ImagePoem.kt <image-path>")
        return
    }
    val input = File(args[0])
    if (!input.exists()) {
        System.err.println("File not found: ${args[0]}")
        return
    }
    val raw = ImageIO.read(input)
    val resized = resize(raw, 80) // fixed width for readability
    val poem = imageToPoem(resized)
    println(poem)
    // Optional: write reconstructed image for verification
    // val recon = poemToImage(poem, resized.width)
    // ImageIO.write(recon, "png", File("reconstructed.png"))
}