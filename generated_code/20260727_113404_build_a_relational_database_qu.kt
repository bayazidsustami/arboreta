import java.util.Locale

// ============================================================================
// ZEN DATABASE: Haiku SQL Query Engine & Bonsai B-Tree Index Visualizer
// ============================================================================

/**
 * Syllable counter estimating English word syllables for Haiku verification (5-7-5 rule).
 */
fun countSyllables(text: String): Int {
    val words = text.lowercase(Locale.getDefault()).replace(Regex("[^a-z\\s]"), "").split("\\s+".toRegex()).filter { it.isNotEmpty() }
    return words.sumOf { word ->
        if (word.length <= 3) 1
        else {
            val cleaned = word.replace(Regex("(?:[^laeiouy]es|ed|e)$"), "")
            val count = Regex("[aeiouy]{1,2}").findAll(cleaned).count()
            if (count == 0) 1 else count
        }
    }
}

/**
 * Checks if a 3-line query conforms to the 5-7-5 syllable Haiku structure.
 */
fun validateHaiku(lines: List<String>): Boolean {
    if (lines.size != 3) return false
    val s1 = countSyllables(lines[0])
    val s2 = countSyllables(lines[1])
    val s3 = countSyllables(lines[2])
    println("  [Haiku Meter] Line 1: $s1/5 | Line 2: $s2/7 | Line 3: $s3/5")
    return s1 == 5 && s2 == 7 && s3 == 5
}

/**
 * Represents a row in our relational database.
 */
data class Record(val id: Int, val name: String, val age: Int)

/**
 * Living Bonsai B-Tree Node with aesthetic foliage and leaf-dropping GC mechanics.
 */
class BonsaiNode(val key: Int, val record: Record) {
    var left: BonsaiNode? = null
    var right: BonsaiNode? = null
    var height: Int = 1
    var foliage: String = "🌸" // Living leaf/cherry blossom
}

/**
 * Bonsai B-Tree (AVL/BST variant) Index that renders as an ASCII tree and drops leaves on GC.
 */
class BonsaiBTreeIndex {
    var root: BonsaiNode? = null

    fun insert(record: Record) {
        root = insertRec(root, record)
    }

    private fun insertRec(node: BonsaiNode?, record: Record): BonsaiNode {
        if (node == null) return BonsaiNode(record.id, record)
        if (record.id < node.key) {
            node.left = insertRec(node.left, record)
        } else if (record.id > node.key) {
            node.right = insertRec(node.right, record)
        }
        return node
    }

    fun find(id: Int): Record? {
        var curr = root
        while (curr != null) {
            if (id == curr.key) return curr.record
            curr = if (id < curr.key) curr.left else curr.right
        }
        return null
    }

    /**
     * Garbage Collection / Pruning trigger that drops leaves from the Bonsai Tree.
     */
    fun performGarbageCollection() {
        println("\n--- 🍂 GARBAGE COLLECTION TRIGGERED: AUTUMN WIND PASSES THROUGH BONSAI 🍂 ---")
        val fallenLeaves = mutableListOf<String>()
        fun drop(node: BonsaiNode?) {
            if (node == null) return
            if (node.foliage == "🌸") {
                node.foliage = "🌿"
                fallenLeaves.add("🍃")
            }
            drop(node.left)
            drop(node.right)
        }
        drop(root)
        println("Fallen Leaves Collected: ${fallenLeaves.joinToString(" ")}")
    }

    /**
     * Visualizes the B-tree as a growing Bonsai tree in ASCII art.
     */
    fun renderBonsai() {
        println("\n====== LIVING BONSAI B-TREE INDEX ======")
        if (root == null) {
            println("  [Empty Pot]")
            return
        }
        renderNode(root, "", true)
        println("       [====||||||||||====]")
        println("       \\_________________/")
        println("=========================================\n")
    }

    private fun renderNode(node: BonsaiNode?, prefix: String, isTail: Boolean) {
        if (node != null) {
            println(prefix + (if (isTail) "└── " else "├── ") + "${node.foliage} Node(${node.key}: ${node.record.name})")
            val children = listOfNotNull(node.left, node.right)
            for (i in children.indices) {
                renderNode(children[i], prefix + (if (isTail) "    " else "│   "), i == children.size - 1)
            }
        }
    }
}

/**
 * Zen Database Engine processing Haiku SQL queries.
 */
class ZenDatabaseEngine {
    private val index = BonsaiBTreeIndex()
    private val table = mutableMapOf<Int, Record>()

    fun insert(record: Record) {
        table[record.id] = record
        index.insert(record)
    }

    fun getIndex(): BonsaiBTreeIndex = index

    fun executeHaikuQuery(haikuQuery: String) {
        println("========================================")
        println("EXAMINING QUERY POEM:")
        println(haikuQuery.trimIndent())
        println("----------------------------------------")

        val lines = haikuQuery.trim().lines().map { it.trim() }.filter { it.isNotEmpty() }
        
        if (!validateHaiku(lines)) {
            println("❌ QUERY REJECTED: The query lacks 5-7-5 syllable harmony. Zen balance broken.")
            return
        }

        println("✅ HAIKU VALIDATED! Executing query...")
        
        // Simple extraction logic for demo execution based on poem keywords
        val fullQuery = lines.joinToString(" ").uppercase(Locale.getDefault())
        when {
            "SELECT" in fullQuery && "WHERE" in fullQuery -> {
                val match = Regex("ID IS (\\d+)").find(fullQuery)
                val targetId = match?.groupValues?.get(1)?.toIntOrNull() ?: 10
                val result = index.find(targetId)
                println("Query Result -> $result")
            }
            "DELETE" in fullQuery || "CLEAN" in fullQuery || "PRUNE" in fullQuery -> {
                index.performGarbageCollection()
            }
            else -> {
                println("Query executed: All table records retrieved -> ${table.values}")
            }
        }
    }
}

fun main() {
    val db = ZenDatabaseEngine()

    // Populate database
    db.insert(Record(5, "Kenji", 24))
    db.insert(Record(2, "Aoi", 30))
    db.insert(Record(8, "Ren", 19))
    db.insert(Record(1, "Hana", 27))
    db.insert(Record(10, "Sora", 35))

    println("Initial Bonsai B-Tree Index Structure:")
    db.getIndex().renderBonsai()

    // Query 1: Valid 5-7-5 Haiku SQL Query
    val validHaikuQuery = """
        Select name from user
        Where id is ten right now
        Give me data back
    """
    db.executeHaikuQuery(validHaikuQuery)

    // Query 2: Garbage Collection / Pruning Haiku Query
    val gcHaikuQuery = """
        Prune the fallen foliage
        Clean all dirty memory
        Leaves drop to the floor
    """
    db.executeHaikuQuery(gcHaikuQuery)

    // Render Bonsai after GC
    db.getIndex().renderBonsai()

    // Query 3: Invalid Haiku Query (wrong syllable count)
    val invalidHaikuQuery = """
        Select everything from database table
        Where id equals one
        Return output
    """
    db.executeHaikuQuery(invalidHaikuQuery)
}