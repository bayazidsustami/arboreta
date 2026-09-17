import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.URL
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

// Fetches live atmospheric pressure from an open weather API, falling back gracefully if offline
fun fetchAtmosphericPressure(): Double {
    return try {
        val url = URL("[https://api.open-meteo.com/v1/forecast?latitude=40.7128&longitude=-74.0060&current=surface_pressure](https://api.open-meteo.com/v1/forecast?latitude=40.7128&longitude=-74.0060&current=surface_pressure)")
        val conn = url.openConnection()
        conn.connectTimeout = 1500
        conn.readTimeout = 1500
        val response = BufferedReader(InputStreamReader(conn.getInputStream())).readText()
        val regex = """"surface_pressure":([0-9.]+)""".toRegex()
        regex.find(response)?.groupValues?.get(1)?.toDouble() ?: 1013.25
    } catch (e: Exception) {
        1013.25 + Random.nextDouble(-3.0, 3.0)
    }
}

// Retrieves active system process IDs to inject into the cellular automaton matrix
fun getActivePids(): List<Long> {
    return try {
        ProcessHandle.allProcesses().map { it.pid() }.toArray().toList()
    } catch (e: Exception) {
        listOf(1L, 42L, 100L, 500L)
    }
}

fun main() {
    val width = 60
    val height = 22
    var grid = Array(height) { Array(width) { 0 } }

    // Hide terminal cursor for smooth generative painting
    print("\u001b[?25l")
    Runtime.getRuntime().addShutdownHook(Thread {
        print("\u001b[?25h\u001b[0m")
    })

    for (generation in 0 until 150) {
        val pressure = fetchAtmosphericPressure()
        val pids = getActivePids()

        // Initialize next generation grid
        val newGrid = Array(height) { Array(width) { 0 } }

        // Inject active process IDs as living seeds across the grid
        for (pid in pids) {
            val px = (pid % width).toInt()
            val py = ((pid / width) % height).toInt()
            newGrid[py][px] = 1
        }

        // Cellular automaton rules modulated by atmospheric pressure fluctuations
        for (y in 0 until height) {
            for (x in 0 until width) {
                var neighbors = 0
                for (dy in -1..1) {
                    for (dx in -1..1) {
                        if (dy == 0 && dx == 0) continue
                        val ny = (y + dy + height) % height
                        val nx = (x + dx + width) % width
                        neighbors += grid[ny][nx]
                    }
                }
                val alive = grid[y][x] == 1
                val threshold = if (pressure > 1013.0) 3 else 2
                newGrid[y][x] = when {
                    alive && (neighbors == 2 || neighbors == 3) -> 1
                    !alive && neighbors == threshold -> 1
                    else -> 0
                }
            }
        }
        grid = newGrid

        // Render shifting watercolor fractals using ANSI 24-bit TrueColor
        val sb = StringBuilder()
        sb.append("\u001b[H") // Reset cursor to top-left
        sb.append("Atmospheric Pressure: ${String.format("%.2f", pressure)} hPa | Active PIDs: ${pids.size} | Gen: $generation\n")

        for (y in 0 until height) {
            for (x in 0 until width) {
                if (grid[y][x] == 1) {
                    // Fluid watercolor color modulation based on cell coordinates, pressure, and time
                    val r = ((sin(x * 0.15 + generation * 0.08) + 1) * 90 + 75).toInt().coerceIn(0, 255)
                    val g = ((cos(y * 0.15 + pressure * 0.005) + 1) * 70 + 110).toInt().coerceIn(0, 255)
                    val b = ((sin((x + y) * 0.1 + generation * 0.05) + 1) * 110 + 130).toInt().coerceIn(0, 255)
                    
                    sb.append("\u001b[38;2;$r;$g;$b")
                    val textures = arrayOf("░", "▒", "▓", "█", "~", "≈")
                    sb.append(textures[(x + y + generation) % textures.size])
                } else {
                    sb.append("\u001b[38;2;25;25;35m·")
                }
            }
            sb.append("\u001b[0m\n")
        }

        print(sb.toString())
        Thread.sleep(120)
    }

    print("\u001b[?25h\u001b[0m")
}