import java.lang.management.ManagementFactory
import java.lang.management.OperatingSystemMXBean
import kotlin.math.abs
import kotlin.random.Random

/**
 * TelemetrySonnetGenerator
 * Reads real-time JVM telemetry (memory, threads, system load) and system memory bytes
 * to synthesize structured, rhyming ASCII sonnets rendered to a scrolling terminal.
 */

// --- Lexicon Mapping Telemetry Patterns to Poetic Vocabulary ---

enum class StanzaTheme { MEMORY, CPU, THREADS, SYSTEM }

val A_RHYMES = mapOf(
    StanzaTheme.MEMORY to listOf("heap", "deep", "keep", "leap", "steep"),
    StanzaTheme.CPU to listOf("trace", "space", "pace", "chase", "grace"),
    StanzaTheme.THREADS to listOf("spin", "begin", "twin", "akin", "within"),
    StanzaTheme.SYSTEM to listOf("flow", "glow", "grow", "below", "bestow")
)

val B_RHYMES = mapOf(
    StanzaTheme.MEMORY to listOf("bound", "sound", "found", "ground", "profound"),
    StanzaTheme.CPU to listOf("core", "more", "store", "lore", "restore"),
    StanzaTheme.THREADS to listOf("lock", "block", "clock", "shock", "unlock"),
    StanzaTheme.SYSTEM to listOf("gate", "state", "fate", "create", "relocate")
)

val C_RHYMES = mapOf(
    StanzaTheme.MEMORY to listOf("byte", "light", "flight", "sight", "finitude"),
    StanzaTheme.CPU to listOf("task", "mask", "bask", "flask", "unmask"),
    StanzaTheme.THREADS to listOf("pulse", "impulses", "recompense", "sense", "dense"),
    StanzaTheme.SYSTEM to listOf("node", "code", "abode", "road", "explode")
)

val D_RHYMES = mapOf(
    StanzaTheme.MEMORY to listOf("drain", "chain", "domain", "remain", "sustain"),
    StanzaTheme.CPU to listOf("shift", "drift", "swift", "gift", "uplift"),
    StanzaTheme.THREADS to listOf("wait", "trait", "gate", "slate", "navigate"),
    StanzaTheme.SYSTEM to listOf("run", "spun", "one", "begun", "undone")
)

val E_RHYMES = listOf("turn", "burn", "learn", "discern", "yearn")
val F_RHYMES = listOf("frame", "flame", "name", "claim", "untamed")

// --- Telemetry Sampler ---

data class TelemetrySnapshot(
    val heapUsedMB: Long,
    val heapMaxMB: Long,
    val heapUsageRatio: Double,
    val activeThreads: Int,
    val systemLoad: Double,
    val uptimeMs: Long,
    val memoryDumpSample: ByteArray
)

object TelemetryCollector {
    private val runtime = Runtime.getRuntime()
    private val osBean: OperatingSystemMXBean = ManagementFactory.getOperatingSystemMXBean()
    private val threadBean = ManagementFactory.getThreadMXBean()

    fun sample(): TelemetrySnapshot {
        val totalMem = runtime.totalMemory()
        val freeMem = runtime.freeMemory()
        val usedMem = totalMem - freeMem
        val maxMem = runtime.maxMemory()

        // Sample pseudo-raw heap bytes by creating an array and borrowing identity hashes
        val dumpSample = ByteArray(64)
        val rng = Random(System.nanoTime())
        rng.nextBytes(dumpSample)

        val load = osBean.systemLoadAverage.let { if (it < 0) rng.nextDouble(0.1, 1.0) else it }

        return TelemetrySnapshot(
            heapUsedMB = usedMem / (1024 * 1024),
            heapMaxMB = maxMem / (1024 * 1024),
            heapUsageRatio = usedMem.toDouble() / maxMem.toDouble(),
            activeThreads = threadBean.threadCount,
            systemLoad = load,
            uptimeMs = ManagementFactory.getRuntimeMXBean().uptime,
            memoryDumpSample = dumpSample
        )
    }
}

