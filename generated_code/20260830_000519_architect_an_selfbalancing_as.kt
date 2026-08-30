import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random

enum class Gene(val symbol: Char) {
    CONSUMER('C'), PRODUCER('P'), PREDATOR('X'), SHIELD('S'), REPLICATOR('R')
}

data class Organism(
    val id: Int,
    var dna: MutableList<Gene>,
    var energy: Long,
    var age: Int = 0,
    var x: Int,
    var y: Int
) {
    val glyph: Char
        get() = when {
            dna.contains(Gene.PREDATOR) -> 'X'
            dna.contains(Gene.PRODUCER) -> 'P'
            dna.contains(Gene.REPLICATOR) -> 'R'
            dna.contains(Gene.SHIELD) -> '#'
            else -> 'o'
        }
}

class TerminalEcosystem(private val width: Int = 60, private val height: Int = 20) {
    private val runtime = Runtime.getRuntime()
    private val grid = Array(height) { CharArray(width) { ' ' } }
    private val organisms = mutableListOf<Organism>()
    private var nextId = 1

    init {
        repeat(15) {
            val initialDna = mutableListOf(
                Gene.entries.toTypedArray().random(),
                Gene.entries.toTypedArray().random()
            )
            organisms.add(
                Organism(
                    id = nextId++,
                    dna = initialDna,
                    energy = 200,
                    x = Random.nextInt(width),
                    y = Random.nextInt(height)
                )
            )
        }
    }

    private fun getMetabolicEnergy(): Long {
        val totalMemory = runtime.totalMemory()
        val freeMemory = runtime.freeMemory()
        val usedMemory = totalMemory - freeMemory
        return max(10L, (freeMemory.toDouble() / totalMemory.toDouble() * 100).toLong())
    }

    fun step() {
        val metabolicBase = getMetabolicEnergy()
        val iterator = organisms.iterator()

        val occupied = mutableMapOf<Pair<Int, Int>, Organism>()
        val newOrganisms = mutableListOf<Organism>()

        while (iterator.hasNext()) {
            val org = iterator.next()
            org.age++

            val cost = org.dna.size * 2L
            org.energy -= cost
            org.energy += (metabolicBase / 5)

            if (org.energy <= 0 || org.age > 100) {
                iterator.remove()
                continue
            }

            val dx = Random.nextInt(-1, 2)
            val dy = Random.nextInt(-1, 2)
            org.x = (org.x + dx + width) % width
            org.y = (org.y + dy + height) % height

            val pos = Pair(org.x, org.y)
            if (occupied.containsKey(pos)) {
                val other = occupied[pos]!!
                if (org.dna.contains(Gene.PREDATOR) && !other.dna.contains(Gene.SHIELD)) {
                    org.energy += other.energy
                    other.energy = 0
                } else if (org.dna.contains(Gene.PRODUCER)) {
                    org.energy += 10
                    other.energy += 10
                }
            } else {
                occupied[pos] = org
            }

            if (org.energy > 300 && org.dna.contains(Gene.REPLICATOR)) {
                org.energy /= 2
                val childDna = org.dna.toMutableList()
                if (Random.nextDouble() < 0.3) {
                    if (childDna.size > 1 && Random.nextBoolean()) {
                        childDna.removeAt(Random.nextInt(childDna.size))
                    } else {
                        childDna.add(Gene.entries.toTypedArray().random())
                    }
                }
                newOrganisms.add(
                    Organism(
                        id = nextId++,
                        dna = childDna,
                        energy = org.energy,
                        x = (org.x + Random.nextInt(-1, 2) + width) % width,
                        y = (org.y + Random.nextInt(-1, 2) + height) % height
                    )
                )
            }
        }

        organisms.addAll(newOrganisms)

        if (organisms.size < 5) {
            repeat(3) {
                organisms.add(
                    Organism(
                        id = nextId++,
                        dna = mutableListOf(Gene.PRODUCER, Gene.REPLICATOR),
                        energy = 150,
                        x = Random.nextInt(width),
                        y = Random.nextInt(height)
                    )
                )
            }
        }
    }

    fun render() {
        for (y in 0 until height) {
            for (x in 0 until width) {
                grid[y][x] = '.'
            }
        }

        for (org in organisms) {
            grid[org.y][org.x] = org.glyph
        }

        print("\u001B[H\u001B[2J")
        System.out.flush()

        val totalMem = runtime.totalMemory() / (1024 * 1024)
        val freeMem = runtime.freeMemory() / (1024 * 1024)
        val usedMem = totalMem - freeMem

        println("=== ASCII ECOSYSTEM | Heap: ${usedMem}MB / ${totalMem}MB | Organisms: ${organisms.size} ===")
        println("+" + "-".repeat(width) + "+")
        for (y in 0 until height) {
            print("|")
            print(String(grid[y]))
            println("|")
        }
        println("+" + "-".repeat(width) + "+")
        println("Legend: P=Producer, X=Predator, R=Replicator, #=Shield, o=Consumer")
    }
}

fun main() {
    val eco = TerminalEcosystem()
    val executor = Executors.newSingleThreadScheduledExecutor()

    executor.scheduleAtFixedRate({
        try {
            eco.step()
            eco.render()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }, 0, 150, TimeUnit.MILLISECONDS)
}