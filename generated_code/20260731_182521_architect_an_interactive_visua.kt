import javax.sound.sampled.AudioFormat
import javax.sound.sampled.AudioSystem
import javax.sound.sampled.SourceDataLine
import javax.swing.JFrame
import javax.swing.JPanel
import java.awt.Color
import java.awt.Dimension
import java.awt.Graphics
import java.awt.Graphics2D
import java.awt.RenderingHints
import java.awt.event.KeyAdapter
import java.awt.event.KeyEvent
import kotlin.concurrent.thread
import kotlin.math.sin

// --- CONFIGURATION & CONSTANTS ---
const val GRID_SIZE = 32
const val CELL_SIZE = 20
const val SAMPLE_RATE = 44100f
const val AUDIO_FRAME_SIZE = 1470 // ~30ms audio blocks (33 fps update)

// Pentatonic frequencies (Hz) mapping to Life grid sections
val SCALE = doubleArrayOf(
    130.81, 146.83, 164.81, 196.00, 220.00, // C3, D3, E3, G3, A3
    261.63, 293.66, 329.63, 392.00, 440.00, // C4, D4, E4, G4, A4
    523.25, 587.33, 659.25, 783.99, 880.00  // C5, D5, E5, G5, A5
)

// Harmonic state representations for the Markov Chain
enum class HarmonicState { CONSONANT, NEUTRAL, DISSONANT, SPARSE, DENSE }

// --- HIDDEN MARKOV CHAIN FOR RULE MUTATION ---
class AudioDrivenRuleMarkov {
    private val states = HarmonicState.entries.toTypedArray()
    
    // Transition probabilities: P(State_next | State_current)
    private val transitions = mapOf(
        HarmonicState.CONSONANT to mapOf(HarmonicState.CONSONANT to 0.4, HarmonicState.NEUTRAL to 0.4, HarmonicState.DENSE to 0.2),
        HarmonicState.NEUTRAL to mapOf(HarmonicState.SPARSE to 0.3, HarmonicState.NEUTRAL to 0.4, HarmonicState.DISSONANT to 0.3),
        HarmonicState.DISSONANT to mapOf(HarmonicState.CONSONANT to 0.5, HarmonicState.SPARSE to 0.3, HarmonicState.DISSONANT to 0.2),
        HarmonicState.SPARSE to mapOf(HarmonicState.DENSE to 0.6, HarmonicState.NEUTRAL to 0.3, HarmonicState.SPARSE to 0.1),
        HarmonicState.DENSE to mapOf(HarmonicState.CONSONANT to 0.3, HarmonicState.DISSONANT to 0.4, HarmonicState.SPARSE to 0.3)
    )

    var currentState = HarmonicState.NEUTRAL
        private set

    // Evaluate current audio features to transition the Markov state and derive CA rules
    fun step(activeNotesCount: Int, spectralSpread: Double): Pair<Set<Int>, Set<Int>> {
        // Classify current observation
        val observation = when {
            activeNotesCount < 3 -> HarmonicState.SPARSE
            activeNotesCount > 10 -> HarmonicState.DENSE
            spectralSpread > 300.0 -> HarmonicState.DISSONANT
            spectralSpread < 100.0 -> HarmonicState.CONSONANT
            else -> HarmonicState.NEUTRAL
        }

        // Transition logic incorporating observation
        val options = transitions[currentState] ?: return Pair(setOf(3), setOf(2, 3))
        val rand = Math.random()
        var cumulative = 0.0
        
        for ((nextState, prob) in options) {
            cumulative += prob
            if (rand <= cumulative || nextState == observation) {
                currentState = nextState
                break
            }
        }

        // Map Markov State to Conway Rules (B = Birth, S = Survival)
        return when (currentState) {
            HarmonicState.CONSONANT -> setOf(3) to setOf(2, 3)          // Classic Conway (B3/S23)
            HarmonicState.NEUTRAL   -> setOf(3, 6) to setOf(2, 3)       // HighLife variant (B36/S23)
            HarmonicState.DISSONANT -> setOf(3, 4) to setOf(3, 4)       // 34 Life (B34/S34 - Chaos)
            HarmonicState.SPARSE    -> setOf(2, 3) to setOf(1, 2, 3, 4) // Spreading expansion
            HarmonicState.DENSE     -> setOf(4, 5, 6) to setOf(2, 3, 4) // Density restriction
        }
    }
}

