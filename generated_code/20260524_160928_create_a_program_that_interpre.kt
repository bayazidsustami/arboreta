import javafx.application.Application
import javafx.application.Platform
import javafx.scene.Scene
import javafx.scene.canvas.Canvas
import javafx.scene.canvas.GraphicsContext
import javafx.scene.layout.StackPane
import javafx.scene.paint.Color
import javafx.stage.Stage
import java.util.*
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import javax.sound.midi.*

// Simple data class representing a tweet
data class Tweet(val text: String, val length: Int, val sentiment: Sentiment)

// Very naive sentiment analysis
enum class Sentiment { POSITIVE, NEGATIVE, NEUTRAL }

fun analyzeSentiment(text: String): Sentiment {
    val lower = text.lowercase()
    return when {
        listOf("good", "great", "awesome", "love", ":)").any { lower.contains(it) } -> Sentiment.POSITIVE
        listOf("bad", "terrible", "hate", ":(").any { lower.contains(it) } -> Sentiment.NEGATIVE
        else -> Sentiment.NEUTRAL
    }
}

// Cell states derived from tweet attributes
enum class CellState { EMPTY, POS, NEG, NEU }

fun tweetToState(tweet: Tweet): CellState = when (tweet.sentiment) {
    Sentiment.POSITIVE -> CellState.POS
    Sentiment.NEGATIVE -> CellState.NEG
    Sentiment.NEUTRAL -> CellState.NEU
}

// Simple automaton rules: next state depends on neighbor majority
fun nextState(current: CellState, neighbors: List<CellState>): CellState {
    val counts = neighbors.groupingBy { it }.eachCount()
    val majority = counts.maxByOrNull { it.value }?.key ?: CellState.EMPTY
    return if (majority != CellState.EMPTY) majority else current
}

// Mock tweet generator (replace with real Twitter streaming)
class MockTweetGenerator {
    private val random = Random()
    private val samples = listOf(
        "I love this! #awesome",
        "This is terrible... #fail",
        "Just another day.",
        "Great vibes :) #fun",
        "I hate waiting. #annoyed",
        "Neutral statement."
    )
    fun nextTweet(): Tweet {
        val text = samples[random.nextInt(samples.size)]
        return Tweet(text, text.length, analyzeSentiment(text))
    }
}

// Music synchronizer (plays a simple tone on each tick)
class MusicSync {
    private val synth = SynthesizerProvider.getSynthesizer()
    private val channel = synth.channels[0]

    init {
        synth.open()
    }

    fun beat() {
        channel.noteOn(60, 80) // C4
        Thread.sleep(100)
        channel.noteOff(60)
    }

    fun close() {
        synth.close()
    }
}

// Utility to obtain a default synthesizer
object SynthesizerProvider {
    fun getSynthesizer(): Synthesizer {
        return MidiSystem.getSynthesizer()
    }
}

// Main JavaFX application
class AutomatonApp : Application() {
    private val cols = 80
    private val rows = 45
    private val cellSize = 12.0
    private val grid = Array(rows) { Array(cols) { CellState.EMPTY } }
    private val generator = MockTweetGenerator()
    private val music = MusicSync()
    private val executor = Executors.newSingleThreadScheduledExecutor()
    private lateinit var gc: GraphicsContext

    override fun start(primaryStage: Stage) {
        val canvas = Canvas(cols * cellSize, rows * cellSize)
        gc = canvas.graphicsContext2D
        val root = StackPane(canvas)
        primaryStage.scene = Scene(root)
        primaryStage.title = "Twitter CA + Music"
        primaryStage.show()

        // Insert initial random tweets
        repeat(200) { injectRandomTweet() }
        drawGrid()

        // Schedule updates at ~30 FPS, each tick also plays a beat
        executor.scheduleAtFixedRate({
            Platform.runLater {
                updateAutomaton()
                drawGrid()
                music.beat()
            }
        }, 0, 33, TimeUnit.MILLISECONDS)
    }

    private fun injectRandomTweet() {
        val tweet = generator.nextTweet()
        // Random position for the new cell
        val r = Random()
        val x = r.nextInt(cols)
        val y = r.nextInt(rows)
        grid[y][x] = tweetToState(tweet)
    }

    private fun updateAutomaton() {
        // Add a new tweet each tick
        injectRandomTweet()
        // Compute next generation
        val next = Array(rows) { Array(cols) { CellState.EMPTY } }
        for (y in 0 until rows) {
            for (x in 0 until cols) {
                val neighbors = mutableListOf<CellState>()
                for (dy in -1..1) for (dx in -1..1) {
                    if (dx == 0 && dy == 0) continue
                    val nx = (x + dx + cols) % cols
                    val ny = (y + dy + rows) % rows
                    neighbors.add(grid[ny][nx])
                }
                next[y][x] = nextState(grid[y][x], neighbors)
            }
        }
        for (y in 0 until rows) for (x in 0 until cols) grid[y][x] = next[y][x]
    }

    private fun drawGrid() {
        for (y in 0 until rows) {
            for (x in 0 until cols) {
                gc.fill = when (grid[y][x]) {
                    CellState.EMPTY -> Color.BLACK
                    CellState.POS -> Color.LIMEGREEN
                    CellState.NEG -> Color.CRIMSON
                    CellState.NEU -> Color.DARKGRAY
                }
                gc.fillRect(x * cellSize, y * cellSize, cellSize, cellSize)
            }
        }
    }

    override fun stop() {
        executor.shutdownNow()
        music.close()
    }
}

// Entry point
fun main() {
    Application.launch(AutomatonApp::class.java)
}