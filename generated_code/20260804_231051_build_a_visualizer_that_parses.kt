import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.sin
import kotlin.random.Random

/**
 * Git Ecosystem ASCII Visualizer
 *
 * Parses git commit history from the current directory (or generates simulated history
 * if not inside a Git repository) and renders an interactive, animated ASCII ecosystem.
 * - File extensions generate flora (trees, flowers, cacti, mushrooms).
 * - Commit frequencies drive weather patterns (sunny, rain, thunderstorm).
 * - Merge conflicts and churn manifest as localized natural disasters (volcanoes, wildfires).
 */

data class CommitInfo(
    val hash: String,
    val author: String,
    val timestamp: Long,
    val message: String,
    val modifiedFiles: List<String>,
    val isMerge: Boolean
)

data class EcosystemStats(
    val extensionCounts: Map<String, Int>,
    val commitsPerDay: Map<String, Int>,
    val mergeConflictsCount: Int,
    val totalCommits: Int,
    val topAuthors: List<Pair<String, Int>>
)

class GitParser {
    fun parseRepo(dir: File = File(".")): List<CommitInfo> {
        return try {
            val process = ProcessBuilder("git", "log", "--name-status", "--pretty=format:COMMIT:%H|%an|%at|%p|%s")
                .directory(dir)
                .redirectError(ProcessBuilder.Redirect.DISCARD)
                .start()

            val lines = process.inputStream.bufferedReader().readLines()
            process.waitFor()

            if (lines.isEmpty()) generateSyntheticHistory() else parseGitOutput(lines)
        } catch (e: Exception) {
            generateSyntheticHistory()
        }
    }

    private fun parseGitOutput(lines: List<String>): List<CommitInfo> {
        val commits = mutableListOf<CommitInfo>()
        var currentHash = ""
        var currentAuthor = ""
        var currentTimestamp = 0L
        var currentMessage = ""
        var isMerge = false
        val files = mutableListOf<String>()

        for (line in lines) {
            if (line.startsWith("COMMIT:")) {
                if (currentHash.isNotEmpty()) {
                    commits.add(CommitInfo(currentHash, currentAuthor, currentTimestamp, currentMessage, files.toList(), isMerge))
                    files.clear()
                }
                val parts = line.removePrefix("COMMIT:").split("|", limit = 5)
                currentHash = parts.getOrNull(0) ?: ""
                currentAuthor = parts.getOrNull(1) ?: "Unknown"
                currentTimestamp = parts.getOrNull(2)?.toLongOrNull() ?: System.currentTimeMillis()
                val parents = parts.getOrNull(3) ?: ""
                isMerge = parents.trim().split(" ").size > 1 || parts.getOrNull(4)?.contains("Merge", ignoreCase = true) == true
                currentMessage = parts.getOrNull(4) ?: ""
            } else if (line.isNotBlank() && (line.startsWith("M\t") || line.startsWith("A\t") || line.startsWith("D\t") || line.startsWith("C\t"))) {
                val filePath = line.split("\t").lastOrNull() ?: ""
                if (filePath.isNotBlank()) files.add(filePath)
            }
        }
        if (currentHash.isNotEmpty()) {
            commits.add(CommitInfo(currentHash, currentAuthor, currentTimestamp, currentMessage, files, isMerge))
        }
        return if (commits.isEmpty()) generateSyntheticHistory() else commits
    }

    private fun generateSyntheticHistory(): List<CommitInfo> {
        val extensions = listOf("kt", "md", "json", "rs", "py", "cpp", "css", "html", "sh")
        val authors = listOf("Alice", "Bob", "Charlie", "Dave")
        val now = System.currentTimeMillis() / 1000
        val random = Random(42)

        return (1..60).map { i ->
            val ext = extensions[random.nextInt(extensions.size)]
            val isMerge = random.nextDouble() < 0.18 || i % 10 == 0
            val msg = if (isMerge) "Merge branch 'feature/conflict-$i'" else "Refactor module $i"
            CommitInfo(
                hash = Integer.toHexString(random.nextInt()),
                author = authors[random.nextInt(authors.size)],
                timestamp = now - (60 - i) * 86400 / 3,
                message = msg,
                modifiedFiles = List(random.nextInt(1, 5)) { "src/File$it.$ext" },
                isMerge = isMerge
            )
        }
    }
}

class EcosystemEngine(val commits: List<CommitInfo>) {
    val stats: EcosystemStats

    init {
        val extMap = mutableMapOf<String, Int>()
        val dayMap = mutableMapOf<String, Int>()
        var merges = 0
        val authorMap = mutableMapOf<String, Int>()
        val formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd").withZone(ZoneId.systemDefault())

        for (c in commits) {
            if (c.isMerge || c.message.contains("conflict", ignoreCase = true)) merges++
            authorMap[c.author] = (authorMap[c.author] ?: 0) + 1

            val dateStr = formatter.format(Instant.ofEpochSecond(c.timestamp))
            dayMap[dateStr] = (dayMap[dateStr] ?: 0) + 1

            for (f in c.modifiedFiles) {
                val ext = f.substringAfterLast('.', "txt").lowercase()
                extMap[ext] = (extMap[ext] ?: 0) + 1
            }
        }

        stats = EcosystemStats(
            extensionCounts = extMap,
            commitsPerDay = dayMap,
            mergeConflictsCount = merges,
            totalCommits = commits.size,
            topAuthors = authorMap.toList().sortedByDescending { it.second }.take(3)
        )
    }

