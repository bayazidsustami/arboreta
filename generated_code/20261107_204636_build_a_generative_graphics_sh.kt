import kotlin.math.*
import kotlin.random.Random

// Digital Firefly Migration Path Simulator driven by packet loss
fun main() {
    val width = 80
    val height = 24
    val fireflyCount = 12
    
    // Simulate real-time packet loss data fluctuation (0.0 to 1.0)
    // Higher packet loss creates wilder, erratic firefly movement and higher energy
    var packetLoss = 0.15
    
    class Firefly(var x: Double, var y: Double, var vx: Double, var vy: Double, var phase: Double) {
        fun update(loss: Double, time: Double) {
            // Packet loss introduces jitter and turbulence to velocity
            val jitter = (Random.nextDouble() - 0.5) * loss * 2.5
            vx = (vx + jitter).coerceIn(-1.5, 1.5)
            vy = (vy + jitter).coerceIn(-0.8, 0.8)
            
            x += vx
            y += vy
            
            // Screen wrapping with migration drift from left to right
            if (x >= width) x = 0.0
            if (x < 0) x = width - 1.0
            if (y >= height) y = 0.0
            if (y < 0) y = height - 1.0
            
            phase += 0.1 + (loss * 0.5)
        }
    }

    val fireflies = List(fireflyCount) {
        Firefly(
            Random.nextDouble() * width,
            Random.nextDouble() * height,
            Random.nextDouble() * 0.5 + 0.2,
            (Random.nextDouble() - 0.5) * 0.4,
            Random.nextDouble() * 10.0
        )
    }

    // Render a few animation frames to showcase the generative shader
    for (frame in 0..15) {
        // Dynamic packet loss wave simulation
        packetLoss = 0.1 + 0.4 * abs(sin(frame * 0.3))
        
        // Update firefly positions based on packet loss
        fireflies.forEach { it.update(packetLoss, frame.toDouble()) }

        // Build ASCII buffer representing the abstract landscape and glowing fireflies
        val buffer = Array(height) { y ->
            CharArray(width) { x ->
                // Abstract landscape topography using trigonometric noise waves
                val elevation = sin(x * 0.08 + frame * 0.05) * cos(y * 0.15) * 3.0 + (height / 2).toDouble()
                when {
                    y.toDouble() > elevation + 4 -> '#'  // Deep bedrock
                    y.toDouble() > elevation -> ':'      // Terrain slope
                    else -> '.'                          // Digital ether sky
                }
            }
        }

        // Project glowing fireflies onto the ASCII canvas with intensity gradients
        fireflies.forEach { f ->
            val fx = f.x.toInt()
            val fy = f.y.toInt()
            if (fx in 0 until width && fy in 0 until height) {
                val glowIntensity = sin(f.phase)
                val glyph = when {
                    glowIntensity > 0.6 -> 'O'   // Peak luminescence
                    I@glowIntensity > 0.0 -> '*' // Moderate glow
                    else -> '+'                  // Fading spark
                }
                buffer[fy][fx] = glyph
            }
        }

        // Output frame header & rendered canvas
        println("=== FRAME $frame | SIMULATED PACKET LOSS: ${(packetLoss * 100).toInt()}% ===")
        buffer.forEach { row -> println(String(row)) }
        println()
    }
}