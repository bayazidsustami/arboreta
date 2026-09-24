import java.net.NetworkInterface
import java.util.Collections
import kotlin.math.sin
import kotlin.random.Random

// Represents an organic data packet stored within the mycelial network
data class HyphaNode(
    val id: Int,
    var payload: String,
    var x: Double,
    var y: Double,
    var vitality: Double = 1.0,
    val connectedBridges: MutableSet<Int> = mutableSetOf()
) {
    fun mutate(signalFactor: Double) {
        // Mutation is influenced by the environmental Wi-Fi fluctuation
        val chars = payload.toCharArray()
        if (chars.isNotEmpty() && Random.nextDouble() < (0.2 * signalFactor)) {
            val idx = Random.nextInt(chars.size)
            chars[idx] = (chars[idx].code + (if (Random.nextBoolean()) 1 else -1)).toChar()
            payload = String(chars)
        }
    }

    fun drift(signalFactor: Double) {
        // Spatial drift mimics organic spore/hyphae growth toward energy sources
        x += (Random.nextDouble() - 0.5) * 1.5 * signalFactor
        y += (Random.nextDouble() - 0.5) * 1.5 * signalFactor
        vitality = (vitality - 0.02).coerceAtLeast(0.1)
    }
}

// The Mycelium Memory Allocator
class MyceliumAllocator {
    private val network = mutableMapOf<Int, HyphaNode>()
    private var nextId = 0

    // Samples real-time local Wi-Fi or environmental entropy as a signal factor
    private fun getEnvironmentalSignal(): Double {
        return try {
            val interfaces = Collections.list(NetworkInterface.getNetworkInterfaces())
            var activeCount = 0
            for (ni in interfaces) {
                if (ni.isUp && !ni.isLoopback) activeCount++
            }
            // Use active interfaces combined with system time to model fluctuations
            val base = (activeCount + 1).toDouble()
            1.0 + (sin(System.currentTimeMillis() / 1000.0) * 0.5) * (base * 0.2)
        } catch (e: Exception) {
            1.0 + sin(System.currentTimeMillis() / 500.0) * 0.3
        }
    }

    fun allocate(data: String, initialX: Double, initialY: Double): Int {
        val id = nextId++
        network[id] = HyphaNode(id, data, initialX, initialY)
        println("[ALLOCATE] Spore node #$id planted at ($initialX, $initialY) with payload: '$data'")
        return id
    }

    fun pulse() {
        val signalFactor = getEnvironmentalSignal()
        println("\n--- Mycelial Pulse [Wi-Fi/Environmental Factor: Stringent %.2f] ---".format(signalFactor))

        // 1. Drift and Mutate Nodes
        for (node in network.values) {
            node.drift(signalFactor)
            node.mutate(signalFactor)
            node.vitality += 0.1 * signalFactor // Nourishment from signal
        }

        // 2. Form Symbiotic Bridges (Nodes close in space link up)
        val entries = network.values.toList()
        for (i in entries.indices) {
            for (j in i + 1 until entries.size) {
                val nodeA = entries[i]
                val nodeB = entries[j]
                val distance = kotlin.math.hypot(nodeA.x - nodeB.x, nodeA.y - nodeB.y)

                if (distance < 5.0 && signalFactor > 1.0) {
                    nodeA.connectedBridges.add(nodeB.id)
                    nodeB.connectedBridges.add(nodeA.id)
                    // Symbiotic memory pooling: share payload fragments
                    if (nodeA.payload.length == nodeB.payload.length && nodeA.payload != nodeB.payload) {
                        nodeA.payload = nodeA.payload.dropLast(1) + nodeB.payload.last()
                    }
                }
            }
        }

        // Print network status
        for (node in network.values) {
            println("Node #${node.id} | Pos: (%.1f, %.1f) | Vitality: %.2f | Bridges: %s | Payload: '%s'".format(
                node.x, node.y, node.vitality, node.connectedBridges, node.payload
            ))
        }
    }
}

fun main() {
    val allocator = MyceliumAllocator()

    // Plant initial data structures into the network
    allocator.allocate("CONFIG_ALPHA", 10.0, 10.0)
    allocator.allocate("STATE_VECTOR", 12.0, 11.0)
    allocator.allocate("CACHE_BUFFER", 50.0, 50.0)

    // Simulate life cycles over several organic pulses
    for (step in 1..4) {
        Thread.sleep(600)
        allocator.pulse()
    }
}