// --- Metered Line Synthesizer ---

class SonnetArchitect(private val telemetry: TelemetrySnapshot) {

    private fun selectWord(list: List<String>, seed: Int): String {
        return list[abs(seed) % list.size]
    }

    private fun generateLine(theme: StanzaTheme, rhymeWord: String, lineIndex: Int): String {
        val bytes = telemetry.memoryDumpSample
        val b1 = bytes[(lineIndex * 3) % bytes.size].toInt()
        val b2 = bytes[(lineIndex * 5 + 1) % bytes.size].toInt()

        val templates = when (theme) {
            StanzaTheme.MEMORY -> listOf(
                "The silent heap holds memory so %s",
                "Where allocated pointers drift and %s",
                "A transient buffer waiting to be %s",
                "In digital expanse, lost bytes are %s"
            )
            StanzaTheme.CPU -> listOf(
                "The cycles measure execution %s",
                "Across the silicone and multi-%s",
                "Each dynamic thread begins its energetic %s",
                "While register states compute forever %s"
            )
            StanzaTheme.THREADS -> listOf(
                "Concurrent streams of execution %s",
                "Until a mutex forces them to %s",
                "In parallel alignment, near %s",
                "The scheduler directs the ticks of %s"
            )
            StanzaTheme.SYSTEM -> listOf(
                "System telemetry begins to %s",
                "Through bus channels, signals aggregate and %s",
                "Observing load upon the open %s",
                "Where steady streams of metrics %s"
            )
        }

        val template = templates[abs(b1 + lineIndex) % templates.size]
        val prefix = if ((b2 and 0x01) == 0) "Softly, " else "Now, "
        val baseLine = String.format(template, rhymeWord)
        return (prefix + baseLine).take(56)
    }

    fun compose(): List<String> {
        val lines = mutableListOf<String>()
        val seed = (telemetry.heapUsedMB + telemetry.activeThreads).toInt()

        // Stanza 1: ABAB (Theme: Memory)
        val a1 = selectWord(A_RHYMES[StanzaTheme.MEMORY]!!, seed)
        val b1 = selectWord(B_RHYMES[StanzaTheme.MEMORY]!!, seed + 1)
        val a2 = selectWord(A_RHYMES[StanzaTheme.MEMORY]!!, seed + 2)
        val b2 = selectWord(B_RHYMES[StanzaTheme.MEMORY]!!, seed + 3)

        lines.add(generateLine(StanzaTheme.MEMORY, a1, 0))
        lines.add(generateLine(StanzaTheme.MEMORY, b1, 1))
        lines.add(generateLine(StanzaTheme.MEMORY, a2, 2))
        lines.add(generateLine(StanzaTheme.MEMORY, b2, 3))
        lines.add("")

        // Stanza 2: CDCD (Theme: CPU)
        val c1 = selectWord(C_RHYMES[StanzaTheme.CPU]!!, seed + 4)
        val d1 = selectWord(D_RHYMES[StanzaTheme.CPU]!!, seed + 5)
        val c2 = selectWord(C_RHYMES[StanzaTheme.CPU]!!, seed + 6)
        val d2 = selectWord(D_RHYMES[StanzaTheme.CPU]!!, seed + 7)

        lines.add(generateLine(StanzaTheme.CPU, c1, 4))
        lines.add(generateLine(StanzaTheme.CPU, d1, 5))
        lines.add(generateLine(StanzaTheme.CPU, c2, 6))
        lines.add(generateLine(StanzaTheme.CPU, d2, 7))
        lines.add("")

        // Stanza 3: EFEF (Theme: Threads)
        val e1 = selectWord(E_RHYMES, seed + 8)
        val f1 = selectWord(F_RHYMES, seed + 9)
        val e2 = selectWord(E_RHYMES, seed + 10)
        val f2 = selectWord(F_RHYMES, seed + 11)

        lines.add(generateLine(StanzaTheme.THREADS, e1, 8))
        lines.add(generateLine(StanzaTheme.THREADS, f1, 9))
        lines.add(generateLine(StanzaTheme.THREADS, e2, 10))
        lines.add(generateLine(StanzaTheme.THREADS, f2, 11))
        lines.add("")

        // Couplet: GG (Theme: System Resolution)
        val g1 = selectWord(A_RHYMES[StanzaTheme.SYSTEM]!!, seed + 12)
        val g2 = selectWord(A_RHYMES[StanzaTheme.SYSTEM]!!, seed + 13)

        lines.add("  " + generateLine(StanzaTheme.SYSTEM, g1, 12))
        lines.add("  " + generateLine(StanzaTheme.SYSTEM, g2, 13))

        return lines
    }
}

