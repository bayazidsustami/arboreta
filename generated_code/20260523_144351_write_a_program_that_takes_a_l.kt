import javafx.animation.AnimationTimer
import javafx.application.Application
import javafx.scene.Group
import javafx.scene.Scene
import javafx.scene.canvas.Canvas
import javafx.scene.canvas.GraphicsContext
import javafx.scene.paint.Color
import javafx.stage.Stage
import javax.sound.midi.*
import kotlin.math.*
import kotlin.random.Random

// Simple data class for a vehicle state
data class Vehicle(var x: Double, var y: Double, var vx: Double, var vy: Double)

// Landmark for proximity effect
data class Landmark(val x: Double, val y: Double)

// Main application entry point
class TransitMidiFractal : Application() {

    private val width = 800.0
    private val height = 800.0
    private val vehicle = Vehicle(width / 2, height / 2, 0.0, 0.0)
    private val landmarks = listOf(
        Landmark(200.0, 200.0),
        Landmark(600.0, 200.0),
        Landmark(200.0, 600.0),
        Landmark(600.0, 600.0)
    )
    private lateinit var synth: Synthesizer
    private lateinit var channel: MidiChannel
    private lateinit var gc: GraphicsContext
    private var lastTick = System.nanoTime()

    override fun start(primaryStage: Stage) {
        // Setup MIDI
        synth = MidiSystem.getSynthesizer()
        synth.open()
        channel = synth.channels[0]
        channel.programChange(0) // Piano

        // Setup JavaFX canvas
        val root = Group()
        val canvas = Canvas(width, height)
        gc = canvas.graphicsContext2D
        root.children.add(canvas)
        primaryStage.scene = Scene(root, width, height, Color.BLACK)
        primaryStage.title = "Transit MIDI Fractal"
        primaryStage.show()

        // Main loop
        object : AnimationTimer() {
            override fun handle(now: Long) {
                val dt = (now - lastTick) / 1_000_000_000.0
                lastTick = now
                updateVehicle(dt)
                renderFractal()
                emitMidi()
            }
        }.start()
    }

    // Simulate vehicle movement with random acceleration
    private fun updateVehicle(dt: Double) {
        // random acceleration
        vehicle.vx += (Random.nextDouble() - 0.5) * 50 * dt
        vehicle.vy += (Random.nextDouble() - 0.5) * 50 * dt
        // damping
        vehicle.vx *= 0.99
        vehicle.vy *= 0.99
        vehicle.x = (vehicle.x + vehicle.vx * dt).let { if (it < 0) width + it else if (it > width) it - width else it }
        vehicle.y = (vehicle.y + vehicle.vy * dt).let { if (it < 0) height + it else if (it > height) it - height else it }
    }

    // Render a simple kaleidoscopic fractal based on vehicle position
    private fun renderFractal() {
        gc.clearRect(0.0, 0.0, width, height)
        val cx = vehicle.x
        val cy = vehicle.y
        val maxR = hypot(width, height) / 2
        for (i in 0 until 12) {
            val angle = i * PI / 6
            gc.save()
            gc.translate(width / 2, height / 2)
            gc.rotate(Math.toDegrees(angle))
            gc.translate(-width / 2, -height / 2)
            for (r in 0..10) {
                val radius = r * 20.0 + 10
                val alpha = 1.0 - r / 12.0
                gc.fill = Color.hsb((r * 30 + i * 15) % 360, 0.7, 0.9, alpha)
                gc.fillOval(cx - radius, cy - radius, radius * 2, radius * 2)
            }
            gc.restore()
        }
    }

    // Map vehicle dynamics to MIDI events
    private fun emitMidi() {
        val speed = hypot(vehicle.vx, vehicle.vy)
        val tempo = (60 + speed * 2).toInt().coerceIn(60, 180) // BPM mapped to speed
        val pitch = ((atan2(vehicle.vy, vehicle.vx) + PI) / (2 * PI) * 127).toInt()
        val nearest = landmarks.minByOrNull { hypot(it.x - vehicle.x, it.y - vehicle.y) }!!
        val distance = hypot(nearest.x - vehicle.x, nearest.y - vehicle.y)
        val volume = ((1 - distance / (width / 2)).coerceIn(0.0, 1.0) * 127).toInt()

        // Send Note On/Off every beat
        val beatDurationMs = (60000 / tempo).toLong()
        val now = System.currentTimeMillis()
        if (now % beatDurationMs < 20) {
            channel.noteOn(pitch, volume)
        } else {
            channel.allNotesOff()
        }

        // Simple timbre modulation using controller 71 (tremolo depth)
        channel.controlChange(71, (volume / 2))
    }

    override fun stop() {
        synth.close()
    }
}

fun main() {
    Application.launch(TransitMidiFractal::class.java)
}