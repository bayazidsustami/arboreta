import java.awt.*
import java.awt.geom.Path2D
import java.awt.image.BufferedImage
import javax.swing.*
import kotlin.concurrent.thread
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

// Represents an allocated chunk of heap memory
data class MemoryChunk(val id: Int, val address: Int, val size: Int, val color: Color)

// Digital Canvas Visualizer acting as a Heap Memory Manager & Garbage Collector
class DigitalCanvasGC(val canvasWidth: Int = 1000, val canvasHeight: Int = 750) : JPanel() {
    private val canvasImage = BufferedImage(canvasWidth, canvasHeight, BufferedImage.TYPE_INT_ARGB)
    private val heap = mutableMapOf<Int, MemoryChunk>()
    private val rootSet = mutableSetOf<Int>()
    private var heapPointer = 0
    private var objectCounter = 0

    init {
        preferredSize = Dimension(canvasWidth, canvasHeight)
        val g = canvasImage.createGraphics()
        g.color = Color(12, 14, 22) // Dark atmospheric gallery backdrop
        g.fillRect(0, 0, canvasWidth, canvasHeight)
        g.dispose()
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        g.drawImage(canvasImage, 0, 0, null)
    }

    // Allocates memory and renders a vibrant brushstroke on the canvas
    @Synchronized
    fun allocate(size: Int): Int {
        val address = heapPointer
        heapPointer = (heapPointer + size * 137) % (canvasWidth * canvasHeight)

        // Generate vibrant colors mapped to allocation
        val hue = Random.nextFloat()
        val baseColor = Color.getHSBColor(hue, 0.85f, 0.95f)
        val strokeColor = Color(baseColor.red, baseColor.green, baseColor.blue, 180)

        val chunk = MemoryChunk(objectCounter++, address, size, strokeColor)
        heap[address] = chunk
        rootSet.add(address)

        paintBrushstroke(chunk)
        repaint()
        return address
    }

    // Unmarks an address from root set, preparing it for garbage collection
    @Synchronized
    fun release(address: Int) {
        rootSet.remove(address)
    }

    // Custom Garbage Collector: sweeps unreachable memory and applies water washes
    @Synchronized
    fun sweepAndCollect() {
        val unreachable = heap.keys.filter { it !in rootSet }
        for (address in unreachable) {
            val chunk = heap.remove(address)
            if (chunk != null) {
                paintWaterWash(chunk)
            }
        }
        repaint()
    }

    // Renders dynamic, expressive brushstrokes for allocations
    private fun paintBrushstroke(chunk: MemoryChunk) {
        val g = canvasImage.createGraphics()
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        val startX = (chunk.address % canvasWidth).toDouble()
        val startY = ((chunk.address / canvasWidth) % canvasHeight).toDouble()
        val length = (chunk.size * 2.5).coerceIn(20.0, 180.0)
        val angle = Random.nextDouble(0.0, Math.PI * 2)

        val endX = startX + length * cos(angle)
        val endY = startY + length * sin(angle)
        val ctrlX = (startX + endX) / 2 + Random.nextInt(-50, 50)
        val ctrlY = (startY + endY) / 2 + Random.nextInt(-50, 50)

        val path = Path2D.Double()
        path.moveTo(startX, startY)
        path.quadTo(ctrlX, ctrlY, endX, endY)

        g.color = chunk.color
        g.stroke = BasicStroke(Random.nextInt(6, 22).toFloat(), BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)
        g.draw(path)
        g.dispose()
    }

    // Renders soft, atmospheric watercolor blurs for memory deallocations
    private fun paintWaterWash(chunk: MemoryChunk) {
        val g = canvasImage.createGraphics()
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        val x = (chunk.address % canvasWidth).toFloat()
        val y = ((chunk.address / canvasWidth) % canvasHeight).toFloat()
        val radius = (chunk.size * 3.0f).coerceIn(40.0f, 250.0f)

        val washColor = Color(210, 225, 240, 30)
        val coreColor = Color(12, 14, 22, 70)

        val gradient = RadialGradientPaint(
            x, y, radius,
            floatArrayOf(0.0f, 0.6f, 1.0f),
            arrayOf(coreColor, washColor, Color(0, 0, 0, 0))
        )

        g.paint = gradient
        g.fillOval((x - radius).toInt(), (y - radius).toInt(), (radius * 2).toInt(), (radius * 2).toInt())
        g.dispose()
    }
}

fun main() {
    val frame = JFrame("Canvas Heap GC Visualizer")
    val canvasGC = DigitalCanvasGC()

    frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
    frame.add(canvasGC)
    frame.pack()
    frame.setLocationRelativeTo(null)
    frame.isVisible = true

    // Background thread simulating continuous heap activity and GC cycles
    thread(isDaemon = true) {
        val livePointers = mutableListOf<Int>()
        while (true) {
            // Memory Allocations
            repeat(Random.nextInt(1, 4)) {
                val size = Random.nextInt(15, 70)
                val ptr = canvasGC.allocate(size)
                livePointers.add(ptr)
            }

            // Dereferencing memory
            if (livePointers.size > 15) {
                repeat(Random.nextInt(1, 4)) {
                    if (livePointers.isNotEmpty()) {
                        val idx = Random.nextInt(livePointers.size)
                        val ptr = livePointers.removeAt(idx)
                        canvasGC.release(ptr)
                    }
                }
            }

            // Triggering Garbage Collector
            if (Random.nextFloat() < 0.4f) {
                canvasGC.sweepAndCollect()
            }

            Thread.sleep(100)
        }
    }
}