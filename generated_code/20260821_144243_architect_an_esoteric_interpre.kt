import java.awt.Canvas
import java.awt.Color
import java.awt.Dimension
import java.awt.Graphics2D
import java.awt.image.BufferedImage
import java.awt.image.DataBufferInt
import javax.swing.JFrame
import javax.swing.WindowConstants
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

// Size of the fluid simulation grid
const val WIDTH = 256
const val HEIGHT = 256
const val SCALE = 3 // Rendering scale factor for Swing window

/**
 * Esoteric Ink Interpreter:
 * Parses source code chars into directional forces (vector fields) and ink dye sources.
 * Simulates fluid dynamics via simplified Navier-Stokes (advection, diffusion, pressure)
 * to execute and visualize logic as self-organizing colorful fluid currents.
 */
class InkInterpreter(private val code: String) {
    // Velocity vectors (u = x-velocity, v = y-velocity)
    val u = FloatArray(WIDTH * HEIGHT)
    val v = FloatArray(WIDTH * HEIGHT)
    private val u0 = FloatArray(WIDTH * HEIGHT)
    private val v0 = FloatArray(WIDTH * HEIGHT)

    // Ink density / Color channels (RGB)
    val r = FloatArray(WIDTH * HEIGHT)
    val g = FloatArray(WIDTH * HEIGHT)
    val b = FloatArray(WIDTH * HEIGHT)
    private val r0 = FloatArray(WIDTH * HEIGHT)
    private val g0 = FloatArray(WIDTH * HEIGHT)
    private val b0 = FloatArray(WIDTH * HEIGHT)

    init {
        compileSourceToField()
    }

    // Map source code tokens into vector forces and ink emitters across the grid
    private fun compileSourceToField() {
        val totalChars = code.length.coerceAtLeast(1)
        val gridSize = sqrt(totalChars.toDouble()).toInt().coerceAtLeast(1)
        val cellW = WIDTH / (gridSize + 1)
        val cellH = HEIGHT / (gridSize + 1)

        code.forEachIndexed { i, char ->
            val cx = ((i % gridSize) + 1) * cellW
            val cy = ((i / gridSize) + 1) * cellH
            val angle = (char.code * 0.137).toFloat() // Deterministic angle per character
            val force = (char.code % 5 + 1) * 2.5f

            // Inject vector force field around character position
            for (dy in -3..3) {
                for (dx in -3..3) {
                    val px = (cx + dx).coerceIn(0, WIDTH - 1)
                    val py = (cy + dy).coerceIn(0, HEIGHT - 1)
                    val idx = px + py * WIDTH
                    u[idx] += cos(angle) * force
                    v[idx] += sin(angle) * force

                    // Inject vibrant ink colors based on character ASCII properties
                    r[idx] = ((char.code * 7) % 255) / 255f
                    g[idx] = ((char.code * 13) % 255) / 255f
                    b[idx] = ((char.code * 23) % 255) / 255f
                }
            }
        }
    }

    // Single iteration of fluid physics (Advection + Diffusion)
    fun step(dt: Float = 0.2f) {
        // Advect velocities through themselves
        advect(1, u0, u, u0, v0, dt)
        advect(2, v0, v, u0, v0, dt)
        
        // Diffuse velocity field
        diffuse(1, u, u0, 0.0001f, dt)
        diffuse(2, v, v0, 0.0001f, dt)

        // Advect color dye fields along velocity field
        advect(0, r0, r, u, v, dt)
        advect(0, g0, g, u, v, dt)
        advect(0, b0, b, u, v, dt)

        diffuse(0, r, r0, 0.00005f, dt)
        diffuse(0, g, g0, 0.00005f, dt)
        diffuse(0, b, b0, 0.00005f, dt)
    }

    private fun diffuse(b: Int, x: FloatArray, x0: FloatArray, diff: Float, dt: Float) {
        val a = dt * diff * WIDTH * HEIGHT
        for (k in 0..15) { // Gauss-Seidel relaxation
            for (i in 1 until WIDTH - 1) {
                for (j in 1 until HEIGHT - 1) {
                    val idx = i + j * WIDTH
                    x[idx] = (x0[idx] + a * (x[idx - 1] + x[idx + 1] + x[idx - WIDTH] + x[idx + WIDTH])) / (1 + 4 * a)
                }
            }
        }
    }

    private fun advect(b: Int, d: FloatArray, d0: FloatArray, uField: FloatArray, vField: FloatArray, dt: Float) {
        val dt0 = dt * WIDTH
        for (i in 1 until WIDTH - 1) {
            for (j in 1 until HEIGHT - 1) {
                var x = i - dt0 * uField[i + j * WIDTH]
                var y = j - dt0 * vField[i + j * WIDTH]
                
                if (x < 0.5f) x = 0.5f
                if (x > WIDTH - 1.5f) x = WIDTH - 1.5f
                val i0 = x.toInt()
                val i1 = i0 + 1

                if (y < 0.5f) y = 0.5f
                if (y > HEIGHT - 1.5f) y = HEIGHT - 1.5f
                val j0 = y.toInt()
                val j1 = j0 + 1

                val s1 = x - i0
                val s0 = 1 - s1
                val t1 = y - j0
                val t0 = 1 - t1

                d[i + j * WIDTH] = s0 * (t0 * d0[i0 + j0 * WIDTH] + t1 * d0[i0 + j1 * WIDTH]) +
                                   s1 * (t0 * d0[i1 + j0 * WIDTH] + t1 * d0[i1 + j1 * WIDTH])
            }
        }
    }
}

// Swing Canvas to display animated ink fluid logic visualizer
class InkVisualizer(code: String) : Canvas(), Runnable {
    private val interpreter = InkInterpreter(code)
    private val img = BufferedImage(WIDTH, HEIGHT, BufferedImage.TYPE_INT_RGB)
    private val pixels = (img.raster.dataBuffer as DataBufferInt).data

    init {
        preferredSize = Dimension(WIDTH * SCALE, HEIGHT * SCALE)
    }

    fun start() {
        Thread(this).apply { isDaemon = true; start() }
    }

    override fun run() {
        while (true) {
            interpreter.step()

            // Map simulated ink density field to ARGB frame pixels
            for (i in 0 until WIDTH * HEIGHT) {
                val r = (interpreter.r[i].coerceIn(0f, 1f) * 255).toInt()
                val g = (interpreter.g[i].coerceIn(0f, 1f) * 255).toInt()
                val b = (interpreter.b[i].coerceIn(0f, 1f) * 255).toInt()
                pixels[i] = (r shl 16) or (g shl 8) or b
            }

            repaint()
            Thread.sleep(16) // ~60 FPS update loop
        }
    }

    override fun paint(g: java.awt.Graphics) {
        val g2 = g as Graphics2D
        g2.drawImage(img, 0, 0, WIDTH * SCALE, HEIGHT * SCALE, null)
    }

    override fun update(g: java.awt.Graphics) {
        paint(g)
    }
}

fun main() {
    // Sample esoteric script encoded as a string
    val sourceCode = """
        fun main() {
            val fluid = "Esoteric Fluid Vector Code"
            println("Rendering logic as animated fluid ink...")
        }
    """.trimIndent()

    val canvas = InkVisualizer(sourceCode)
    val frame = JFrame("Esoteric Ink Vector Field Interpreter")
    frame.defaultCloseOperation = WindowConstants.EXIT_ON_CLOSE
    frame.add(canvas)
    frame.pack()
    frame.setLocationRelativeTo(null)
    frame.isVisible = true

    canvas.start()
}