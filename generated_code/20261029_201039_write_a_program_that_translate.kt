import kotlin.math.*
import kotlin.random.Random

// Represents a 3D point in space for typographic vertex manipulation
data class Vector3(var x: Double, var y: Double, var z: Double)

// Represents an individual character sculpture node in 3D space
data class GlyphChar(
    val char: Char,
    val basePosition: Vector3,
    val currentVertices: MutableList<Vector3>,
    var integrity: Double = 1.0 // 1.0 = solid, 0.0 = completely dissolved
) {
    // Dissolves character vertices based on real-time atmospheric pressure and volatility
    fun dissolve(pressureFactor: Double, volatility: Double) {
        integrity = max(0.0, integrity - (0.01 * volatility / pressureFactor))
        val dispersion = (1.0 - integrity) * 0.5
        currentVertices.forEach { v ->
            v.x += (Random.nextDouble() - 0.5) * dispersion
            v.y += (Random.nextDouble() - 0.5) * dispersion
            v.z += (Random.nextDouble() - 0.5) * dispersion
        }
    }
}

// Manages the complete self-evolving 3D typographic sculpture
class AtmosphericSculpture(text: String) {
    private val glyphs: List<GlyphChar> = text.mapIndexed { index, c ->
        val basePos = Vector3(index * 2.0, 0.0, 0.0)
        val verts = (0..10).map { 
            Vector3(basePos.x + Random.nextDouble(-0.5, 0.5), basePos.y + Random.nextDouble(-0.5, 0.5), basePos.z + Random.nextDouble(-0.5, 0.5)) 
        }.toMutableList()
        GlyphChar(c, basePos, verts)
    }

    // Updates sculpture topology based on incoming atmospheric telemetry
    fun update(atmosphericPressure: Double, humidity: Double) {
        val pressureFactor = atmosphericPressure / 1013.25 // Standard atmospheric pressure baseline
        val volatility = 1.2 + (100.0 - humidity) * 0.005
        glyphs.forEach { it.dissolve(pressureFactor, volatility) }
    }

    // Renders current structural state and character integrity levels
    fun renderState(): String {
        return glyphs.joinToString(" ") { glyph ->
            if (glyph.integrity > 0.2) "${glyph.char}(${"%.2f".format(glyph.integrity)})" else "~"
        }
    }
}

fun main() {
    println("Initializing 3D Typographic Sculpture Engine...")
    val sculpture = AtmosphericSculpture("ATMOSPHERE")
    
    // Incoming real-time atmospheric pressure (hPa) and humidity data streams
    val pressures = listOf(1015.0, 1008.5, 995.0, 982.0, 970.5)
    val humidities = listOf(45.0, 60.0, 75.0, 88.0, 95.0)

    for (i in pressures.indices) {
        val p = pressures[i]
        val h = humidities[i]
        println("\n[Weather Stream] Pressure: $p hPa | Humidity: $h%")
        sculpture.update(p, h)
        println("Sculpture State: ${sculpture.renderState()}")
    }
    println("\nSculpture evolution complete. Characters dissolved into atmospheric dust.")
}