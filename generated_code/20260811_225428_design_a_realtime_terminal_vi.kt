import java.io.File
import kotlin.math.*
import kotlin.random.Random

// Visualizer screen boundaries
const val WIDTH = 80
const val HEIGHT = 22

// Terminal ANSI control codes for dynamic coloring and cursor manipulation
object ANSI {
    const val CLEAR = "\u001B[2J"
    const val HIDE_CURSOR = "\u001B[?25l"
    const val SHOW_CURSOR = "\u001B[?25h"
    const val RESET = "\u001B[0m"
    const val BOLD = "\u001B[1m"
    fun move(r: Int, c: Int) = "\u001B[${r};${c}H"
    fun fg256(color: Int) = "\u001B[38;5;${color}m"
}

// Genome defining ASCII traits and palette for a single plant species
data class Genome(
    var stems: List<Char> = listOf('│', '┃', '╱', '╲', '┼'),
    var leaves: List<Char> = listOf('v', 'w', '✦', '☘', '⁕'),
    var blooms: List<Char> = listOf('✿', '❀', '❁', '✺', '✪', '🪷'),
    var stemColor: Int = 34,   // Forest green
    var leafColor: Int = 78,   // Bright green
    var bloomColor: Int = 213, // Neon pink
    var isMutated: Boolean = false
)

// Individual Flora entity that grows upward and mutates during thermal spikes
class Plant(val originX: Int, val originY: Int, var genome: Genome) {
    val nodes = mutableListOf<Triple<Int, Char Int,>>()
    var heightMax = Random.nextInt(5, 12)
    private var currentY = originY

    init {
        nodes.add(Triple(originX, originY, genome.stems.random()))
    }

    fun grow(temp: Double, spike: Boolean) {
        if (nodes.size > 40) return

        if (spike) mutate()

        // Higher CPU temp accelerates cellular growth
        val growthRate = (temp / 35.0).coerceIn(0.4, 2.5)
        if (Random.nextDouble() < 0.65 * growthRate && originY - currentY < heightMax) {
            currentY--
            val lastX = nodes.last().first
            val deltaX = when {
                Random.nextDouble() < 0.3 -> -1
                Random.nextDouble() < 0.3 -> 1
                else -> 0
            }
            
            val newX = (lastX + deltaX).coerceIn(1, WIDTH - 2)
            val symbol = when {
                originY - currentY >= heightMax -> genome.blooms.random()
                Random.nextDouble() < 0.35 -> genome.leaves.random()
                else -> genome.stems.random()
            }
            nodes.add(Triple(newX, currentY, symbol))
        }
    }

    // Thermal spikes trigger rapid genetic restructuring
    fun mutate() {
        genome.isMutated = true
        val mutatedSymbols = listOf('Ψ', 'Ω', '§', '‡', '░', '█', '✦', '❖', '☣', '⚡', '☢', '▲')
        val mutatedColors = listOf(196, 201, 208, 226, 198, 45, 118, 51)
        
        genome.stems = List(3) { mutatedSymbols.random() }
        genome.leaves = List(3) { mutatedSymbols.random() }
        genome.blooms = List(3) { mutatedSymbols.random() }
        genome.stemColor = mutatedColors.random()
        genome.leafColor = mutatedColors.random()
        genome.bloomColor = mutatedColors.random()
    }
}

// Sensor reading actual hardware CPU temperature with a simulated thermal engine fallback
class CpuThermalSensor {
    private var simTime = 0.0
    private var lastTemp = 42.0

    fun readTemperature(): Pair<Double, Boolean> {
        val realTemp = readHardwareTemp()
        val temp = realTemp ?: simulateTemp()
        // Spike detected if sudden heat surge or absolute high temp threshold crossed
        val spike = (temp - lastTemp) > 2.2 || temp > 70.0
        lastTemp = temp
        return Pair(temp, spike)
    }

    private fun readHardwareTemp(): Double? {
        val thermalPaths = listOf(
            "/sys/class/thermal/thermal_zone0/temp",
            "/sys/class/thermal/thermal_zone1/temp",
            "/sys/class/hwmon/hwmon0/temp1_input"
        )
        for (path in thermalPaths) {
            runCatching {
                val file = File(path)
                if (file.exists()) {
                    val raw = file.readText().trim().toDoubleOrNull()
                    if (raw != null) return if (raw > 1000) raw / 1000.0 else raw
                }
            }
        }
        return null
    }

