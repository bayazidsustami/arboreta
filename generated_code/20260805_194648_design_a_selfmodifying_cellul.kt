import java.lang.management.ManagementFactory
import com.sun.management.OperatingSystemMXBean
import kotlin.random.Random

/**
 * Self-Modifying Cellular Automaton Typographic Tapestry
 *
 * Reads real-time JVM & System diagnostics (CPU load, memory usage, thread count, uptime)
 * to continuously mutate the transition rule set of a 2D cellular automaton.
 * The resulting automaton states render as an evolving typographic tapestry.
 */

class SystemDiagnostics {
    private val osBean = ManagementFactory.getPlatformMXBean(OperatingSystemMXBean::class.java)
    private val runtime = Runtime.getRuntime()

    fun getCpuLoad(): Double {
        val load = osBean.cpuLoad
        return if (load < 0) Random.nextDouble(0.1, 0.8) else load
    }

    fun getMemoryUsage(): Double {
        val max = runtime.maxMemory().toDouble()
        val used = (runtime.totalMemory() - runtime.freeMemory()).toDouble()
        return (used / max).coerceIn(0.0, 1.0)
    }

    fun getActiveThreads(): Int {
        return Thread.activeCount()
    }
}

class SelfModifyingAutomaton(val width: Int, val height: Int) {
    private var grid = Array(height) { IntArray(width) { Random.nextInt(4) } }
    private var ruleSet = IntArray(16) { Random.nextInt(4) }
    
    // Typographic glyph sets representing energy levels / automaton states
    private val typographyGradients = arrayOf(
        charArrayOf(' ', '.', ':', '-', '=', '+', '*', '#', '%', '@'),
        charArrayOf(' ', '·', '°', 'º', 'o', 'O', '0', 'Q', 'Ø', '█'),
        charArrayOf(' ', '░', '▒', '▓', '│', '┤', '╡', '╢', '╖', '█'),
        charArrayOf(' ', '╱', '╲', '╳', '┼', '╪', '╫', '╬', '█', '▉')
    )

    fun mutateRules(cpuLoad: Double, memoryRatio: Double, threads: Int) {
        val mutationRate = (cpuLoad * 0.5) + 0.05
        val styleIndex = (threads % typographyGradients.size)
        
        for (i in ruleSet.indices) {
            if (Random.nextDouble() < mutationRate) {
                // Rule modification driven by system memory and CPU rhythms
                val shift = (memoryRatio * 10).toInt() + i
                ruleSet[i] = (ruleSet[i] + shift + Random.nextInt(1, 3)) % 4
            }
        }
    }

    fun step() {
        val nextGrid = Array(height) { IntArray(width) }
        for (y in 0 until height) {
            for (x in 0 until width) {
                val current = grid[y][x]
                val neighborsSum = getNeighborsSum(x, y)
                
                // Transition logic influenced by dynamically shifting ruleSet
                val ruleLookup = (current + neighborsSum) % ruleSet.size
                nextGrid[y][x] = ruleSet[ruleLookup]
            }
        }
        grid = nextGrid
    }

    private fun getNeighborsSum(x: Int, y: Int): Int {
        var sum = 0
        for (dy in -1..1) {
            for (dx in -1..1) {
                if (dx == 0 && dy == 0) continue
                val nx = (x + dx + width) % width
                val ny = (y + dy + height) % height
                sum += grid[ny][nx]
            }
        }
        return sum
    }

    fun render(threads: Int): String {
        val palette = typographyGradients[threads % typographyGradients.size]
        val builder = StringBuilder()
        
        // ANSI escape clear screen
        builder.append("\u001B[H")
        
        for (y in 0 until height) {
            for (x in 0 until width) {
                val state = grid[y][x]
                val charIdx = ((state.toDouble() / 3.0) * (palette.size - 1)).toInt()
                
                // Apply dynamic ANSI color based on cell state
                val colorCode = 31 + (state % 6)
                builder.append("\u001B[${colorCode}m").append(palette[charIdx])
            }
            builder.append("\u001B[0m\n")
        }
        return builder.toString()
    }
}

fun main() {
    val width = 80
    val height = 24
    val automaton = SelfModifyingAutomaton(width, height)
    val diagnostics = SystemDiagnostics()

    // Hide cursor & clear screen
    print("\u001B[?25l\u001B[2J")

    Runtime.getRuntime().addShutdownHook(Thread {
        // Show cursor back on exit
        print("\u001B[?25h\u001B[0m")
    })

    var frame = 0
    while (true) {
        val cpu = diagnostics.getCpuLoad()
        val mem = diagnostics.getMemoryUsage()
        val threads = diagnostics.getActiveThreads()

        automaton.mutateRules(cpu, mem, threads)
        automaton.step()

        val output = automaton.render(threads)
        print(output)
        
        // Render diagnostic status line at bottom
        val status = String.format(" CPU: %5.1f%% | MEM: %5.1f%% | THREADS: %d | FRAME: %d ", cpu * 100, mem * 100, threads, frame++)
        print("\u001B[47m\u001B[30m" + status.padEnd(width) + "\u001B[0m")

        Thread.sleep(100)
    }
}