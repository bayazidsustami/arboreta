import java.io.BufferedReader
import java.io.InputStreamReader
import kotlin.math.abs
import kotlin.math.sqrt

// Data class representing a Git commit with sentiment metadata
data class Commit(
    val hash: String,
    val message: String,
    val author: String,
    val sentimentScore: Double
)

// ANSI color codes for terminal rendering of emotional states
object AnsiColor {
    const val RESET = "\u001B[0m"
    const val RED = "\u001B[31m"    // High emotional volatility / frustration
    const val GREEN = "\u001B[32m"  // Calm, positive, steady progress
    const val YELLOW = "\u001B[33m" // Moderate fluctuation / caution
    const val BLUE = "\u001B[34m"   // Deep focus / structural refactoring
    const val MAGENTA = "\u001B[35m"// Extreme volatility spikes
    const val BOLD = "\u001B[1m"
}

fun main(args: Array<String>) {
    println("${AnsiColor.BOLD}🌿 Git Bonsai Forest & Emotional Volatility Visualizer 🌿${AnsiColor.RESET}\n")
    
    // Fetch commit history from local repository or fallback to a simulated history if not in a git repo
    val commits = fetchGitCommits()
    if (commits.isEmpty()) {
        println("No commits found or not a git repository. Generating simulated bonsai data...")
    }
    
    val processedCommits = if (commits.isEmpty()) generateMockCommits() else commits
    
    // Group commits into conceptual "branches" (batches of 10 commits or per author)
    val commitBatches = processedCommits.chunked(10)
    
    commitBatches.forEachIndexed { index, batch ->
        println("Bonsai Tree #${index + 1} (Commits: ${batch.first().hash.take(7)} ... ${batch.last().hash.take(7)})")
        renderBonsaiTree(batch)
        println("------------------------------------------------------------------\n")
    }
}

// Executes 'git log' to extract recent commit history
fun fetchGitCommits(): List<Commit> {
    val commits = mutableListOf<Commit>()
    try {
        val process = ProcessBuilder("git", "log", "--pretty=format:%h|%s|%an", "-n", "50")
            .redirectErrorStream(true)
            .start()
        
        val reader = BufferedReader(InputStreamReader(process.inputStream))
        var line: String?
        while (reader.readLine().also { line = it } != null) {
            val parts = line!!.split("|")
            if (parts.size >= 3) {
                val hash = parts[0]
                val message = parts[1]
                val author = parts[2]
                val sentiment = analyzeSentiment(message)
                commits.add(Commit(hash, message, author, sentiment))
            }
        }
        process.waitFor()
    } catch (e: Exception) {
        // Fallback handled by caller if empty
    }
    return commits
}

// Heuristic sentiment analysis mapping commit intent to emotional polarity (-2.0 to 2.0)
fun analyzeSentiment(message: String): Double {
    val lower = message.lowercase()
    val positiveKeywords = listOf("fix", "feature", "add", "clean", "perf", "speed", "happy", "update", "resolve", "good", "success")
    val negativeKeywords = listOf("bug", "error", "fail", "crash", "hotfix", "damn", "broken", "issue", "wtf", "revert", "panic", "slow")
    
    var score = 0.0
    positiveKeywords.forEach { if (lower.contains(it)) score += 1.0 }
    negativeKeywords.forEach { if (lower.contains(it)) score -= 1.5 }
    
    // Length penalty/bonus for expressive rants vs terse notes
    if (message.length > 80) score -= 0.2
    return score
}

// Generates fallback mock commits if git history is unavailable
fun generateMockCommits(): List<Commit> {
    return listOf(
        Commit("a1b2c3d", "Initial structure setup", "Alice", 0.5),
        Commit("e4f5g6h", "WIP testing basic parser", "Bob", -0.5),
        Commit("i7j8k9l", "Fix critical null pointer exception crash!", "Alice", -2.0),
        Commit("m0n1o2p", "Refactor core architecture for better performance", "Charlie", 1.5),
        Commit("q3r4s5t", "Damn it another build failure in CI", "Bob", -2.5),
        Commit("u6v7w8x", "Finally resolved merge conflicts successfully", "Alice", 2.0)
    )
}

// Calculates standard deviation of sentiment scores to represent emotional volatility
fun calculateVolatility(commits: List<Commit>): Double {
    if (commits.size <= 1) return 0.0
    val mean = commits.map { it.sentimentScore }.average()
    val variance = commits.map { (it.sentimentScore - mean) * (it.sentimentScore - mean) }.sum() / commits.size
    return sqrt(variance)
}

// Renders an ASCII bonsai tree with foliage colored by emotional volatility
fun renderBonsaiTree(commits: List<Commit>) {
    val volatility = calculateVolatility(commits)
    val avgSentiment = commits.map { it.sentimentScore }.average()
    
    // Choose leaf color based on volatility and sentiment
    val leafColor = when {
        volatility > 1.2 -> AnsiColor.MAGENTA // High volatility turbulence
        avgSentiment < -0.5 -> AnsiColor.RED   // Frustrated / bug-heavy cluster
        avgSentiment > 0.5 -> AnsiColor.GREEN  // Smooth, positive progress
        else -> AnsiColor.YELLOW               // Cautious / mixed state
    }
    
    val trunkColor = AnsiColor.BLUE
    
    println("  Volatility Index: %.2f | Sentiment Tone: %.2f".format(volatility, avgSentiment))
    println()
    
    // Artistic ASCII Bonsai representation shaped dynamically
    val treeStructure = listOf(
        "       __.---.__",
        "    .-'          '-.",
        "   /  {LEAVES}      \\",
        "  (_  {LEAVES}    _)",
        "    `'-.____.-'`",
        "         |||",
        "         |||",
        "       __|||__"
    )
    
    // Generate foliage visual blocks from commit messages
    val leafText = commits.joinToString(" ") { it.message.take(6) }
    
    for (line in treeStructure) {
        if (line.contains("{LEAVES}")) {
            val formattedLine = line.replace("{LEAVES}", "$leafColor$leafText${AnsiColor.RESET}")
            println("    $formattedLine")
        } else if (line.contains("|||")) {
            println("    $trunkColor$line${AnsiColor.RESET}")
        } else {
            println("    $leafColor$line${AnsiColor.RESET}")
        }
    }
}