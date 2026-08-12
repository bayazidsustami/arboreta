import javax.sound.midi.MidiSystem
import javax.sound.midi.ShortMessage
import kotlin.concurrent.thread
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

// --- Global States ---
val width = 60
val height = 24
val size = width * height

// Fluid Buffers
val u = FloatArray(size)
val v = FloatArray(size)
val uPrev = FloatArray(size)
val vPrev = FloatArray(size)
val density = FloatArray(size)
val densityPrev = FloatArray(size)

// Self-Destructing Source Code Representation
var sourceCode = """
import javax.sound.midi.MidiSystem
import javax.sound.midi.ShortMessage
import kotlin.concurrent.thread
import kotlin.math.*

// Fluid Simulation & Hardware Audio Corrupter
fun main() {
    println("Initializing Terminal Fluid Dynamics...")
    val synth = MidiSystem.getSynthesizer().apply { open() }
    val channel = synth.channels[0].apply { programChange(81) }
    
    // Core Fluid Solver Loop
    while (true) {
        decayDensity()
        diffuseAndAdvect()
        harvestFloatErrorsAndPlaySound(channel)
        corrodeSourceCode()
        renderTerminal()
        Thread.sleep(30)
    }
}
""".trimIndent().toCharArray()

// MIDI Synthesizer Setup
val synth = MidiSystem.getSynthesizer().apply { open() }
val midiChannel = synth.channels[0].apply { programChange(81) } // Lead 2 (sawtooth)

fun IX(x: Int, y: Int): Int = (x.coerceIn(0, width - 1)) + (y.coerceIn(0, height - 1)) * width

fun addSource(x: FloatArray, s: FloatArray, dt: Float) {
    for (i in 0 until size) x[i] += dt * s[i]
}

fun diffuse(b: Int, x: FloatArray, x0: FloatArray, diff: Float, dt: Float) {
    val a = dt * diff * width * height
    for (k in 0 until 20) {
        for (i in 1 until width - 1) {
            for (j in 1 until height - 1) {
                x[IX(i, j)] = (x0[IX(i, j)] + a * (x[IX(i - 1, j)] + x[IX(i + 1, j)] + x[IX(i, j - 1)] + x[IX(i, j + 1)])) / (1 + 4 * a)
            }
        }
    }
}

fun advect(b: Int, d: FloatArray, d0: FloatArray, u: FloatArray, v: FloatArray, dt: Float) {
    val dt0 = dt * width
    for (i in 1 until width - 1) {
        for (j in 1 until height - 1) {
            var x = i - dt0 * u[IX(i, j)]
            var y = j - dt0 * v[IX(i, j)]
            if (x < 0.5f) x = 0.5f
            if (x > width - 1.5f) x = width - 1.5f
            val i0 = x.toInt()
            val i1 = i0 + 1
            if (y < 0.5f) y = 0.5f
            if (y > height - 1.5f) y = height - 1.5f
            val j0 = y.toInt()
            val j1 = j0 + 1
            val s1 = x - i0
            val s0 = 1 - s1
            val t1 = y - j0
            val t0 = 1 - t1
            d[IX(i, j)] = s0 * (t0 * d0[IX(i0, j0)] + t1 * d0[IX(i0, j1)]) + s1 * (t0 * d0[IX(i1, j0)] + t1 * d0[IX(i1, j1)])
        }
    }
}

fun stepFluid(dt: Float) {
    diffuse(1, uPrev, u, 0.0001f, dt)
    diffuse(2, vPrev, v, 0.0001f, dt)
    advect(1, u, uPrev, uPrev, vPrev, dt)
    advect(2, v, vPrev, uPrev, vPrev, dt)
    diffuse(0, densityPrev, density, 0.0001f, dt)
    advect(0, density, densityPrev, u, v, dt)
}

fun harvestFloatErrorsAndPlaySound(): Float {
    var totalError = 0.0f
    for (i in 0 until size) {
        // Exploit non-associativity of IEEE 754 floating points to extract numerical drift error
        val val1 = (density[i] + u[i]) + v[i]
        val val2 = density[i] + (u[i] + v[i])
        val drift = abs(val1 - val2)
        totalError += drift

        // Convert microscopic precision loss into musical pitch scales
        if (drift > 1e-7f && Random.nextFloat() < 0.05f) {
            val note = 36 + ((drift * 1e7f).toInt() % 48)
            midiChannel.noteOn(note, (60 + (drift * 1e8f).toInt() % 67))
        }
    }
    return totalError
}

fun corrodeSourceCode(errorMagnitude: Float) {
    // High numerical drift causes real-time code byte decay
    val corruptionTarget = (errorMagnitude * 1000).toInt() + 1
    repeat(corruptionTarget) {
        if (sourceCode.isNotEmpty()) {
            val idx = Random.nextInt(sourceCode.size)
            if (sourceCode[idx] != '\n' && sourceCode[idx] != ' ') {
                sourceCode[idx] = "░▒▓█▓▒░#$@!*&;:[]./\\".random()
            }
        }
    }
}

fun renderFrame(t: Float) {
    val asciiGradient = " .:-=+*#%@"
    val sb = StringBuilder("\u001B[H") // Move cursor top-left

    sb.append("=== TERMINAL FLUID DYNAMICS & SOURCE CORROSION ===\n")
    for (y in 0 until height) {
        for (x in 0 until width) {
            val d = density[IX(x, y)].coerceIn(0.0f, 1.0f)
            val charIdx = (d * (asciiGradient.length - 1)).toInt()
            sb.append(asciiGradient[charIdx])
        }
        sb.append("\n")
    }

    sb.append("\n=== SELF-CORRODING SOURCE CODE (REAL-TIME MEMORY DECAY) ===\n")
    val displayCode = String(sourceCode).take(width * 8)
    sb.append(displayCode)
    
    print(sb.toString())
}

fun main() {
    print("\u001B[2J\u001B[?25l") // Clear screen & hide cursor
    
    // Add graceful shutdown hook to restore cursor
    Runtime.getRuntime().addShutdownHook(Thread {
        print("\u001B[?25h\n")
        synth.close()
    })

    var t = 0.0f
    val dt = 0.1f

    while (true) {
        // Inject moving fluid sources dynamically
        val cx = (width / 2 + cos(t * 2.0f) * (width / 3)).toInt()
        val cy = (height / 2 + sin(t * 1.5f) * (height / 3)).toInt()
        
        density[IX(cx, cy)] += 5.0f
        u[IX(cx, cy)] += cos(t * 3.0f) * 2.0f
        v[IX(cx, cy)] += sin(t * 3.0f) * 2.0f

        stepFluid(dt)
        val errorVal = harvestFloatErrorsAndPlaySound()
        corrodeSourceCode(errorVal)
        renderFrame(t)

        t += dt
        Thread.sleep(33) // ~30 FPS
    }
}