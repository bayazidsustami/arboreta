import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.max
import kotlin.math.min

// Represents cell types parsed from the ASCII art map
enum class CellType {
    EMPTY, WALL, PIPE, VALVE_OPEN, VALVE_CLOSED, RESERVOIR
}

// State of a single grid cell in the fluid system
data class Cell(
    val type: CellType,
    var fluid: Double = 0.0,      // Fluid volume [0.0, 1.0]
    var pressure: Double = 0.0,   // Internal pressure level
    var flowX: Double = 0.0,      // Velocity X for rendering ripples
    var flowY: Double = 0.0       // Velocity Y for rendering ripples
)

fun main() {
    // ASCII map representation:
    // R = Reservoir (Infinite source), # = Wall, - / | / + = Pipes
    // O = Open Valve, X = Closed Valve
    val mapAscii = """
        ####################################################
        # R ----+                                          #
        #       |                                          #
        #       +---- O ----+                              #
        #                   |                              #
        #                   +---- X ----+                  #
        #                               |                  #
        # R ----------------------------+                  #
        #                               |                  #
        #                               +----------------  #
        ####################################################
    """.trimIndent()

    val lines = mapAscii.lines()
    val height = lines.size
    val width = lines.maxOf { it.length }

    // Initialize grid
    var grid = Array(height) { r ->
        Array(width) { c ->
            val char = lines[r].getOrNull(c) ?: ' '
            val type = when (char) {
                '#' -> CellType.WALL
                'R' -> CellType.RESERVOIR
                '-', '|', '+' -> CellType.PIPE
                'O' -> CellType.VALVE_OPEN
                'X' -> CellType.VALVE_CLOSED
                else -> CellType.EMPTY
            }
            Cell(type = type, fluid = if (type == CellType.RESERVOIR) 1.0 else 0.0)
        }
    }

    // Hide cursor
    print("\u001B[?25l")
    
    // Clear screen
    print("\u001B[2J")

    val executor = Executors.newSingleThreadScheduledExecutor()
    
    // Simulation loop using Cellular Automata rules
    executor.scheduleAtFixedRate({
        val nextGrid = Array(height) { r ->
            Array(width) { c ->
                grid[r][c].copy()
            }
        }

        // 1. Reservoir replenishment
        for (r in 0 until height) {
            for (c in 0 until width) {
                if (grid[r][c].type == CellType.RESERVOIR) {
                    nextGrid[r][c].fluid = 1.0
                    nextGrid[r][c].pressure = 1.0
                }
            }
        }

        // 2. Fluid Diffusion & Pressure Propagation
        val dr = arrayOf(-1, 1, 0, 0)
        val dc = arrayOf(0, 0, -1, 1)

        for (r in 0 until height) {
            for (c in 0 until width) {
                val curr = grid[r][c]
                if (curr.type == CellType.WALL || curr.type == CellType.EMPTY || curr.type == CellType.VALVE_CLOSED) continue

                var totalOutflow = 0.0
                var netVx = 0.0
                var netVy = 0.0

                for (i in 0..3) {
                    val nr = r + dr[i]
                    val nc = c + dc[i]

                    if (nr in 0 until height && nc in 0 until width) {
                        val neighbor = grid[nr][nc]
                        if (neighbor.type != CellType.WALL && neighbor.type != CellType.EMPTY && neighbor.type != CellType.VALVE_CLOSED) {
                            // Flow driving force: fluid height difference + pressure gradient
                            val delta = (curr.fluid + curr.pressure) - (neighbor.fluid + neighbor.pressure)
                            if (delta > 0) {
                                val flow = min(curr.fluid * 0.25, delta * 0.2)
                                totalOutflow += flow
                                nextGrid[nr][nc].fluid += flow
                                
                                netVx += dc[i] * flow
                                netVy += dr[i] * flow
                            }
                        }
                    }
                }

                nextGrid[r][c].fluid = max(0.0, nextGrid[r][c].fluid - totalOutflow)
                nextGrid[r][c].flowX = netVx
                nextGrid[r][c].flowY = netVy

                // Pressure calculation based on fluid density/accumulation
                nextGrid[r][c].pressure = nextGrid[r][c].fluid * 1.2
            }
        }

        grid = nextGrid

        // 3. Render frame with dynamic ASCII symbols for ripples/pressure
        val buffer = StringBuilder()
        buffer.append("\u001B[H") // Reset cursor to top-left
        buffer.append("=== Dynamic Fluid System Cellular Automata ===\n\n")

        for (r in 0 until height) {
            for (c in 0 until width) {
                val cell = grid[r][c]
                val char = when (cell.type) {
                    CellType.WALL -> '#'
                    CellType.EMPTY -> ' '
                    CellType.VALVE_CLOSED -> 'X'
                    CellType.VALVE_OPEN, CellType.PIPE, CellType.RESERVOIR -> {
                        val f = cell.fluid
                        val vx = cell.flowX
                        val vy = cell.flowY

                        if (f < 0.05) {
                            if (cell.type == CellType.VALVE_OPEN) 'O' else '.'
                        } else {
                            // Render dynamic ripple icons based on flow direction & intensity
                            when {
                                cell.pressure > 1.1 -> '█' // High pressure
                                Math.abs(vx) > Math.abs(vy) && vx > 0 -> '>'
                                Math.abs(vx) > Math.abs(vy) && vx < 0 -> '<'
                                Math.abs(vy) > Math.abs(vx) && vy > 0 -> 'v'
                                Math.abs(vy) > Math.abs(vx) && vy < 0 -> '^'
                                f > 0.7 -> '~'
                                f > 0.3 -> '≈'
                                else -> '░'
                            }
                        }
                    }
                }
                
                // Simple color representation using ANSI escapes (blue for fluid, red for high pressure)
                if (cell.fluid > 0.05 && cell.type != CellType.WALL) {
                    if (cell.pressure > 1.1) {
                        buffer.append("\u001B[31m$char\u001B[0m") // Red high pressure
                    } else {
                        buffer.append("\u001B[36m$char\u001B[0m") // Cyan/Blue fluid
                    }
                } else {
                    buffer.append(char)
                }
            }
            buffer.append("\n")
        }

        print(buffer.toString())

    }, 0, 100, TimeUnit.MILLISECONDS)

    // Keep thread alive for demo duration
    Thread.sleep(15000)
    executor.shutdown()
    print("\u001B[?25h") // Restore cursor
}