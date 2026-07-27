import kotlin.math.*

/**
 * System Call Trace to Fluid Dynamics Simulation & Topological Mapper
 *
 * Mechanics:
 * 1. Analyzes syscall trace logs for execution anomalies.
 * 2. Unfreed allocations (Memory Leaks) generate buoyant upward density flows.
 * 3. Concurrent unsynchronized accesses (Race Conditions) inject rotational vortex torque.
 * 4. Runs Eulerian grid simulation (Advection + Vorticity Diffusion).
 * 5. Resolves final kinetic & potential state into an ASCII Topological Execution Map.
 */

enum class SyscallType { MALLOC, FREE, LOCK, UNLOCK }

data class SyscallLog(
    val timestamp: Long,
    val threadId: Int,
    val type: SyscallType,
    val address: Long,
    val size: Int = 0
)

class ExecutionFluidGrid(val width: Int, val height: Int) {
    val u = Array(width) { DoubleArray(height) }       // Horizontal Velocity
    val v = Array(width) { DoubleArray(height) }       // Vertical Velocity
    val density = Array(width) { DoubleArray(height) } // Density (Buoyancy Mass)
    val curl = Array(width) { DoubleArray(height) }    // Vorticity field

    fun addBuoyancy(x: Int, y: Int, amount: Double) {
        if (x in 0 until width && y in 0 until height) {
            density[x][y] += amount
            v[x][y] -= amount * 0.4 // Upward force vector
        }
    }

    fun addVortex(cx: Int, cy: Int, strength: Double, radius: Int = 4) {
        for (dx in -radius..radius) {
            for (dy in -radius..radius) {
                val nx = cx + dx
                val ny = cy + dy
                if (nx in 0 until width && ny in 0 until height) {
                    val dist = sqrt((dx * dx + dy * dy).toDouble()) + 0.001
                    if (dist <= radius) {
                        val factor = (1.0 - dist / radius) * strength
                        u[nx][ny] += -dy / dist * factor
                        v[nx][ny] += dx / dist * factor
                        curl[nx][ny] += strength * factor
                    }
                }
            }
        }
    }

    // Eulerian Fluid Simulation Step (Semi-Lagrangian Advection)
    fun step(dt: Double) {
        val newDensity = Array(width) { DoubleArray(height) }
        for (x in 1 until width - 1) {
            for (y in 1 until height - 1) {
                // Compute local fluid curl (vorticity)
                curl[x][y] = (v[x + 1][y] - v[x - 1][y] - u[x][y + 1] + u[x][y - 1]) * 0.5
                
                // Backtrack particle position along velocity field
                val srcX = (x - u[x][y] * dt).coerceIn(0.0, (width - 1).toDouble())
                val srcY = (y - v[x][y] * dt).coerceIn(0.0, (height - 1).toDouble())
                
                val ix = srcX.toInt()
                val iy = srcY.toInt()
                newDensity[x][y] = density[ix][iy] * 0.98 // Dissipation factor
            }
        }
        for (x in 0 until width) {
            for (y in 0 until height) {
                density[x][y] = newDensity[x][y]
            }
        }
    }

    // Collapse fluid dynamics energy grid into a static topological contour representation
    fun resolveTopologicalMap(): Array<CharArray> {
        val isoLayers = " .:-=+*#%@"
        val topoMap = Array(height) { CharArray(width) }
        
        var maxEnergy = 0.001
        for (x in 0 until width) {
            for (y in 0 until height) {
                val energy = density[x][y] + abs(curl[x][y])
                if (energy > maxEnergy) maxEnergy = energy
            }
        }

        for (y in 0 until height) {
            for (x in 0 until width) {
                val energy = density[x][y] + abs(curl[x][y])
                val idx = ((energy / maxEnergy) * (isoLayers.length - 1)).toInt().coerceIn(0, isoLayers.length - 1)
                topoMap[y][x] = isoLayers[idx]
            }
        }
        return topoMap
    }
}

