import java.awt.*
import java.awt.geom.*
import javax.sound.midi.*
import javax.swing.*
import kotlin.concurrent.thread
import kotlin.math.*
import kotlin.random.Random

// Data model representing a Git commit entry
data class Commit(
    val hash: String,
    val author: String,
    val additions: Int,
    val deletions: Int,
    val message: String
) {
    val churn: Int get() = additions + deletions
}

// Maps code churn to Musical Scales (Low churn = Harmonic/Consonant, High churn = Dissonant/Chromatic)
object MusicTheory {
    val PENTATONIC = intArrayOf(60, 62, 64, 67, 69, 72, 74, 76)      // Pure harmony (Low churn)
    val DIATONIC = intArrayOf(60, 62, 64, 65, 67, 69, 71, 72)        // Standard Major (Medium churn)
    val HARMONIC_MINOR = intArrayOf(60, 62, 63, 65, 67, 68, 71, 72)  // Tense / Minor (High churn)
    val CHROMATIC = (55..80).toIntArray()                           // High Dissonance (Massive churn)

    fun getNotesForChurn(churn: Int, count: Int): List<Int> {
        val scale = when {
            churn < 20 -> PENTATONIC
            churn < 70 -> DIATONIC
            churn < 200 -> HARMONIC_MINOR
            else -> CHROMATIC
        }
        val rng = Random(churn)
        return List(count) {
            var note = scale[rng.nextInt(scale.size)]
            // Inject sharp micro-dissonances (tritones/half-steps) for chaotic refactors
            if (churn > 150 && rng.nextBoolean()) note += 1
            note
        }
    }
}

// Visual note element drawn on the generative sheet music staff
class NoteVisual(
    val x: Float,
    val y: Float,
    val pitch: Int,
    val color: Color,
    val size: Float,
    val isDissonant: Boolean
) {
    var alpha: Float = 1.0f
    fun update() { alpha -= 0.006f }
}

// Swing Canvas rendering generative sheet music & ambient visualizer
class VisualSynthesizerCanvas : JPanel() {
    val visualNotes = mutableListOf<NoteVisual>()
    var currentCommit: Commit? = null
    var currentAuthorColor: Color = Color.CYAN

    init {
        isOpaque = true
        background = Color(12, 12, 20)
    }

    fun addNote(pitch: Int, churn: Int, color: Color) {
        val staffCenterY = height / 2
        // Calculate vertical pitch position on the musical staff
        val pitchOffset = (72 - pitch) * 9.0f
        val x = width * 0.75f + (Random.nextFloat() - 0.5f) * 30f
        val y = staffCenterY + pitchOffset
        val size = (14f + sqrt(churn.toFloat()) * 1.8f).coerceAtMost(55f)
        val isDissonant = churn > 120

        synchronized(visualNotes) {
            visualNotes.add(NoteVisual(x, y, pitch, color, size, isDissonant))
        }
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        val g2 = g as Graphics2D
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        val w = width
        val h = height
        val centerY = h / 2

        // Draw Generative Sheet Music Staves
        g2.color = Color(255, 255, 255, 35)
        g2.stroke = BasicStroke(1.5f)
        val lineSpacing = 18
        for (i in -5..5) {
            if (i == 0) continue // Clef separation gap
            val y = centerY + i * lineSpacing
            g2.drawLine(50, y, w - 50, y)
        }

        // Draw Ambient Aura corresponding to author & code churn
        currentCommit?.let { commit ->
            val bgGlow = Color(currentAuthorColor.red, currentAuthorColor.green, currentAuthorColor.blue, 20)
            g2.color = bgGlow
            val glowRadius = (commit.churn * 4).coerceIn(80, w)
            g2.fill(Ellipse2D.Float((w / 2 - glowRadius / 2).toFloat(), (centerY - glowRadius / 2).toFloat(), glowRadius.toFloat(), glowRadius.toFloat()))

            // Draw HUD Info
            g2.color = Color(220, 220, 240, 200)
            g2.font = Font("Monospaced", Font.BOLD, 13)
            g2.drawString("COMMIT: [${commit.hash}] | AUTHOR: ${commit.author} | CHURN: ${commit.churn} lines", 50, 45)
            g2.font = Font("SansSerif", Font.ITALIC, 12)
            g2.drawString("\"${commit.message}\"", 50, 65)
        }

        // Render and flow visual sheet music notes
        synchronized(visualNotes) {
            val iterator = visualNotes.iterator()
            while (iterator.hasNext()) {
                val note = iterator.next()
                note.update()
                if (note.alpha <= 0f) {
                    iterator.remove()
                    continue
                }

                val drawX = note.x - (1f - note.alpha) * 350f
                val alphaInt = (note.alpha * 255).toInt().coerceIn(0, 255)

                // Dissonance Aura (Red glow for high churn)
                if (note.isDissonant) {
                    g2.color = Color(255, 60, 60, alphaInt / 3)
                    g2.fill(Ellipse2D.Float(drawX - note.size, note.y - note.size, note.size * 2, note.size * 2))
                }

                // Generative Note Head
                g2.color = Color(note.color.red, note.color.green, note.color.blue, alphaInt)
                g2.fill(Ellipse2D.Float(drawX - note.size / 2, note.y - note.size / 2, note.size, note.size))

                // Sheet Music Stem Line
                g2.stroke = BasicStroke(2f)
                g2.drawLine(drawX.toInt() + note.size.toInt() / 2, note.y.toInt(), drawX.toInt() + note.size.toInt() / 2, note.y.toInt() - 30)
            }
        }
    }
}

