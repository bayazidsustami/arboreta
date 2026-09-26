import java.io.File
import kotlin.random.Random

// Represents a file system node translated into the terrarium ecosystem
data class TerrariumNode(val name: String, var sizeBytes: Long, val isDirectory: Boolean)

// A rogue procedural hermit crab that feeds on directory sizes
data class HermitCrab(
    val id: Int,
    var x: Int,
    var y: Int,
    var energy: Int,
    var shellCapacity: Long
)

fun scanLocalFileSystem(): List<TerrariumNode> {
    val currentDir = File(".")
    val files = currentDir.listFiles() ?: return emptyList()
    
    return files.map { file ->
        val size = if (file.isDirectory) {
            try { file.walkTopDown().sumOf { it.length() } } catch (e: Exception) { 0L }
        } else {
            file.length()
        }
        TerrariumNode(file.name.take(8), size, file.isDirectory)
    }
}

fun main() {
    val nodes = scanLocalFileSystem()
    if (nodes.isEmpty()) {
        println("The local habitat is barren.")
        return
    }

    val width = 50
    val height = 15
    
    // Spawn initial rogue hermit crabs
    val crabs = mutableListOf(
        HermitCrab(id = 1, x = width / 4, y = height / 2, energy = 100, shellCapacity = 5000L),
        HermitCrab(id = 2, x = (width * 3) / 4, y = height / 2, energy = 80, shellCapacity = 10000L)
    )

    println("=== LOCAL FILE SYSTEM TERRARIUM INITIALIZED ===")
    println("Directory sizes dictate crab appetites. Press Enter to simulate a cycle.")

    // Simulate 4 generational cycles of the terrarium
    for (cycle in 1..4) {
        println("\n--- ECOSYSTEM CYCLE $cycle ---")
        
        // Initialize grid
        val grid = Array(height) { CharArray(width) { ' ' } }
        
        // Draw boundaries
        for (x in 0 until width) {
            grid[0][x] = '-'
            grid[height - 1][x] = '-'
        }

        // Place nodes as terrain features based on size
        nodes.forEachIndexed { index, node ->
            val px = (index * 6) % (width - 2) + 1
            val py = (index * 3) % (height - 2) + 1
            // Larger directories appear as dense thickets 'O', smaller files as '.'
            grid[py][px] = if (node.isDirectory) {
                if (node.sizeBytes > 1_000_000) 'O' else 'o'
            } else {
                '.'
            }
        }

        // Update crab positions and feeding mechanics
        for (crab in crabs) {
            // Crabs gravitate toward larger directory nodes or wander procedurally
            crab.x = (crab.x + Random.nextInt(-2, 3)).coerceIn(1, width - 2)
            crab.y = (crab.y + Random.nextInt(-1, 2)).coerceIn(1, height - 2)
            
            // Feed: consume energy from environment
            crab.energy -= 5
            if (crab.energy < 0) crab.energy = 0
            
            // Render crab on grid
            grid[crab.y][crab.x] = 'C'
        }

        // Print terrarium frame
        for (row in grid) {
            println(row.joinToString(""))
        }

        // Status report
        crabs.forEach { c ->
            println("Crab #${c.id} at (${c.x}, ${c.y}) | Energy: ${c.energy} | Shell Capacity: ${c.shellCapacity} bytes")
        }

        try {
            readlnOrNull()
        } catch (e: Exception) {
            break
        }
    }
    
    println("\nTerrarium simulation concluded. The hermit crabs burrow deep into the disk sectors.")
}

main()