import java.io.File
import java.lang.management.ManagementFactory
import kotlin.concurrent.thread
import kotlin.random.Random

/**
 * SELF-MODIFYING MEMORY TERRAFORMER & EXCEPTION ECOSYSTEM
 * 
 * 1. Reads raw bytecode/memory footprint into a byte array representing terrain elevation.
 * 2. Hooks Thread.setDefaultUncaughtExceptionHandler to convert JVM runtime crashes into Exception Nutrients.
 * 3. Spawns background threads that intentionally throw unhandled exceptions.
 * 4. Animates text organisms ('Ѫ', '§', 'Ø', 'ψ') across an ASCII screen map.
 * 5. Organisms hunt exception nutrients, devour them, and write back into the binary terrain memory array.
 */

// Represents an ASCII creature surviving in the heap environment
data class Creature(
    var x: Int,
    var y: Int,
    val symbol: Char,
    var energy: Int = 60,
    val species: String
)

// An unhandled exception translated into consumable digital energy
data class ExceptionNutrient(
    val x: Int,
    val y: Int,
    val type: String,
    var energyValue: Int
)

fun main() {
    val width = 60
    val height = 22
    val totalCells = width * height

    // Step 1: Read binary memory/bytecode footprint as raw terrain height data
    val memoryFootprint: ByteArray = try {
        val className = object {}.javaClass.enclosingClass?.name ?: "MainKt"
        val resourcePath = className.replace('.', '/') + ".class"
        object {}.javaClass.classLoader.getResourceAsStream(resourcePath)?.readBytes()
            ?: ByteArray(totalCells) { Random.nextInt(0, 256).toByte() }
    } catch (e: Exception) {
        ByteArray(totalCells) { Random.nextInt(0, 256).toByte() }
    }

    // Mutable binary memory map used as live topographic buffer
    val terrainMemory = ByteArray(totalCells) { i ->
        if (i < memoryFootprint.size) memoryFootprint[i] else Random.nextInt(0, 256).toByte()
    }

    val exceptionPool = mutableListOf<ExceptionNutrient>()
    val creatures = mutableListOf(
        Creature(Random.nextInt(width), Random.nextInt(height), 'Ѫ', 100, "HeapEater"),
        Creature(Random.nextInt(width), Random.nextInt(height), '§', 80, "StackDevourer"),
        Creature(Random.nextInt(width), Random.nextInt(height), 'Ø', 90, "NullSiphon"),
        Creature(Random.nextInt(width), Random.nextInt(height), 'ψ', 75, "ByteParasite")
    )

    var exceptionsConsumed = 0
    var era = 1

    // Step 2: Intercept unhandled exceptions globally and synthesize them into food sources
    Thread.setDefaultUncaughtExceptionHandler { _, throwable ->
        val exName = throwable.javaClass.simpleName
        val x = Random.nextInt(width)
        val y = Random.nextInt(height)
        val nutrientEnergy = (throwable.stackTrace.size * 12).coerceAtLeast(25)

        synchronized(exceptionPool) {
            exceptionPool.add(ExceptionNutrient(x, y, exName, nutrientEnergy))
            if (exceptionPool.size > 20) exceptionPool.removeAt(0)
        }
    }

    // Step 3: Chaos engine thread generating deliberate background exceptions to feed organisms
    thread(isDaemon = true, name = "ChaosEngine") {
        val faultGenerators = listOf<() -> Unit>(
            { throw NullPointerException("Dereferenced null pointer at memory address 0x${Random.nextInt(0xFFFF).toString(16)}") },
            { throw ArithmeticException("Division by zero inside terraforming calculation") },
            { throw IndexOutOfBoundsException("Heap boundary buffer overflow detected") },
            { throw IllegalStateException("Corrupted state transition in memory byte cell") },
            { throw IllegalArgumentException("Invalid bytecode operand passed to ecosystem loop") }
        )

        while (true) {
            Thread.sleep(Random.nextLong(500, 1200))
            // Trigger exception on a isolated transient thread
            thread(name = "FaultyThread") {
                faultGenerators.random().invoke()
            }
        }
    }

    // Clear console terminal screen
    print("\u001B[2J")

    // Step 4: Core Terraforming & Interactive Ecosystem Rendering Loop
    while (true) {
        // Map raw byte values (0..255) to topographic terrain features
        // 0..63 = Deep Water (~), 64..127 = Plains (.), 128..191 = Forest (:), 192..255 = Peak (^)
        val grid = Array(height) { CharArray(width) }
        for (y in 0 until height) {
            for (x in 0 until width) {
                val idx = y * width + x
                val rawByte = terrainMemory[idx].toInt() and 0xFF
                grid[y][x] = when {
                    rawByte < 64 -> '~'
                    rawByte < 128 -> '.'
                    rawByte < 192 -> ':'
                    else -> '^'
                }
            }
        }

        // Render active exception food drops on the map
        synchronized(exceptionPool) {
            for (food in exceptionPool) {
                if (food.x in 0 until width && food.y in 0 until height) {
                    grid[food.y][food.x] = '!'
                }
            }
        }

        // Update Creature behavior: pathfinding, feeding, and terraforming binary memory
        val iterator = creatures.iterator()
        val newBorns = mutableListOf<Creature>()

        while (iterator.hasNext()) {
            val c = iterator.next()
            c.energy -= 1 // Metabolic energy decay

            if (c.energy <= 0) {
                iterator.remove()
                continue
            }

            // Seek nearest unhandled exception nutrient
            val targetFood = synchronized(exceptionPool) {
                exceptionPool.minByOrNull { (it.x - c.x) * (it.x - c.x) + (it.y - c.y) * (it.y - c.y) }
            }

            if (targetFood != null) {
                // Move towards exception source
                if (c.x < targetFood.x) c.x++ else if (c.x > targetFood.x) c.x--
                if (c.y < targetFood.y) c.y++ else if (c.y > targetFood.y) c.y--

                // Feed on exception
                if (c.x == targetFood.x && c.y == targetFood.y) {
                    c.energy += targetFood.energyValue
                    exceptionsConsumed++
                    synchronized(exceptionPool) { exceptionPool.remove(targetFood) }

                    // Terraforming: Creature mutates underlying binary memory upon feeding
                    val memIndex = c.y * width + c.x
                    terrainMemory[memIndex] = ((terrainMemory[memIndex].toInt() and 0xFF) + 50).toByte()

                    // Replicate if organism accumulates high energy
                    if (c.energy > 130) {
                        c.energy /= 2
                        newBorns.add(
                            Creature(
                                (c.x + Random.nextInt(-1, 2)).coerceIn(0, width - 1),
                                (c.y + Random.nextInt(-1, 2)).coerceIn(0, height - 1),
                                c.symbol,
                                c.energy,
                                c.species
                            )
                        )
                    }
                }
            } else {
                // Random wander across topographic surface
                c.x = (c.x + Random.nextInt(-1, 2)).coerceIn(0, width - 1)
                c.y = (c.y + Random.nextInt(-1, 2)).coerceIn(0, height - 1)
            }

            grid[c.y][c.x] = c.symbol
        }

        creatures.addAll(newBorns)

        // Seed new life if extinct
        if (creatures.isEmpty()) {
            creatures.add(Creature(Random.nextInt(width), Random.nextInt(height), 'Ѫ', 100, "HeapEater"))
            era++
        }

        // Render Ecosystem UI Frame
        val runtime = Runtime.getRuntime()
        val usedMem = (runtime.totalMemory() - runtime.freeMemory()) / 1024

        val output = StringBuilder()
        output.append("\u001B[H") // Reset cursor position top-left
        output.append("=== BINARY MEMORY TERRAFORMER [Era $era] ===\n")
        output.append("Heap Memory Allocated: $usedMem KB | Exception Nutrients: ${exceptionPool.size}\n")
        output.append("Text Organisms Alive: ${creatures.size} | Unhandled Exceptions Consumed: $exceptionsConsumed\n")
        output.append("=".repeat(width)).append("\n")

        for (row in grid) {
            output.append(String(row)).append("\n")
        }

        output.append("=".repeat(width)).append("\n")
        output.append("Terrain: ~ Water  . Plains  : Forest  ^ Peak | Food: ! Exception\n")
        output.append("Creatures: Ѫ HeapEater | § StackDevourer | Ø NullSiphon | ψ ByteParasite\n")

        print(output.toString())

        Thread.sleep(100)
    }
}