class TraceAnalyzer(val grid: ExecutionFluidGrid) {
    private val activeAllocations = mutableMapOf<Long, Int>()
    private val lockOwners = mutableMapOf<Long, Int>()
    private val lastAccess = mutableMapOf<Long, Long Pair<Int,>>()

    fun processTrace(logs: List<SyscallLog>) {
        for (log in logs) {
            val gridX = (log.address.hashCode() and 0x7FFFFFFF) % grid.width
            val gridY = (log.threadId * 4) % grid.height

            when (log.type) {
                SyscallType.MALLOC -> activeAllocations[log.address] = log.size
                SyscallType.FREE -> activeAllocations.remove(log.address)
                SyscallType.LOCK -> lockOwners[log.address] = log.threadId
                SyscallType.UNLOCK -> lockOwners.remove(log.address)
            }

            // Race Condition Detection: Unlocked concurrent thread access within tight timestamp delta
            val last = lastAccess[log.address]
            if (last != null && last.first != log.threadId && (log.timestamp - last.second) < 10) {
                if (lockOwners[log.address] != log.threadId) {
                    val rotationalTorque = if (log.threadId % 2 == 0) 8.0 else -8.0
                    grid.addVortex(gridX, gridY, rotationalTorque)
                }
            }
            lastAccess[log.address] = Pair(log.threadId, log.timestamp)
        }

        // Memory Leak Detection: Unreleased allocations generate upward fluid buoyancy
        for ((addr, size) in activeAllocations) {
            val gridX = (addr.hashCode() and 0x7FFFFFFF) % grid.width
            val gridY = grid.height - 1
            val buoyancyForce = size / 50.0
            grid.addBuoyancy(gridX, gridY, buoyancyForce)
        }
    }
}

fun main() {
    val logs = mutableListOf<SyscallLog>()
    var clock = 0L

    // 1. Normal execution flow
    for (i in 0..15) {
        logs.add(SyscallLog(clock++, threadId = 1, type = SyscallType.MALLOC, address = 0x1000L + i, size = 64))
        logs.add(SyscallLog(clock++, threadId = 1, type = SyscallType.FREE, address = 0x1000L + i))
    }

    // 2. Memory Leak Simulation (Allocated without matching free calls)
    for (i in 0..20) {
        logs.add(SyscallLog(clock++, threadId = 2, type = SyscallType.MALLOC, address = 0x5000L + i * 0x20, size = 512))
    }

    // 3. Race Condition Simulation (Thread 3 and Thread 4 accessing shared resource without mutex)
    val sharedResource = 0xA000L
    for (i in 0..8) {
        logs.add(SyscallLog(clock++, threadId = 3, type = SyscallType.MALLOC, address = sharedResource, size = 128))
        logs.add(SyscallLog(clock + 1, threadId = 4, type = SyscallType.MALLOC, address = sharedResource, size = 128))
        clock += 2
    }

    // Initialize fluid dynamics workspace
    val gridWidth = 70
    val gridHeight = 22
    val fluidGrid = ExecutionFluidGrid(gridWidth, gridHeight)
    val analyzer = TraceAnalyzer(fluidGrid)

    // Map system call traces to fluid dynamics sources
    analyzer.processTrace(logs)

    // Evolve fluid dynamics model through time steps
    println("Evolving system call fluid dynamics simulation...")
    for (step in 0..40) {
        fluidGrid.step(dt = 0.15)
    }

    // Resolve fluid physical state to static topological map
    println("\n================ SOFTWARE EXECUTION TOPOLOGICAL MAP ================")
    val topoMap = fluidGrid.resolveTopologicalMap()
    for (row in topoMap) {
        println(String(row))
    }
    println("====================================================================")
    println("Legend: Elevated peaks (#, %, @) denote severe turbulence & buoyancy")
    println("        (Race condition vortices & Memory leak hotspots).")
}