// --- SYNTHESIZER ENGINE ---
class AmbientSynthesizer {
    private var phaseAngle = DoubleArray(SCALE.size)
    @Volatile var activeFrequencies = DoubleArray(0)
    
    // Low-pass filter state
    private var filterState = 0.0

    fun renderBlock(buffer: ByteArray, frameSize: Int) {
        val freqs = activeFrequencies
        for (i in 0 until frameSize / 2) {
            var sample = 0.0
            if (freqs.isNotEmpty()) {
                val weight = 1.0 / freqs.size
                for (j in freqs.indices) {
                    val freq = freqs[j]
                    val step = 2.0 * Math.PI * freq / SAMPLE_RATE
                    phaseAngle[j % phaseAngle.size] += step
                    // Add sine wave with subtle octave harmonic
                    sample += (sin(phaseAngle[j % phaseAngle.size]) + 0.3 * sin(2.0 * phaseAngle[j % phaseAngle.size])) * weight
                }
            }

            // Simple One-Pole Low-Pass Filter for warmth
            filterState += (sample - filterState) * 0.15
            
            // Convert to 16-bit PCM Audio
            val pcmValue = (filterState.coerceIn(-1.0, 1.0) * 32767).toInt()
            buffer[2 * i] = (pcmValue and 0xFF).toByte()
            buffer[2 * i + 1] = ((pcmValue shr 8) and 0xFF).toByte()
        }
    }
}

// --- MAIN INTERACTIVE VISUAL ENGINE ---
class VisualEcosystem : JPanel() {
    private var grid = Array(GRID_SIZE) { BooleanArray(GRID_SIZE) }
    private var birthRules = setOf(3)
    private var survivalRules = setOf(2, 3)
    
    private val markov = AudioDrivenRuleMarkov()
    private val synth = AmbientSynthesizer()
    
    private var audioThreadRunning = true
    private var currentPhaseHue = 0f

    init {
        preferredSize = Dimension(GRID_SIZE * CELL_SIZE, GRID_SIZE * CELL_SIZE)
        isFocusable = true
        
        // Key controls: Space to randomize, C to clear
        addKeyListener(object : KeyAdapter() {
            override fun keyPressed(e: KeyEvent) {
                when (e.keyCode) {
                    KeyEvent.VK_SPACE -> randomizeGrid()
                    KeyEvent.VK_C -> grid = Array(GRID_SIZE) { BooleanArray(GRID_SIZE) }
                }
            }
        })

        randomizeGrid()
        startAudioEngine()
        startEcosystemLoop()
    }

    private fun randomizeGrid() {
        for (x in 0 until GRID_SIZE) {
            for (y in 0 until GRID_SIZE) {
                grid[x][y] = Math.random() < 0.25
            }
        }
    }

    // Main Audio Synthesis Thread
    private fun startAudioEngine() {
        thread(isDaemon = true) {
            val format = AudioFormat(SAMPLE_RATE, 16, 1, true, false)
            val line: SourceDataLine = AudioSystem.getSourceDataLine(format)
            line.open(format, AUDIO_FRAME_SIZE * 2)
            line.start()

            val pcmBuffer = ByteArray(AUDIO_FRAME_SIZE * 2)

            while (audioThreadRunning) {
                synth.renderBlock(pcmBuffer, AUDIO_FRAME_SIZE)
                line.write(pcmBuffer, 0, pcmBuffer.size)
            }

            line.drain()
            line.close()
        }
    }

