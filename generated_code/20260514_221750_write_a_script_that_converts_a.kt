import java.util.*

/**
 * A Markov Chain generator for surrealist poetry.
 * It builds a model of word transitions based on a provided corpus of lyrics.
 */
class SurrealistPoet(private val order: Int = 2) {
    // Maps a prefix (list of words) to a list of possible next words
    private val chain = mutableMapOf<List<String>, MutableList<String>>()
    private val allWords = mutableListOf<String>()

    /**
     * Trains the model using a collection of song lyrics.
     */
    fun train(lyrics: List<String>) {
        val words = lyrics.flatMap { it.lowercase().split(Regex("\\W+")).filter { w -> w.isNotBlank() } }
        allWords.addAll(words)

        if (words.size <= order) return

        for (i in 0 until words.size - order) {
            val state = words.subList(i, i + order)
            val nextWord = words[i + order]
            chain.getOrPut(state) { mutableListOf() }.add(nextWord)
        }
    }

    /**
     * Generates a new poem of a specified number of words.
     */
    fun generate(length: Int): String {
        if (allWords.isEmpty()) return "The silence is deafening."

        val result = mutableListOf<String>()
        // Start with a random sequence from the training data
        var currentState = allWords.shuffled().take(order) 
        // To ensure a valid start, find a state that actually exists in our chain
        val validStarts = chain.keys.toList()
        if (validStarts.isNotEmpty()) {
            currentState = validStarts.random()
        } else {
            return allWords.shuffled().take(length).joinToString(" ")
        }

        result.addAll(currentState)

        repeat(length - order) {
            val possibilities = chain[currentState]
            if (possibilities == null || possibilities.isEmpty()) {
                // If we hit a dead end, pick a new random starting state
                currentState = validStarts.random()
                result.addAll(currentState)
            } else {
                val nextWord = possibilities.random()
                result.add(nextWord)
                // Update the current state (sliding window)
                currentState = currentState.drop(1) + nextWord
            }
        }

        return result.take(length).joinToString(" ")
            .replaceFirstChar { it.uppercase() } + "."
    }
}

fun main() {
    // Sample corpus: A mix of different lyrical styles to create surrealist combinations
    val lyricsCorpus = listOf(
        "Electric blue neon dreams dancing in the velvet night",
        "The moon is a silver coin dropped in a well of stars",
        "Broken clocks ticking in the garden of forgotten echoes",
        "Velvet shadows whisper secrets to the digital rain",
        "Gravity is a heavy lie told by the spinning earth",
        "Neon ghosts haunt the circuits of a lonely heart",
        "Cyanide sugar melting on the tongue of the sun",
        "Whispering wires connect the dreams of sleeping gods",
        "The ocean breathes in rhythms of static and salt",
        "Fractal butterflies erupt from the pages of old books",
        "A kaleidoscope of shadows dancing on a porcelain sky",
        "Midnight electricity flows through the veins of the city"
    )

    // Initialize the poet with an order of 2 (looks at two words to predict the third)
    val poet = SurrealistPoet(order = 2)
    
    // Train the model
    poet.train(lyricsCorpus)

    println("--- SURREALIST POETRY GENERATOR ---")
    println("Style: Markov Chain (Order 2)\n")

    // Generate 3 different poems
    repeat(3) { i ->
        println("Poem #${i + 1}:")
        // Generate a poem roughly 20-30 words long
        val poem = poet.generate(25)
        
        // Format the output into pseudo-verses for aesthetic effect
        val words = poem.split(" ")
        words.chunked(5).forEach { line ->
            println(line.joinToString(" "))
        }
        println()
    }
}