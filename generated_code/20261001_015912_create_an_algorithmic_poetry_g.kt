import kotlin.math.PI
import kotlin.math.pow
import kotlin.math.max

// Algorithmic Poetry Generator simulating stellar gravitational collapse
// Maps stellar physical metrics (Radius, Density, Degeneracy Pressure) directly onto linguistic syntax and meter.

data class StellarState(
    var radius: Double,
    var mass: Double,
    var temperature: Double,
    var phase: String
) {
    val density: Double
        get() = (3.0 * mass) / (4.0 * PI * radius.pow(3.0))
    val pressure: Double
        get() = density.pow(5.0 / 3.0)
}

fun main() {
    val random = java.util.Random(1337)
    var star = StellarState(radius = 100.0, mass = 1.0, temperature = 3000.0, phase = "Protostellar Cloud")

    val phase1Words = listOf("hydrogen", "whisper", "vast", "drift", "nebula", "gentle", "scatter", "glow")
    val phase2Words = listOf("helium", "swell", "crimson", "titan", "radiate", "expand", "amber", "breath")
    val phase3Words = listOf("iron", "core", "crunch", "compress", "gravity", "fracture", "heavy", "sink")
    val phase4Words = listOf("void", "singularity", "event", "horizon", "silent", "infinite", "zero")

    println("--- STELLAR COLLAPSE LYRICS ---")

    for (step in 1..4) {
        star.radius = max(0.001, star.radius * 0.25)
        star.temperature *= 4.0

        star.phase = when {
            star.radius > 20.0 -> "Phase I: Main Sequence"
            star.radius > 2.0  -> "Phase II: Red Giant Swell"
            star.radius > 0.05 -> "Phase III: Core Collapse"
            else               -> "Phase IV: Singularity"
        }

        val activeVocab = when {
            star.radius > 20.0 -> phase1Words
            star.radius > 2.0  -> phase2Words
            star.radius > 0.05 -> phase3Words
            else               -> phase4Words
        }

        // Syntax density scales inversely with radius (higher density = tighter, shorter syntax)
        val wordCount = max(1, (star.radius * 0.2).toInt())
        
        println("\n[Radius: %.4f | Density: %.2e | Pressure: %.2e]".format(star.radius, star.density, star.pressure))
        println("Stage: ${star.phase}")

        repeat(3) {
            val line = (0..wordCount).map { activeVocab[random.nextInt(activeVocab.size)] }
                .joinToString(" ")
                .replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
            println("  $line.")
        }
    }
    println("\n--- COLLAPSE COMPLETE. LIGHT ENTRAPPED. ---")
}