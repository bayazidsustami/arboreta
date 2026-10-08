import java.io.File
import kotlin.math.*
import kotlin.random.Random

// Procedural Typography & Ant Foraging Engine driven by CPU Temperature
// Renders transient love letter trails in the console influenced by thermal fluctuations.
fun main() {
    val width = 74
    val height = 22
    val grid = Array(height) { DoubleArray(width) { 0.0 } }
    
    val message = " * I LOVE YOU FOREVER * "
    
    data class Ant(var x: Double, var y: Double, var vx: Double, var vy: Double)
    val ants = MutableList(40) {
        Ant(
            Random.nextDouble(width.toDouble()), 
            Random.nextDouble(height.toDouble()), 
            Random.nextDouble(-1.0, 1.0), 
            Random.nextDouble(-1.0, 1.0)
        )
    }

    // Clear screen escape sequence
    print("\u001b[2J")
    
    for (step in 0..200) {
        // Read live CPU temperature (Linux thermal zone) with graceful sinusoidal fallback
        val temp = try {
            val f = File("/sys/class/thermal/thermal_zone0/temp")
            if (f.exists()) f.readText().trim().toDouble() / 1000.0 
            else 45.0 + sin(step * 0.15) * 12.0 + Random.nextDouble(0.0, 3.0)
        } catch (e: Exception) {
            45.0 + sin(step * 0.15) * 12.0 + Random.nextDouble(0.0, 3.0)
        }

        // Temperature modulates ant Brownian motion and foraging velocity
        val chaosFactor = (temp / 75.0).coerceIn(0.3, 2.5)

        // Pheromone evaporation decay
        for (y in 0 until height) {
            for (x in 0 until width) {
                grid[y][x] *= 0.88
            }
        }

        // Update ant positions and deposit pheromones
        for (ant in ants) {
            ant.vx += Random.nextDouble(-0.6, 0.6) * chaosFactor
            ant.vy += Random.nextDouble(-0.6, 0.6) * chaosFactor
            
            val speed = sqrt(ant.vx * ant.vx + ant.vy * ant.vy)
            if (speed > 0) {
                ant.vx = (ant.vx / speed) * chaosFactor * 1.8
                ant.vy = (ant.vy / speed) * chaosFactor * 1.8
            }
            
            ant.x = (ant.x + ant.vx + width) % width
            ant.y = (ant.y + ant.vy + height) % height

            val ix = ant.x.toInt().coerceIn(0, width - 1)
            val iy = ant.y.toInt().coerceIn(0, height - 1)
            grid[iy][ix] = (grid[iy][ix] + 1.2).coerceAtMost(6.0)
        }

        // Render frame buffer using ASCII gradient mapping
        val sb = StringBuilder()
        sb.append("\u001b[H") // Reset cursor to top-left
        sb.append("=== TRANSIENT THERMAL LOVE ENGINE | CPU Temp: %.1f C | Frame: %d ===\n".format(temp, step))
        
        val gradient = " .·:=+*#%@"
        for (y in 0 until height) {
            for (x in 0 until width) {
                // Overlay the typography message across the central scanline
                val isTextRow = y == height / 2
                val textStart = (width - message.length) / 2
                val charToShow = if (isTextRow && x >= textStart && x < textStart + message.length) {
                    message[x - textStart]
                } else {
                    val intensity = grid[y][x]
                    val idx = (intensity / 6.0 * (gradient.length - 1)).toInt().coerceIn(0, gradient.length - 1)
                    gradient[idx]
                }
                sb.append(charToShow)
            }
            sb.append("\n")
        }
        
        print(sb.toString())
        Thread.sleep(80)
    }
}