// Main Synthesizer orchestrating MIDI audio synthesis and visual generation
class GitVisualSynthesizer {
    private val synthesizer: Synthesizer = MidiSystem.getSynthesizer().apply { open() }
    private val channel: MidiChannel = synthesizer.channels[0]
    private val canvas = VisualSynthesizerCanvas()

    // Deterministically maps Author identity to an Orchestral Instrument & Color Palette
    private fun getAuthorProfile(author: String): Pair<Int, Color> {
        val hash = abs(author.hashCode())
        val instrument = when (hash % 6) {
            0 -> 73  // Flute (Light woodwind)
            1 -> 48  // String Ensemble (Warm orchestral)
            2 -> 11  // Vibraphone (Ambient metallic)
            3 -> 89  // Warm Pad (Ambient synth)
            4 -> 19  // Church Organ
            else -> 0 // Grand Piano
        }
        val hue = (hash % 360) / 360.0f
        val color = Color.getHSBColor(hue, 0.75f, 0.95f)
        return Pair(instrument, color)
    }

    fun playCommitHistory(commits: List<Commit>) {
        val frame = JFrame("Git Generative Ambient Sheet Music Synthesizer")
        frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
        frame.size = Dimension(1020, 640)
        frame.add(canvas)
        frame.setLocationRelativeTo(null)
        frame.isVisible = true

        // 60 FPS Render Loop
        thread {
            while (frame.isVisible) {
                canvas.repaint()
                Thread.sleep(16)
            }
        }

        // Generative MIDI & Visual Playback Thread
        thread {
            for (commit in commits) {
                if (!frame.isVisible) break

                val (instrument, color) = getAuthorProfile(commit.author)
                channel.programChange(instrument)

                canvas.currentCommit = commit
                canvas.currentAuthorColor = color

                // Code Churn dictates chord density & velocity (Dissonance & Dynamic intensity)
                val noteCount = (2 + commit.churn / 30).coerceIn(2, 7)
                val notes = MusicTheory.getNotesForChurn(commit.churn, noteCount)
                val velocity = (45 + commit.churn / 2).coerceIn(35, 120)

                for (pitch in notes) {
                    channel.noteOn(pitch, velocity)
                    canvas.addNote(pitch, commit.churn, color)
                    Thread.sleep((120..320).random().toLong())
                }

                // Ambient sustain between commits
                Thread.sleep((800..2200).random().toLong())

                for (pitch in notes) {
                    channel.noteOff(pitch)
                }
            }
        }
    }
}

fun main() {
    val sampleAuthors = listOf("Alice (Architect)", "Bob (Refactoring)", "Charlie (DevOps)", "Diana (UI)", "Eve (Chaos Eng)")
    val sampleMessages = listOf("Initial scaffold", "Fix critical memory leak", "Massive refactor of rendering core", "Updated docs", "Experimental shader engine", "Hotfix null pointer", "Nuked legacy modules")

    // Generate a synthetic Git commit log sequence
    val generatedCommits = List(30) {
        val author = sampleAuthors.random()
        val isHighChurn = Random.nextDouble() < 0.35
        val additions = if (isHighChurn) Random.nextInt(120, 600) else Random.nextInt(1, 40)
        val deletions = if (isHighChurn) Random.nextInt(90, 450) else Random.nextInt(0, 15)
        val hash = Integer.toHexString((100000..999999).random()).take(7)

        Commit(
            hash = hash,
            author = author,
            additions = additions,
            deletions = deletions,
            message = sampleMessages.random()
        )
    }

    val synth = GitVisualSynthesizer()
    synth.playCommitHistory(generatedCommits)
}