    fun getFloraSymbol(ext: String): String {
        return when (ext) {
            "kt", "java" -> "🌲" // Kotlin/Java -> Evergreen Tree
            "md", "txt" -> "🌸" // Docs -> Blossom
            "json", "yaml", "xml" -> "🌿" // Config -> Fern
            "rs", "c", "cpp" -> "🌵" // Systems -> Cactus
            "py", "js", "ts" -> "🍄" // Scripting -> Mushroom
            "html", "css" -> "🌻" // Web -> Sunflower
            "sh", "bat" -> "🌾" // Shell -> Reeds
            else -> "🌱" // Default -> Sprout
        }
    }

    fun getWeatherPattern(avgCommitsPerDay: Double): String {
        return when {
            avgCommitsPerDay > 5.0 -> "⛈️ THUNDERSTORM (High Velocity)"
            avgCommitsPerDay > 2.5 -> "🌧️ RAIN SHOWER (Steady Commits)"
            avgCommitsPerDay > 1.0 -> "🌤️ PARTLY CLOUDY (Normal Activity)"
            else -> "☀️ CLEAR SKIES (Quiet Repo)"
        }
    }
}

class AsciiRenderer(private val engine: EcosystemEngine) {
    private val width = 64
    private val height = 15
    private var frame = 0

    fun renderFrame() {
        frame++
        val stats = engine.stats
        val avgCommits = if (stats.commitsPerDay.isNotEmpty()) stats.totalCommits.toDouble() / stats.commitsPerDay.size else 1.0
        val weather = engine.getWeatherPattern(avgCommits)
        val disasterMode = stats.mergeConflictsCount > 2

        // Clear terminal frame using ANSI escape codes
        print("\u001B[H\u001B[2J")
        System.out.flush()

        val buffer = Array(height) { CharArray(width) { ' ' } }

        // Render Sky & Weather dynamics
        val isRaining = avgCommits > 2.0
        val isStormy = avgCommits > 5.0

        for (y in 0..4) {
            for (x in 0 until width) {
                val cloudDensity = sin((x + frame * 0.5) * 0.2) + sin((y + frame) * 0.3)
                if (cloudDensity > 0.8) {
                    buffer[y][x] = if (isStormy) '🌩' else '☁'
                } else if (isRaining && (x + y * 2 + frame) % 5 == 0 && y > 1) {
                    buffer[y][x] = if (isStormy) '⚡' else '💧'
                }
            }
        }

        // Render Ground/Terrain profile
        val groundY = 10
        for (x in 0 until width) {
            val terrainHeight = (sin((x + frame * 0.1) * 0.3) * 1.2).toInt()
            val yPos = groundY + terrainHeight
            if (yPos in 0 until height) {
                buffer[yPos][x] = '='
            }
        }

        val grid = buffer.map { String(it) }.toMutableList()

        // Distribute Flora across terrain based on repository extensions
        val floraList = mutableListOf<String>()
        val totalFiles = stats.extensionCounts.values.sum().coerceAtLeast(1)
        stats.extensionCounts.forEach { (ext, count) ->
            val symbol = engine.getFloraSymbol(ext)
            val countToPlace = ((count.toDouble() / totalFiles) * 20).toInt().coerceAtLeast(1)
            repeat(countToPlace) { floraList.add(symbol) }
        }
        floraList.shuffle(Random(1234))

        // Overlay Flora onto the landscape
        val floraLine = StringBuilder(" ".repeat(width))
        var fIndex = 0
        for (x in 2 until width - 2 step 3) {
            if (fIndex < floraList.size) {
                val symbol = floraList[fIndex++]
                if (x < floraLine.length) {
                    floraLine.replace(x, (x + symbol.length).coerceAtMost(width), symbol)
                }
            }
        }

        // Inject Natural Disaster visuals if merge conflicts exist
        var disasterBanner = ""
        if (disasterMode) {
            disasterBanner = "🔥 NATURAL DISASTER: ${stats.mergeConflictsCount} MERGE CONFLICTS DETECTED! 🔥"
            val sparkX = (frame * 3) % (width - 4)
            if (groundY - 1 >= 0 && sparkX < grid[groundY - 1].length - 1) {
                val chars = grid[groundY - 1].toCharArray()
                chars[sparkX] = '🌋'
                grid[groundY - 1] = String(chars)
            }
        }

        // Render Dashboard Header
        println("=" .repeat(width))
        println(" 🌌 GIT ECOSYSTEM VISUALIZER 🌌")
        println("=" .repeat(width))
        println("Weather: $weather")
        println("Commits: ${stats.totalCommits} | Merge Conflicts: ${stats.mergeConflictsCount}")
        val topAuthorsStr = stats.topAuthors.joinToString(", ") { "${it.first} (${it.second})" }
        println("Top Authors: $topAuthorsStr")
        println("-".repeat(width))

        // Render Animated Visual Horizon
        for (y in 0 until groundY - 1) {
            println(grid[y])
        }
        println(floraLine.toString())
        for (y in groundY until height - 2) {
            println(grid[y])
        }

        println("=" .repeat(width))
        if (disasterBanner.isNotEmpty()) {
            println(disasterBanner)
            println("=" .repeat(width))
        }
        println("Flora: 🌲 Kt/Java  🌸 Docs  🌿 Config  🌵 Native  🍄 Script  🌻 Web")
        println("Press Ctrl+C to exit. Frame #$frame")
    }
}

fun main() {
    println("Parsing Git repository history...")
    val parser = GitParser()
    val commits = parser.parseRepo()
    val engine = EcosystemEngine(commits)
    val renderer = AsciiRenderer(engine)

    println("Ecosystem initialized (${commits.size} commits). Starting simulation...")
    Thread.sleep(1000)

    try {
        while (true) {
            renderer.renderFrame()
            Thread.sleep(250)
        }
    } catch (e: InterruptedException) {
        println("\nSimulation ended.")
    }
}