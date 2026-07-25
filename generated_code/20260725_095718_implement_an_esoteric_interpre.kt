import javax.sound.sampled.*
import javax.swing.*
import java.awt.*
import java.awt.event.*
import java.io.BufferedReader
import java.io.InputStreamReader
import kotlin.math.*
import kotlin.concurrent.thread

/**
 * Esoteric Git Interpreter: Microtonal Lullabies & Call-Stack Bonsai Renderer
 *
 * Translates Git commit histories into microtonal lullaby frequencies while
 * dynamically rendering an interactive digital bonsai tree representing stack execution.
 */

data class Commit(val hash: String, val author: String, val message: String, val timestamp: Long)

class MicrotonalAudioEngine {
    private val sampleRate = 44100f
    private val line: SourceDataLine

    init {
        val format = AudioFormat(sampleRate, 16, 1, true, true)
        val info = DataLine.Info(SourceDataLine::class.java, format)
        line = AudioSystem.getLine(info) as SourceDataLine
        line.open(format, 44100)
        line.start()
    }

    // Synthesizes soothing microtonal sine waves using microtonal pitch steps
    fun playMicrotone(frequencyHz: Double, durationMs: Int, volume: Float = 0.25f) {
        val numSamples = (sampleRate * (durationMs / 1000.0)).toInt()
        val buffer = ByteArray(numSamples * 2)
        val attackSamples = (numSamples * 0.20).toInt()
        val releaseSamples = (numSamples * 0.40).toInt()

        for (i in 0 until numSamples) {
            val t = i / sampleRate.toDouble()
            // Sine fundamental plus soft harmonic overtone for lullaby quality
            val sine1 = sin(2.0 * PI * frequencyHz * t)
            val sine2 = sin(2.0 * PI * (frequencyHz * 2.003) * t) * 0.2
            val sampleVal = sine1 + sine2

            // Envelope calculation for soft attack and decay
            val envelope = when {
                i < attackSamples -> i.toDouble() / attackSamples
                i > numSamples - releaseSamples -> (numSamples - i).toDouble() / releaseSamples
                else -> 1.0
            }

            val scaled = (sampleVal * envelope * volume * 32767).toInt().coerceIn(-32768, 32767)
            buffer[i * 2] = (scaled shr 8).toByte()
            buffer[i * 2 + 1] = scaled.toByte()
        }
        line.write(buffer, 0, buffer.size)
    }

    fun close() {
        line.drain()
        line.close()
    }
}

class StackNode(
    val name: String,
    val commit: Commit,
    val depth: Int,
    val angle: Double,
    val length: Double
) {
    val children = mutableListOf<StackNode>()
    var growthRatio = 0.0
}

class BonsaiPanel : JPanel() {
    var rootNode: StackNode? = null

    init {
        background = Color(18, 22, 20)
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        val g2d = g as Graphics2D
        g2d.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        // Draw Pot Base
        g2d.color = Color(40, 30, 25)
        g2d.fillRoundRect(width / 2 - 80, height - 40, 160, 30, 15, 15)

        val root = rootNode ?: return
        drawNode(g2d, root, width / 2.0, height - 40.0)
    }

    private fun drawNode(g2d: Graphics2D, node: StackNode, startX: Double, startY: Double) {
        val currentLen = node.length * node.growthRatio
        val endX = startX + currentLen * sin(node.angle)
        val endY = startY - currentLen * cos(node.angle)

        // Draw Recursive Branch Frame
        val strokeWidth = max(1.0f, 9.0f - node.depth * 1.2f)
        g2d.stroke = BasicStroke(strokeWidth, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)
        g2d.color = Color(110 - node.depth * 8, 75 - node.depth * 4, 45)
        g2d.drawLine(startX.toInt(), startY.toInt(), endX.toInt(), endY.toInt())

        // Render Leaves / Microtonal Blossoms
        if (node.children.isEmpty() || node.depth > 2) {
            g2d.color = Color(140 + (node.depth * 15) % 80, 200, 150, 170)
            val blossomSize = 6 + node.commit.hash.hashCode() % 8
            g2d.fillOval((endX - blossomSize / 2).toInt(), (endY - blossomSize / 2).toInt(), blossomSize, blossomSize)
        }

        // Render Call Frame Metadata
        if (node.growthRatio > 0.6) {
            g2d.color = Color(180, 210, 190, 160)
            g2d.font = Font("Monospaced", Font.PLAIN, 10)
            g2d.drawString("${node.name}:${node.commit.hash.take(6)}", endX.toInt() + 6, endY.toInt())
        }

        for (child in node.children) {
            drawNode(g2d, child, endX, endY)
        }
    }
}

