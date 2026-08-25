import kotlinx.browser.document
import kotlinx.browser.window
import org.w3c.dom.HTMLCanvasElement
import org.w3c.dom.CanvasRenderingContext2D
import org.w3c.dom.events.KeyboardEvent
import kotlin.math.*
import kotlin.random.Random

/**
 * Topological Keystroke Cellular Automaton
 * Translates real-time typing dynamics (key codes, timing, sequence) into an evolving
 * textile-like grid of text fibers governed by custom cellular automaton rules.
 */

class FiberCell(
    var state: Double = 0.0,
    var char: Char = ' ',
    var hue: Double = 200.0,
    var tension: Double = 0.5,
    var weaveDirection: Boolean = true // Horizontal vs Vertical fiber bias
)

class TextWeaveAutomaton(
    private val width: Int,
    private val height: Int,
    private val canvas: HTMLCanvasElement
) {
    private val ctx = canvas.getContext("2d") as CanvasRenderingContext2D
    private var grid = Array(width) { Array(height) { FiberCell() } }
    private var nextGrid = Array(width) { Array(height) { FiberCell() } }
    
    private var lastKeyTime = window.performance.now()
    private val activeGlyphs = mutableListOf<Char>()
    private val charPalette = "░▒▓█│─┼┴┬┤├┼║═╬".toCharArray()

    init {
        canvas.width = window.innerWidth.toInt()
        canvas.height = window.innerHeight.toInt()
        
        // Seed initial state
        for (x in 0 until width) {
            for (y in 0 until height) {
                grid[x][y].state = if (Random.nextDouble() < 0.1) Random.nextDouble() else 0.0
                grid[x][y].char = charPalette[Random.nextInt(charPalette.size)]
                grid[x][y].hue = (x * 360.0 / width)
            }
        }
    }

    fun injectKeystroke(event: KeyboardEvent) {
        val now = window.performance.now()
        val delta = now - lastKeyTime
        lastKeyTime = now

        val keyChar = if (event.key.length == 1) event.key[0] else '?'
        activeGlyphs.add(keyChar)
        if (activeGlyphs.size > 10) activeGlyphs.removeAt(0)

        val code = event.keyCode
        val normX = (code * 17) % width
        val normY = ((delta / 10).toInt() * 13) % height
        
        // Inject topological singularity (keystroke disturbance)
        val radius = (1000.0 / (delta + 1.0)).clamp(2.0, 12.0).toInt()
        
        for (dx in -radius..radius) {
            for (dy in -radius..radius) {
                val gx = (normX + dx + width) % width
                val gy = (normY + dy + height) % height
                if (dx * dx + dy * dy <= radius * radius) {
                    val cell = grid[gx][gy]
                    cell.state = 1.0
                    cell.char = keyChar
                    cell.hue = (code * 3.5) % 360.0
                    cell.tension = (100.0 / (delta + 1.0)).clamp(0.1, 1.0)
                    cell.weaveDirection = (dx + dy) % 2 == 0
                }
            }
        }
    }

    fun step() {
        for (x in 0 until width) {
            for (y in 0 until height) {
                val current = grid[x][y]
                val next = nextGrid[x][y]

                // Compute neighborhood tension & state gradient
                var neighborSum = 0.0
                var dominantHue = current.hue
                var dominantChar = current.char

                val neighbors = arrayOf(
                    grid[(x - 1 + width) % width][y],
                    grid[(x + 1) % width][y],
                    grid[x][(y - 1 + height) % height],
                    grid[x][(y + 1) % height]
                )

                for (n in neighbors) {
                    neighborSum += n.state
                    if (n.state > 0.5 && Random.nextDouble() < 0.2) {
                        dominantHue = n.hue
                        dominantChar = n.char
                    }
                }

                val avgNeighbor = neighborSum / 4.0

                // Woven Cellular Automaton Rule System
                // State transitions based on fiber tension and local topological density
                val nextState = when {
                    current.state > 0.8 -> (avgNeighbor * 0.9) + (current.tension * 0.1)
                    avgNeighbor in 0.25..0.65 -> avgNeighbor + 0.15 * current.tension
                    else -> current.state * 0.92 // Continuous decay creating thread residue
                }

                next.state = nextState.clamp(0.0, 1.0)
                next.hue = (current.hue * 0.95 + dominantHue * 0.05) % 360.0
                next.tension = (current.tension * 0.99)
                next.weaveDirection = if (avgNeighbor > 0.5) !current.weaveDirection else current.weaveDirection
                
                // Evolve character fibers based on dynamic state
                next.char = when {
                    next.state > 0.85 -> dominantChar
                    next.state > 0.5 -> if (next.weaveDirection) '║' else '═'
                    next.state > 0.2 -> if (next.weaveDirection) '│' else '─'
                    next.state > 0.05 -> '┼'
                    else -> ' '
                }
            }
        }

        // Swap grids
        val temp = grid
        grid = nextGrid
        nextGrid = temp
    }

    fun render() {
        val cellW = canvas.width.toDouble() / width
        val cellH = canvas.height.toDouble() / height

        ctx.fillStyle = "rgba(10, 10, 15, 0.25)" // Trail decay overlay
        ctx.fillRect(0.0, 0.0, canvas.width.toDouble(), canvas.height.toDouble())

        ctx.font = "${cellH.toInt()}px monospace"
        ctx.textBaseline = "top"

        for (x in 0 until width) {
            for (y in 0 until height) {
                val cell = grid[x][y]
                if (cell.state <= 0.01) continue

                val posX = x * cellW
                val posY = y * cellH

                val lightness = (cell.state * 60 + 20).toInt()
                val alpha = cell.state.clamp(0.1, 1.0)
                
                ctx.fillStyle = "hsla(${cell.hue.toInt()}, 80%, ${lightness}%, $alpha)"
                
                // Draw text fiber character
                ctx.fillText(cell.char.toString(), posX, posY)
                
                // Draw structural warp/weft connection lines
                if (cell.state > 0.4) {
                    ctx.strokeStyle = "hsla(${(cell.hue + 40).toInt() % 360}, 100%, 70%, ${alpha * 0.3})"
                    ctx.lineWidth = 0.5
                    ctx.beginPath()
                    if (cell.weaveDirection) {
                        ctx.moveTo(posX + cellW / 2, posY)
                        ctx.lineTo(posX + cellW / 2, posY + cellH)
                    } else {
                        ctx.moveTo(posX, posY + cellH / 2)
                        ctx.lineTo(posX + cellW, posY + cellH / 2)
                    }
                    ctx.stroke()
                }
            }
        }
    }
}

private fun Double.clamp(min: Double, max: Double): Double = max(min, min(max, this))

fun main() {
    window.onload = {
        val canvas = document.createElement("canvas") as HTMLCanvasElement
        document.body?.appendChild(canvas)
        document.body?.style?.margin = "0"
        document.body?.style?.overflow = "hidden"
        document.body?.style?.backgroundColor = "#0a0a0f"

        val columns = 120
        val rows = 60
        val automaton = TextWeaveAutomaton(columns, rows, canvas)

        window.addEventListener("keydown", { event ->
            automaton.injectKeystroke(event as KeyboardEvent)
        })

        window.addEventListener("resize", {
            canvas.width = window.innerWidth.toInt()
            canvas.height = window.innerHeight.toInt()
        })

        fun loop(timestamp: Double) {
            automaton.step()
            automaton.render()
            window.requestAnimationFrame(::loop)
        }

        window.requestAnimationFrame(::loop)
    }
}