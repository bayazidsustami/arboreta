import java.awt.Color
import java.awt.Graphics2D
import java.awt.image.BufferedImage
import java.io.File
import kotlin.math.cos
import kotlin.math.sin

fun main() {
    // ---- 1. locate own source file (assumes script is named SelfMod.kt) ----
    val sourceFile = File("SelfMod.kt")
    if (!sourceFile.exists()) return

    // ---- 2. read bytes and convert to bit list ----
    val bytes = sourceFile.readBytes()
    val bits = mutableListOf<Int>()
    for (b in bytes) {
        for (i in 7 downTo 0) bits.add((b.toInt() shr i) and 1)
    }

    // ---- 3. simple turtle graphics driven by bits ----
    val size = 800
    val img = BufferedImage(size, size, BufferedImage.TYPE_INT_RGB)
    val g = img.createGraphics()
    g.color = Color.WHITE
    g.fillRect(0, 0, size, size)
    g.color = Color.BLACK

    var x = size / 2.0
    var y = size / 2.0
    var angle = -90.0 // up
    val step = 5.0

    for (bit in bits) {
        // move forward
        val nx = x + step * cos(Math.toRadians(angle))
        val ny = y + step * sin(Math.toRadians(angle))
        g.drawLine(x.toInt(), y.toInt(), nx.toInt(), ny.toInt())
        x = nx; y = ny
        // turn: 0 -> left 90°, 1 -> right 90°
        angle += if (bit == 0) -90 else 90
    }
    g.dispose()
    // save artwork
    ImageIO.write(img, "png", File("fractal.png"))

    // ---- 4. swap each adjacent pair of bits ----
    val swappedBits = bits.toMutableList()
    var i = 0
    while (i + 1 < swappedBits.size) {
        val tmp = swappedBits[i]
        swappedBits[i] = swappedBits[i + 1]
        swappedBits[i + 1] = tmp
        i += 2
    }

    // ---- 5. pack bits back into bytes and overwrite source ----
    val newBytes = ByteArray((swappedBits.size + 7) / 8)
    for (idx in swappedBits.indices) {
        val byteIdx = idx / 8
        val bitPos = 7 - (idx % 8)
        newBytes[byteIdx] = (newBytes[byteIdx].toInt() or (swappedBits[idx] shl bitPos)).toByte()
    }
    sourceFile.writeBytes(newBytes)
}