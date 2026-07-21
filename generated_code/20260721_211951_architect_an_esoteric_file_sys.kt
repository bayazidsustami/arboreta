import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.abs
import kotlin.math.sqrt
import kotlin.random.Random

/**
 * Esoteric Memory-Reef File System
 * Maps continuous heap memory leaks into procedural ASCII coral growth,
 * where thermal waste from newly allocated bytes gradually bleaches the ecosystem.
 */

class CoralCell(
    var symbol: Char = ' ',
    var health: Double = 1.0, // 1.0 = Vibrant, 0.0 = Bleached Bone
    var colorCode: String = "\u001B[32m"
) {
    fun bleach(amount: Double) {
        health = (health - amount).coerceAtLeast(0.0)
    }

    fun render(): String {
        val color = when {
            health > 0.7 -> colorCode
            health > 0.3 -> "\u001B[33m" // Stress yellow
            health > 0.0 -> "\u001B[37m" // Faded white
            else -> "\u001B[90m"        // Dead grey
        }
        val charToDisplay = if (health <= 0.0 && symbol != ' ') '.' else symbol
        return "$color$charToDisplay\u001B[0m"
    }
}

class MemoryReefFileSystem(val width: Int = 50, val height: Int = 18) {
    private val reef = Array(height) { Array(width) { CoralCell() } }
    private val leakedHeap = mutableListOf<ByteArray>()
    private val coralSpecies = listOf('@', '&', '%', '*', '¥', '§', 'W', 'Y', 'Ψ')
    private val vibrantColors = listOf("\u001B[31m", "\u001B[32m", "\u001B[34m", "\u001B[35m", "\u001B[36m")

    // Allocates real memory bytes and radiates thermal bleaching to nearby reef coordinates
    fun allocateAndBleach(bytesToLeak: Int) {
        // Intentionally leak heap memory
        val memoryBlock = ByteArray(bytesToLeak) { Random.nextInt(256).toByte() }
        leakedHeap.add(memoryBlock)

        // Map memory signature to a grid coordinate
        val hash = abs(memoryBlock.contentHashCode())
        val cx = hash % width
        val cy = (hash / width) % height

        // Plant or refresh vibrant coral at allocation focal point
        reef[cy][cx].apply {
            symbol = coralSpecies.random()
            health = 1.0
            colorCode = vibrantColors.random()
        }

        // Thermal radiation effect: Bleach surrounding cells based on allocation size
        val thermalRadius = (bytesToLeak / 512).coerceIn(1, 6)
        for (dy in -thermalRadius..thermalRadius) {
            for (dx in -thermalRadius..thermalRadius) {
                val ny = cy + dy
                val nx = cx + dx
                if (ny in 0 until height && nx in 0 until width) {
                    val distance = sqrt((dx * dx + dy * dy).toDouble())
                    if (distance <= thermalRadius) {
                        val thermalStress = 0.20 * (1.0 - distance / (thermalRadius + 1))
                        reef[ny][nx].bleach(thermalStress)
                    }
                }
            }
        }
    }

    fun renderScreen() {
        print("\u001B[H\u001B[2J") // Clear terminal buffer
        val totalLeakedBytes = leakedHeap.sumOf { it.size }
        println("=== ESOTERIC MEMORY-REEF FS | Leaked Heap: $totalLeakedBytes Bytes ===")
        println("┌" + "─".repeat(width) + "┐")
        for (y in 0 until height) {
            print("│")
            for (x in 0 until width) {
                print(reef[y][x].render())
            }
            println("│")
        }
        println("└" + "─".repeat(width) + "┘")
        println("Thermal Allocation Pulse: Active | Bleached Coral: '.' | Living Coral: Colored Symbols")
    }
}

fun main() {
    val fileSystem = MemoryReefFileSystem()
    val executor = Executors.newScheduledThreadPool(1)
    var cycles = 0

    // Continuously leak byte arrays to simulate memory degradation and ocean bleaching
    val simulation = Runnable {
        val bytesAllocated = Random.nextInt(512, 3072)
        fileSystem.allocateAndBleach(bytesAllocated)
        fileSystem.renderScreen()
        
        cycles++
        if (cycles >= 50) {
            println("\n[FS CRITICAL] Reef ecosystem completely bleached by accumulated memory leaks.")
            executor.shutdown()
        }
    }

    executor.scheduleAtFixedRate(simulation, 0, 200, TimeUnit.MILLISECONDS)
}