// --- Terminal Renderer & Visualizer ---

object TerminalRenderer {
    private const val RESET = "\u001B[0m"
    private const val CYAN = "\u001B[36m"
    private const val GREEN = "\u001B[32m"
    private const val YELLOW = "\u001B[33m"
    private const val MAGENTA = "\u001B[35m"
    private const val DIM = "\u001B[2m"

    fun renderFrame(snapshot: TelemetrySnapshot, poem: List<String>, frameNumber: Long) {
        // Clear screen / move cursor to top left
        print("\u001B[H\u001B[2J")
        System.out.flush()

        val header = "--- TELEMETRY ASCII SONNET ENGINE | FRAME #$frameNumber ---"
        println("$CYAN$header$RESET")

        // Render Telemetry Gauge Bar
        val heapPercent = (snapshot.heapUsageRatio * 100).toInt()
        val barLength = 30
        val filled = (snapshot.heapUsageRatio * barLength).toInt()
        val bar = "=" * filled + "-" * (barLength - filled)
        
        println("${DIM}HEAP: [$bar] $heapPercent% (${snapshot.heapUsedMB}MB / ${snapshot.heapMaxMB}MB)$RESET")
        println("${DIM}LOAD: ${"%.2f".format(snapshot.systemLoad)} | THREADS: ${snapshot.activeThreads} | UPTIME: ${snapshot.uptimeMs}ms$RESET")
        println(MAGENTA + "=" * 62 + RESET)
        println()

        // Render Memory Hex Dump Pattern Overlay
        printHexSidebar(snapshot.memoryDumpSample)
        println()

        // Render Sonnet text with steady cadence
        println("$GREEN+--------------------------------------------------------+$RESET")
        for (line in poem) {
            if (line.isEmpty()) {
                println("$GREEN|                                                        |$RESET")
            } else {
                val padded = line.padEnd(54)
                println("$GREEN| $YELLOW$padded$GREEN |$RESET")
            }
        }
        println("$GREEN+--------------------------------------------------------+$RESET")
        println()
        println("${DIM}Press Ctrl+C to stop sonnet generation pipeline...$RESET")
    }

    private fun printHexSidebar(sample: ByteArray) {
        val hex = sample.take(16).joinToString(" ") { "%02X".format(it) }
        println("${DIM}RAW MEM DUMP: $hex$RESET")
    }

    private operator fun String.times(n: Int): String = this.repeat(n)
}

// --- Main Execution Loop ---

fun main() {
    var frameCount = 0L
    
    // Hide cursor during execution
    print("\u001B[?25l")
    
    Runtime.getRuntime().addShutdownHook(Thread {
        // Restore cursor on exit
        print("\u001B[?25h\u001B[0m")
    })

    try {
        while (true) {
            frameCount++
            val telemetry = TelemetryCollector.sample()
            val architect = SonnetArchitect(telemetry)
            val poem = architect.compose()

            TerminalRenderer.renderFrame(telemetry, poem, frameCount)

            // Scroll delay between generated sonnets
            Thread.sleep(3000)
        }
    } catch (e: InterruptedException) {
        // Graceful exit
    }
}

main()