class EsotericGitInterpreter {
    private val audio = MicrotonalAudioEngine()
    private val bonsaiPanel = BonsaiPanel()
    private val frame = JFrame("Git Commit Microtonal Lullaby Call Stack Bonsai")

    init {
        frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
        frame.size = Dimension(900, 700)
        frame.add(bonsaiPanel)
        frame.setLocationRelativeTo(null)
        frame.isVisible = true
    }

    private fun fetchGitCommits(): List<Commit> {
        val commits = mutableListOf<Commit>()
        try {
            val process = Runtime.getRuntime().exec("git log --pretty=format:%H|%an|%s|%at -n 16")
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                val parts = line!!.split("|")
                if (parts.size >= 4) {
                    commits.add(Commit(parts[0], parts[1], parts[2], parts[3].toLongOrNull() ?: 0L))
                }
            }
        } catch (_: Exception) {}

        // Fallback procedural commit generation if git repo is absent
        if (commits.isEmpty()) {
            val authors = listOf("Ada", "Turing", "Lovelace", "Church", "Euler")
            val msgs = listOf("init dream", "pitch bend", "refactor microtone", "stack blossom", "sleep merge")
            for (i in 0 until 14) {
                val hash = (0..39).map { "0123456789abcdef".random() }.joinToString("")
                commits.add(Commit(hash, authors[i % authors.size], msgs[i % msgs.size], System.currentTimeMillis() - i * 3600))
            }
        }
        return commits
    }

    // Translates hash to microtonal pitch using 31-TET (Thirty-One Equal Temperament) microtonal scale
    private fun hashToMicrotoneFreq(hash: String, index: Int): Double {
        val baseFreq = 220.0 // A3 reference pitch
        val byteVal = hash.substring((index * 2) % (hash.length - 2), ((index * 2) % (hash.length - 2)) + 2).toIntOrNull(16) ?: 31
        val microStep = byteVal % 31 // Microtonal scale division
        return baseFreq * 2.0.pow(microStep / 31.0)
    }

    fun interpretAndPerform() {
        val commits = fetchGitCommits()
        val rootNode = StackNode("main()", commits.first(), 0, 0.0, 85.0)
        bonsaiPanel.rootNode = rootNode

        thread {
            var currentParent = rootNode
            for ((index, commit) in commits.withIndex()) {
                val depth = (index % 4) + 1
                val angleOffset = ((commit.hash.hashCode() % 50) - 25) * (PI / 180.0)
                val nodeName = "stackFrame_${commit.author.lowercase().replace(" ", "_")}"
                val newNode = StackNode(nodeName, commit, depth, currentParent.angle + angleOffset, 65.0 - depth * 7)

                if (depth == 1) {
                    rootNode.children.add(newNode)
                } else {
                    currentParent.children.add(newNode)
                }
                currentParent = newNode

                // Animate Stack Frame Growth
                for (step in 1..25) {
                    newNode.growthRatio = step / 25.0
                    bonsaiPanel.repaint()
                    Thread.sleep(12)
                }

                // Interpret Commit Hash bytes as Microtonal Lullaby Melody
                for (byteIdx in 0 until 3) {
                    val freq = hashToMicrotoneFreq(commit.hash, byteIdx)
                    val duration = 280 + (commit.timestamp % 180).toInt()
                    audio.playMicrotone(freq, duration)
                }
            }
        }
    }
}

fun main() {
    SwingUtilities.invokeLater {
        val interpreter = EsotericGitInterpreter()
        interpreter.interpretAndPerform()
    }
}