    private fun simulateTemp(): Double {
        simTime += 0.12
        val base = 42.0 + 16.0 * sin(simTime * 0.4)
        val noise = Random.nextDouble(-1.2, 1.2)
        // Synthetic workloads causing sudden thermal spikes
        val surge = if (Random.nextDouble() < 0.07) Random.nextDouble(9.0, 20.0) else 0.0
        return (base + noise + surge).coerceIn(30.0, 95.0)
    }
}

fun main() {
    val sensor = CpuThermalSensor()
    val plants = mutableListOf<Plant>()
    val grid = Array(HEIGHT) { CharArray(WIDTH) { ' ' } }
    val colorGrid = Array(HEIGHT) { IntArray(WIDTH) { 0 } }

    // Restore terminal cursor on exit
    Runtime.getRuntime().addShutdownHook(Thread {
        print("${ANSI.SHOW_CURSOR}${ANSI.RESET}${ANSI.CLEAR}${ANSI.move(1, 1)}")
    })

    print("${ANSI.HIDE_CURSOR}${ANSI.CLEAR}")

    var frameCount = 0
    while (true) {
        frameCount++
        val (temp, isSpike) = sensor.readTemperature()

        // Spontaneously seed new flora into the ecosystem
        if (plants.size < 14 && Random.nextDouble() < 0.3) {
            val spawnX = Random.nextInt(2, WIDTH - 2)
            plants.add(Plant(spawnX, HEIGHT - 2, Genome()))
        }

        // Update plants & trigger evolutionary shifts on thermal surges
        if (isSpike) {
            plants.forEach { it.mutate() }
        }
        plants.forEach { it.grow(temp, isSpike) }

        // Prune old, overgrown flora to maintain ecosystem diversity
        if (frameCount % 60 == 0 && plants.size > 6) {
            plants.removeAt(Random.nextInt(plants.size))
        }

        // Reset display frame buffers
        for (y in 0 until HEIGHT) {
            for (x in 0 until WIDTH) {
                grid[y][x] = ' '
                colorGrid[y][x] = 0
            }
        }

        // Render Ground/Soil (Shifts color with high thermal load)
        val soilColor = if (temp > 65.0) 208 else 238
        for (x in 0 until WIDTH) {
            grid[HEIGHT - 1][x] = if (x % 2 == 0) '▔' else '─'
            colorGrid[HEIGHT - 1][x] = soilColor
        }

        // Rasterize plant structures onto the ASCII grid
        plants.forEach { plant ->
            plant.nodes.forEach { (x, y, ch) ->
                if (y in 0 until HEIGHT - 1 && x in 0 until WIDTH) {
                    grid[y][x] = ch
                    colorGrid[y][x] = when (ch) {
                        in plant.genome.stems -> plant.genome.stemColor
                        in plant.genome.leaves -> plant.genome.leafColor
                        else -> plant.genome.bloomColor
                    }
                }
            }
        }

        // Construct frame buffer output
        val buffer = StringBuilder()
        buffer.append(ANSI.move(1, 1))

        // Render HUD Header with real-time temperature meter
        val tempColor = when {
            temp > 72.0 -> 196 // High alert red
            temp > 55.0 -> 208 // Warning orange
            else -> 46        // Optimal green
        }

        val statusText = when {
            isSpike -> "${ANSI.fg256(196)}${ANSI.BOLD}⚡ THERMAL MUTATION SPIKE DETECTED ⚡"
            temp > 60.0 -> "${ANSI.fg256(208)}HIGH ECOSYSTEM METABOLISM"
            else -> "${ANSI.fg256(78)}STABLE THERMAL CLIMATE"
        }

        val barFilled = (temp / 100.0 * 16).toInt().coerceIn(0, 16)
        val tempBar = "█".repeat(barFilled) + "░".repeat(16 - barFilled)

        buffer.append("${ANSI.fg256(255)}${ANSI.BOLD}CPU ECOSYSTEM HARNESS${ANSI.RESET} | ")
        buffer.append("TEMP: ${ANSI.fg256(tempColor)}%.1f°C ${ANSI.RESET}[$tempBar] | $statusText${ANSI.RESET}\n".format(temp))
        buffer.append("━".repeat(WIDTH)).append("\n")

        // Draw rendered visual frame
        for (y in 2 until HEIGHT) {
            for (x in 0 until WIDTH) {
                val ch = grid[y][x]
                val color = colorGrid[y][x]
                if (ch != ' ') {
                    buffer.append("${ANSI.fg256(color)}$ch${ANSI.RESET}")
                } else {
                    buffer.append(' ')
                }
            }
            buffer.append("\n")
        }

        print(buffer.toString())
        Thread.sleep(120) // Frame speed ~8 FPS
    }
}