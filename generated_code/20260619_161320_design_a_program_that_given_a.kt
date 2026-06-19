import javafx.application.Application
import javafx.scene.*
import javafx.scene.input.KeyCode
import javafx.scene.input.KeyEvent
import javafx.scene.paint.Color
import javafx.scene.paint.PhongMaterial
import javafx.scene.shape.Box
import javafx.scene.transform.Rotate
import javafx.scene.transform.Translate
import javafx.stage.Stage
import javafx.animation.AnimationTimer
import javax.sound.midi.*
import java.io.File
import kotlin.math.*

// Simple 3‑D fractal terrain generated from MIDI notes.
// Each note creates a box; pitch => height, velocity => color/intensity.
// User walks with WASD/Space/Shift. Original MIDI plays in sync.

class MidiFractalApp : Application() {

    private val sceneRoot = Group()
    private val camera = PerspectiveCamera(true)
    private val camTranslate = Translate(0.0, -200.0, -800.0)
    private val camRotateX = Rotate(-30.0, Rotate.X_AXIS)
    private val camRotateY = Rotate(0.0, Rotate.Y_AXIS)

    // movement state
    private val pressed = mutableSetOf<KeyCode>()
    private val moveSpeed = 3.0
    private val turnSpeed = 0.5

    // lighting that reacts to dynamics
    private val ambient = AmbientLight(Color.grayRgb(30))
    private val pointLight = PointLight(Color.WHITE).apply { translateX = 0.0; translateY = -200.0; translateZ = -300.0 }

    // MIDI playback
    private var sequencer: Sequencer? = null

    override fun start(primaryStage: Stage) {
        if (parameters.raw.size < 1) {
            println("Usage: <program> <midi-file>")
            System.exit(0)
        }
        val midiFile = File(parameters.raw[0])
        if (!midiFile.exists()) {
            println("File not found: ${midiFile.path}")
            System.exit(0)
        }

        parseMidiAndBuildTerrain(midiFile)

        sceneRoot.children.addAll(ambient, pointLight)

        val subScene = SubScene(sceneRoot, 1024.0, 768.0, true, SceneAntialiasing.BALANCED)
        subScene.fill = Color.BLACK
        subScene.camera = camera
        camera.transforms.addAll(camTranslate, camRotateX, camRotateY)

        val scene = Scene(Group(subScene))
        scene.onKeyPressed = this::handleKeyPress
        scene.onKeyReleased = this::handleKeyRelease

        primaryStage.title = "MIDI Fractal Landscape"
        primaryStage.scene = scene
        primaryStage.show()

        startMidiPlayback(midiFile)
        startAnimationLoop()
    }

    private fun parseMidiAndBuildTerrain(file: File) {
        val seq = MidiSystem.getSequence(file)
        val tracks = seq.tracks

        // simple fractal: recursively place boxes around a central point.
        fun addBox(pitch: Int, velocity: Int, time: Long) {
            val size = 20.0
            val height = (pitch - 21) * 4.0   // piano range 21‑108
            val material = PhongMaterial()
            val intensity = velocity / 127.0
            material.diffuseColor = Color.hsb(pitch * 3.0 % 360, 0.8, intensity.coerceIn(0.2,1.0))

            val box = Box(size, height.coerceAtLeast(5.0), size)
            box.material = material

            // fractal placement: radius grows with time
            val radius = (time / 1000.0) * 2.0 + 50.0
            val angle = Math.toRadians((pitch * 13) % 360.0)
            box.translateX = radius * cos(angle)
            box.translateZ = radius * sin(angle)
            box.translateY = -height / 2.0
            sceneRoot.children.add(box)
        }

        // iterate all note-on events
        for (track in tracks) {
            var tickPos = 0L
            for (msg in track) {
                tickPos = msg.tick
                val midiMsg = msg.message
                if (midiMsg is ShortMessage && midiMsg.command == ShortMessage.NOTE_ON && midiMsg.data2 > 0) {
                    addBox(midiMsg.data1, midiMsg.data2, tickPos)
                }
            }
        }
    }

    private fun startMidiPlayback(file: File) {
        try {
            sequencer = MidiSystem.getSequencer(false)
            sequencer?.open()
            sequencer?.sequence = MidiSystem.getSequence(file)
            sequencer?.start()
        } catch (e: Exception) {
            println("MIDI playback failed: ${e.message}")
        }
    }

    private fun startAnimationLoop() {
        object : AnimationTimer() {
            override fun handle(now: Long) {
                // camera movement
                var dx = 0.0
                var dz = 0.0
                if (pressed.contains(KeyCode.W)) dz += moveSpeed
                if (pressed.contains(KeyCode.S)) dz -= moveSpeed
                if (pressed.contains(KeyCode.A)) dx += moveSpeed
                if (pressed.contains(KeyCode.D)) dx -= moveSpeed

                val rad = Math.toRadians(camRotateY.angle)
                camTranslate.x += (dx * cos(rad) - dz * sin(rad))
                camTranslate.z += (dx * sin(rad) + dz * cos(rad))

                if (pressed.contains(KeyCode.LEFT)) camRotateY.angle -= turnSpeed
                if (pressed.contains(KeyCode.RIGHT)) camRotateY.angle += turnSpeed
                if (pressed.contains(KeyCode.UP)) camRotateX.angle -= turnSpeed
                if (pressed.contains(KeyCode.DOWN)) camRotateX.angle += turnSpeed
                if (pressed.contains(KeyCode.SPACE)) camTranslate.y += moveSpeed
                if (pressed.contains(KeyCode.SHIFT)) camTranslate.y -= moveSpeed

                // lighting reacts to current MIDI velocity (simple pulse)
                val pos = sequencer?.microsecondPosition ?: 0L
                val intensity = (sin(pos / 1_000_000.0 * Math.PI * 2) * 0.5 + 0.5) * 0.8 + 0.2
                pointLight.color = Color.grayRgb((intensity * 255).toInt())
            }
        }.start()
    }

    private fun handleKeyPress(e: KeyEvent) {
        pressed.add(e.code)
    }

    private fun handleKeyRelease(e: KeyEvent) {
        pressed.remove(e.code)
    }

    override fun stop() {
        sequencer?.close()
    }
}

fun main(args: Array<String>) {
    Application.launch(MidiFractalApp::class.java, *args)
}