    // Step Ecosystem Simulation & Audio/Rule Feedback Loop
    private fun startEcosystemLoop() {
        thread(isDaemon = true) {
            while (audioThreadRunning) {
                // 1. Translate Grid State to Audio Frequencies
                val activeFreqs = mutableListOf<Double>()
                var activeCount = 0
                
                // Map active grid sectors to scale frequencies
                for (x in 0 until GRID_SIZE) {
                    for (y in 0 until GRID_SIZE) {
                        if (grid[x][y]) {
                            activeCount++
                            if (x % 2 == 0 && y % 2 == 0) {
                                val scaleIdx = (x / 2 + y / 2) % SCALE.size
                                if (activeFreqs.size < 8) activeFreqs.add(SCALE[scaleIdx])
                            }
                        }
                    }
                }
                
                synth.activeFrequencies = activeFreqs.toDoubleArray()

                // 2. Pass Audio Characteristics to Markov Chain to Mutate Rules
                val spectralSpread = if (activeFreqs.size > 1) activeFreqs.last() - activeFreqs.first() else 0.0
                val (newBirth, newSurvival) = markov.step(activeCount, spectralSpread)
                birthRules = newBirth
                survivalRules = newSurvival

                // 3. Evolve Cellular Automata Grid
                evolveGrid()

                // Visual updates
                currentPhaseHue = (currentPhaseHue + 0.005f) % 1.0f
                repaint()

                Thread.sleep(120) // ~8 updates per second for evolutionary step
            }
        }
    }

    private fun evolveGrid() {
        val nextGrid = Array(GRID_SIZE) { BooleanArray(GRID_SIZE) }
        for (x in 0 until GRID_SIZE) {
            for (y in 0 until GRID_SIZE) {
                val neighbors = countNeighbors(x, y)
                val alive = grid[x][y]
                nextGrid[x][y] = if (alive) {
                    survivalRules.contains(neighbors)
                } else {
                    birthRules.contains(neighbors)
                }
            }
        }
        grid = nextGrid
    }

    private fun countNeighbors(x: Int, y: Int): Int {
        var count = 0
        for (dx in -1..1) {
            for (dy in -1..1) {
                if (dx == 0 && dy == 0) continue
                val nx = (x + dx + GRID_SIZE) % GRID_SIZE
                val ny = (y + dy + GRID_SIZE) % GRID_SIZE
                if (grid[nx][ny]) count++
            }
        }
        return count
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        val g2d = g as Graphics2D
        g2d.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        // Background gradient based on active Markov State
        val baseColor = Color.getHSBColor(currentPhaseHue, 0.4f, 0.15f)
        g2d.color = baseColor
        g2d.fillRect(0, 0, width, height)

        // Render Cells
        val cellColor = Color.getHSBColor(currentPhaseHue, 0.7f, 0.9f)
        for (x in 0 until GRID_SIZE) {
            for (y in 0 until GRID_SIZE) {
                if (grid[x][y]) {
                    g2d.color = cellColor
                    g2d.fillRoundRect(
                        x * CELL_SIZE + 1, y * CELL_SIZE + 1,
                        CELL_SIZE - 2, CELL_SIZE - 2, 6, 6
                    )
                }
            }
        }

        // Render HUD overlay with real-time Markov Rule information
        g2d.color = Color.WHITE
        g2d.drawString("Markov State: ${markov.currentState}", 10, height - 30)
        g2d.drawString("Active Rules: B${birthRules.joinToString("")}/S${survivalRules.joinToString("")}", 10, height - 12)
        g2d.drawString("[SPACE] Randomize | [C] Clear", width - 180, height - 12)
    }
}

fun main() {
    val frame = JFrame("Bio-Acoustic Ecosystem: Visual Life & Audio-Markov Feedback Loop")
    val ecosystem = VisualEcosystem()
    
    frame.add(ecosystem)
    frame.pack()
    frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
    frame.setLocationRelativeTo(null)
    frame.isVisible = true
}