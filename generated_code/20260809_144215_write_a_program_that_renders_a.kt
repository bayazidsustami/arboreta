import java.awt.*
import javax.swing.*
import kotlin.math.*

// Live-updating fractal tree generated from bytecode analysis
fun main() {
    // Load compiled class bytes of current context to build byte frequency distribution
    val clazz = object {}.javaClass.enclosingClass ?: object {}.javaClass
    val classResource = clazz.name.replace('.', '/') + ".class"
    val bytes = clazz.classLoader?.getResourceAsStream(classResource)?.readBytes()
        ?: clazz.getResourceAsStream("/$classResource")?.readBytes()
        ?: ByteArray(256) { it.toByte() }

    // Compute frequency array (0..255) normalized between 0.0 and 1.0
    val freq = IntArray(256)
    bytes.forEach { freq[it.toInt() and 0xFF]++ }
    val maxFreq = maxOf(1, freq.maxOrNull() ?: 1)
    val normFreq = DoubleArray(256) { freq[it].toDouble() / maxFreq }

    // Swing UI setup
    SwingUtilities.invokeLater {
        val frame = JFrame("Bytecode Frequency Fractal Tree")
        frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
        frame.setSize(900, 750)
        frame.setLocationRelativeTo(null)

        var animationTime = 0.0

        val panel = object : JPanel() {
            init {
                background = Color(10, 12, 20)
            }

            override fun paintComponent(g: Graphics) {
                super.paintComponent(g)
                val g2d = g as Graphics2D
                g2d.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

                // Draw fractal starting from bottom-center
                val rootX = width / 2.0
                val rootY = height - 50.0
                renderBranch(g2d, rootX, rootY, 130.0, -Math.PI / 2, 0, normFreq, animationTime)
            }

            // Recursive branch rendering dynamically driven by bytecode byte frequencies
            private fun renderBranch(
                g2d: Graphics2D,
                x: Double,
                y: Double,
                length: Double,
                angle: Double,
                depth: Int,
                freqs: DoubleArray,
                t: Double
            ) {
                if (depth > 8 || length < 2.0) return

                // Select byte frequency buckets based on recursion depth & time animation
                val byteIndex1 = (depth * 31 + (t * 5).toInt()) % 256
                val byteIndex2 = (depth * 47 + 19 + (t * 3).toInt()) % 256
                val val1 = freqs[byteIndex1]
                val val2 = freqs[byteIndex2]

                // Dynamic angular spread and length reduction dictated by source bytecode values
                val spread = Math.toRadians(18.0 + val1 * 35.0 + sin(t + depth) * 4.0)
                val decay = 0.67 + val2 * 0.12 + cos(t * 0.8 + depth) * 0.02

                val endX = x + length * cos(angle)
                val endY = y + length * sin(angle)

                // HSB Color dynamic modulation based on bytecode spectrum
                val hue = ((depth * 0.09 + val1 * 0.4 + t * 0.02) % 1.0).toFloat()
                val sat = (0.6f + val2.toFloat() * 0.4f).coerceIn(0.2f, 1.0f)
                val brightness = (0.95f - depth * 0.08f).coerceIn(0.3f, 1.0f)

                g2d.color = Color.getHSBColor(hue, sat, brightness)
                g2d.stroke = BasicStroke(maxOf(1f, (9f - depth * 0.95f)))
                g2d.drawLine(x.toInt(), y.toInt(), endX.toInt(), endY.toInt())

                // Spawn split sub-branches with byte-influenced parameters
                renderBranch(g2d, endX, endY, length * decay, angle - spread, depth + 1, freqs, t)
                renderBranch(g2d, endX, endY, length * decay, angle + spread, depth + 1, freqs, t)
            }
        }

        frame.add(panel)
        frame.isVisible = true

        // Timer drives live animation loop updating the tree frame by frame
        Timer(25) {
            animationTime += 0.025
            panel.repaint()
        }.start()
    }
}