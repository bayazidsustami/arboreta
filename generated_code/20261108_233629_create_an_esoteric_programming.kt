import kotlin.math.*

// InkScript: An esoteric programming language driven by fluid dynamics and mythical silhouettes.

data class Point(val x: Int, val y: Int)

class Parchment(val width: Int, val height: Int) {
    val grid = Array(height) { DoubleArray(width) }

    fun dropInk(x: Int, y: Int, amount: Double) {
        if (x in 0 until width && y in 0 until height) {
            grid[y][x] += amount
        }
    }

    // Simulate a step of viscous fluid diffusion across the parchment
    fun diffuse() {
        val nextGrid = Array(height) { DoubleArray(width) }
        val decay = 0.98
        for (y in 0 until height) {
            for (x in 0 until width) {
                var sum = grid[y][x] * 0.5
                var count = 0.5
                val neighbors = listOf(Point(x + 1, y), Point(x - 1, y), Point(x, y + 1), Point(x, y - 1))
                for (n in neighbors) {
                    if (n.x in 0 until width && n.y in 0 until height) {
                        sum += grid[n.y][n.x] * 0.125
                        count += 0.125
                    }
                }
                nextGrid[y][x] = (sum / count) * decay
            }
        }
        for (y in 0 until height) {
            for (x in 0 until width) {
                grid[y][x] = nextGrid[y][x]
            }
        }
    }

    // Measure resemblance to a target mythical silhouette
    fun matchSilhouette(targetMask: (Int, Int) -> Boolean): Double {
        var matchScore = 0.0
        var totalTarget = 0.0
        for (y in 0 until height) {
            for (x in 0 until width) {
                val isTarget = targetMask(x, y)
                val hasInk = grid[y][x] > 0.08
                if (isTarget) {
                    totalTarget += 1.0
                    if (hasInk) matchScore += 1.0
                } else if (hasInk) {
                    matchScore -= 0.15 // Penalty for ink spattering outside the silhouette
                }
            }
        }
        return max(0.0, matchScore / max(1.0, totalTarget))
    }
}

// Procedural mask defining a majestic Dragon silhouette
fun dragonSilhouette(x: Int, y: Int, w: Int, h: Int): Boolean {
    val nx = (x.toDouble() - w / 2) / (w / 2)
    val ny = (y.toDouble() - h / 2) / (h / 2)
    
    val isBody = abs(nx) < 0.22 && abs(ny) < 0.55
    val isHead = nx in -0.55..-0.2 && ny in -0.65..-0.35
    val isWings = abs(nx) in 0.18..0.75 && abs(ny) in -0.35..0.15
    val isTail = nx in 0.15..0.65 && ny in 0.15..0.75
    
    return isBody || isHead || isWings || isTail
}

fun main(args: Array<String>) {
    val width = 44
    val height = 22
    val parchment = Parchment(width, height)

    // Source code translates characters into initial ink droplet placements and viscosities
    val sourceCode = "SUMMON_DRACO_IGNIS_V1"
    
    println("Compiling InkScript source: '$sourceCode'")
    
    sourceCode.forEachIndexed { index, char ->
        val dropX = (index * 4) % width
        val dropY = ((index * 7) % height)
        val viscosity = char.code.toDouble() / 85.0
        parchment.dropInk(dropX, dropY, viscosity)
    }

    // Execute fluid dynamics simulation cycles
    for (step in 1..18) {
        parchment.diffuse()
    }

    // Validate compilation through silhouette recognition
    val fidelity = parchment.matchSilhouette { x, y -> dragonSilhouette(x, y, width, height) }
    val percentage = (fidelity * 100).toInt()
    println("Fluid dynamics simulation complete. Silhouette Fidelity: $percentage%")

    if (fidelity > 0.32) {
        println("SUCCESS: The ink stain successfully formed a recognizable dragon silhouette!")
        println(">> Bytecode executed: Mythical runtime initialized. Computational fire unleashed.")
    } else {
        println("COMPILATION ERROR: Ink diffusion failed to evoke the mythical beast. Refine your source syntax.")
    }
}