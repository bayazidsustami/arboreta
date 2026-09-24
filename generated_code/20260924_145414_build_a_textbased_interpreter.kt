import kotlin.math.*

// Gravitational Interpreter: Variables are masses in a 2D plane.
// Program execution is driven by orbital collisions and gravitational interactions.

data class VariableMass(
    val name: String,
    var mass: Double,
    var x: Double,
    var y: Double,
    var vx: Double,
    var vy: Double,
    var value: Double,
    val action: (VariableMass, VariableMass) -> Unit
)

fun main() {
    val G = 2.0
    val dt = 0.02
    val collisionThreshold = 0.8

    val variables = mutableListOf(
        VariableMass("A", mass = 15.0, x = -2.0, y = 0.0, vx = 0.0, vy = 1.5, value = 10.0) { self, other ->
            println("[COLLISION] ${self.name} absorbs ${other.name}: ${self.value} + ${other.value}")
            self.value += other.value
        },
        VariableMass("B", mass = 5.0, x = 2.0, y = 0.0, vx = 0.0, vy = -2.0, value = 4.0) { self, other ->
            println("[COLLISION] ${self.name} multiplies by ${other.name}: ${self.value} * ${other.value}")
            self.value *= other.value
        },
        VariableMass("C", mass = 1.0, x = 0.0, y = 4.0, vx = -2.5, vy = 0.0, value = 100.0) { self, other ->
            println("[RESULT] ${self.name} reached body interaction with value: ${self.value}")
        }
    )

    println("--- Starting Gravitational Execution ---")

    for (step in 1..300) {
        // Apply gravity between all variable pairs
        for (i in variables.indices) {
            for (j in i + 1 until variables.size) {
                val bi = variables[i]
                val bj = variables[j]

                val dx = bj.x - bi.x
                val dy = bj.y - bi.y
                val distSq = dx * dx + dy * dy + 1e-10
                val dist = sqrt(distSq)

                // Trigger execution flow via collision event
                if (dist < collisionThreshold) {
                    bi.action(bi, bj)
                    bi.vx = -bi.vx; bi.vy = -bi.vy
                    bj.vx = -bj.vx; bj.vy = -bj.vy
                }

                // Gravitational force calculation: F = G * m1 * m2 / r^2
                val force = G * bi.mass * bj.mass / distSq
                val fx = force * (dx / dist)
                val fy = force * (dy / dist)

                bi.vx += (fx / bi.mass) * dt
                bi.vy += (fy / bi.mass) * dt
                bj.vx -= (fx / bj.mass) * dt
                bj.vy -= (fy / bj.mass) * dt
            }
        }

        // Update positions based on velocities (orbital movement)
        for (v in variables) {
            v.x += v.vx * dt
            v.y += v.vy * dt
        }
    }

    println("--- Execution Completed ---")
    variables.forEach { println("Variable ${it.name} final value: ${it.value}") }
}