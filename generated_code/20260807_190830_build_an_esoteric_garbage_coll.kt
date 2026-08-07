import java.lang.ref.WeakReference
import java.util.Random

/**
 * EsotericGarbageCollector: Scavenges heap-allocated String buffers and, upon 
 * an integer overflow, synthesizes rhyming 4-line stanzas (AABB or ABAB) from 
 * scavenged tokens.
 */
class EsotericGarbageCollector {
    private val scavengedTokens = mutableListOf<String>()
    private val random = Random()

    /**
     * Simulates memory scavenging by capturing strings from weak references
     * or active heap buffers.
     */
    fun scavenge(vararg references: WeakReference<String>) {
        for (ref in references) {
            ref.get()?.let { buffer ->
                // Tokenize words, removing punctuation and normalizing
                val words = buffer.split(Regex("\\s+"))
                    .map { it.replace(Regex("[^a-zA-Z]"), "").lowercase() }
                    .filter { it.length > 2 }
                scavengedTokens.addAll(words)
            }
        }
    }

    /**
     * Evaluates a safe addition. If an integer overflow occurs, triggers
     * the collection sweep and composes a rhyming four-line stanza.
     */
    fun safeAddAndSweepOnOverflow(a: Int, b: Int): Int {
        return try {
            Math.addExact(a, b)
        } catch (e: ArithmeticException) {
            triggerEsotericSweep(a, b)
            0 // Reset accumulator on overflow
        }
    }

    private fun triggerEsotericSweep(a: Int, b: Int) {
        println("\n=== [OVERFLOW DETECTED: $a + $b > Int.MAX_VALUE] ===")
        println("=== [INITIATING ESOTERIC GARBAGE COLLECTION SWEEP] ===\n")

        if (scavengedTokens.size < 4) {
            // Fallback emergency tokens if memory pool is depleted
            scavengedTokens.addAll(listOf("heap", "deep", "byte", "night", "code", "node", "stream", "dream"))
        }

        val stanza = composeRhymingStanza()
        println(stanza)
        
        // Clear consumed garbage
        scavengedTokens.clear()
        println("\n=== [SWEEP COMPLETE: Heap Restored to Equilibrium] ===\n")
    }

    private fun composeRhymingStanza(): String {
        // Group available tokens by their last 2 characters to approximate rhymes
        val rhymingGroups = scavengedTokens.distinct()
            .groupBy { it.takeLast(2) }
            .filter { it.value.size >= 2 }
            .values
            .toList()

        val (pairA, pairB) = if (rhymingGroups.size >= 2) {
            Pair(rhymingGroups[0].shuffled(random), rhymingGroups[1].shuffled(random))
        } else {
            // Synthesize phonetic rhymes if memory lacks sufficient sound-matched pairs
            Pair(listOf("light", "night"), listOf("heap", "deep"))
        }

        val line1 = buildLine(pairA[0])
        val line2 = buildLine(pairA[1])
        val line3 = buildLine(pairB[0])
        val line4 = buildLine(pairB[1])

        // Randomly choose AABB or ABAB stanza scheme
        return if (random.nextBoolean()) {
            "$line1\n$line2\n$line3\n$line4" // AABB
        } else {
            "$line1\n$line3\n$line2\n$line4" // ABAB
        }
    }

    private fun buildLine(endRhyme: String): String {
        val lineTemplates = listOf(
            "Lost within the discarded",
            "Fading shadows of a forgotten",
            "Reclaimed elements from the silent",
            "A shattered buffer echoes in the",
            "Swept away into the ancient",
            "Traces remain inside the digital"
        )
        val prefix = lineTemplates[random.nextInt(lineTemplates.size)]
        val filler = scavengedTokens.shuffled(random).firstOrNull() ?: "memory"
        return "$prefix $filler $endRhyme.".capitalize()
    }

    private fun String.capitalize() = replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
}

fun main() {
    val gc = EsotericGarbageCollector()

    // 1. Allocate strings and feed them to the garbage collector scavenger
    val memBuffer1 = String(charArrayOf('t', 'h', 'e', ' ', 'd', 'e', 'e', 'p', ' ', 'h', 'e', 'a', 'p'))
    val memBuffer2 = String(charArrayOf('f', 'a', 'd', 'e', 's', ' ', 'i', 'n', ' ', 't', 'h', 'e', ' ', 'n', 'i', 'g', 'h', 't'))
    val memBuffer3 = String(charArrayOf('s', 'i', 'l', 'e', 'n', 't', ' ', 's', 't', 'r', 'e', 'a', 'm', ' ', 'd', 'r', 'e', 'a', 'm'))
    val memBuffer4 = String(charArrayOf('a', 'l', 'l', ' ', 't', 'h', 'e', ' ', 'b', 'y', 't', 'e', ' ', 'l', 'i', 'g', 'h', 't'))

    gc.scavenge(
        WeakReference(memBuffer1),
        WeakReference(memBuffer2),
        WeakReference(memBuffer3),
        WeakReference(memBuffer4)
    )

    // 2. Perform arithmetic operations up to an integer overflow
    var register = Int.MAX_VALUE - 100
    println("Initial Register State: $register")

    // Increment gradually
    register = gc.safeAddAndSweepOnOverflow(register, 50)
    println("Register State after normal addition: $register")

    // Trigger Integer Overflow
    println("Triggering critical overflow addition...")
    register = gc.safeAddAndSweepOnOverflow(register, Integer.MAX_VALUE)
}