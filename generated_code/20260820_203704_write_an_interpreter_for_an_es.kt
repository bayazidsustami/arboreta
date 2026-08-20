import javax.sound.sampled.*
import java.io.File
import kotlin.math.*

/**
 * Esoteric Visual Audio Interpreter for Fractally-Growing SVG Programs.
 * 
 * Flow & Semantics:
 * 1. Generates a procedural recursive SVG tree with dynamically overlapping RGB branches.
 * 2. Traverses the SVG AST/DOM elements sequentially as instructions.
 * 3. Extracts RGB colors, maps them to audio frequencies (R=Pitch, G=Duration, B=Harmonics),
 *    and synthesizes/plays the resulting musical tone sequence.
 */

data class Branch(
    val x1: Double, val y1: Double,
    val x2: Double, val y2: Double,
    val r: Int, val g: Int, val b: Int,
    val depth: Int
)

class EsotericFractalInterpreter(private val maxDepth: Int = 5) {
    private val branches = mutableListOf<Branch>()

    // Procedurally generates an expanding tree where overlap and color evolve dynamically
    fun grow(x: Double, y: Double, length: Double, angle: Double, depth: Int) {
        if (depth > maxDepth) return

        val x2 = x + length * cos(Math.toRadians(angle))
        val y2 = y + length * sin(Math.toRadians(angle))

        // RGB values encode the execution instruction set
        val r = ((sin(depth * 0.8) * 0.5 + 0.5) * 255).toInt()
        val g = ((cos(angle * 0.05) * 0.5 + 0.5) * 255).toInt()
        val b = ((depth.toDouble() / maxDepth) * 255).toInt()

        branches.add(Branch(x, y, x2, y2, r, g, b, depth))

        // Recursive branching creates visual and instruction overlap
        grow(x2, y2, length * 0.75, angle - 25, depth + 1)
        grow(x2, y2, length * 0.75, angle + 30, depth + 1)
    }

    // Exports generated execution graph into SVG format
    fun exportSvg(): String {
        val body = branches.joinToString("\n  ") { b ->
            """<line x1="${b.x1.toInt()}" y1="${b.y1.toInt()}" x2="${b.x2.toInt()}" y2="${b.y2.toInt()}" """ +
            """stroke="rgb(${b.r},${b.g},${b.b})" stroke-width="${6 - b.depth}" stroke-linecap="round"/>"""
        }
        return """<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 800 600" style="background:#111">$body</svg>"""
    }

    // Executes the visual code: Maps RGB branches to sound synthesized live
    fun executeAudio() {
        val sampleRate = 44100f
        val format = AudioFormat(sampleRate, 16, 1, true, true)
        val line = AudioSystem.getSourceDataLine(format)
        line.open(format)
        line.start()

        for (branch in branches) {
            // R = Pitch Frequency (200Hz - 1000Hz)
            val freq = 200.0 + (branch.r / 255.0) * 800.0
            // G = Duration in milliseconds (80ms - 300ms)
            val durationMs = 80 + (branch.g / 255.0) * 220.0
            // B = Harmonic overtone intensity
            val harmonicRatio = 1.0 + (branch.b / 255.0)

            val numSamples = (sampleRate * (durationMs / 1000.0)).toInt()
            val buffer = ByteArray(numSamples * 2)

            for (i in 0 until numSamples) {
                val t = i / sampleRate.toDouble()
                // Fundamental tone mixed with secondary RGB harmonic multiplier
                val sample = sin(2.0 * PI * freq * t) + 0.3 * sin(2.0 * PI * freq * harmonicRatio * t)
                val envelope = sin(PI * i / numSamples) // Smooth fade in/out
                val pcmVal = (sample * envelope * 16383.0).toInt().coerceIn(-32768, 32767)

                buffer[i * 2] = (pcmVal shr 8).toByte()
                buffer[i * 2 + 1] = pcmVal.toByte()
            }

            line.write(buffer, 0, buffer.size)
        }

        line.drain()
        line.close()
    }
}

fun main() {
    println("Synthesizing Esoteric Visual Program...")
    val interpreter = EsotericFractalInterpreter(maxDepth = 6)
    
    // Grow visual tree starting at bottom center
    interpreter.grow(x = 400.0, y = 550.0, length = 100.0, angle = -90.0, depth = 1)

    // Output SVG source
    val svgCode = interpreter.exportSvg()
    File("fractal_program.svg").writeText(svgCode)
    println("Saved program visualization to 'fractal_program.svg'")

    // Interpret overlapping tree nodes into audio soundscape
    println("Executing visual audio code...")
    interpreter.executeAudio()
    println("Execution finished.")
}

This program uses standard Java/Kotlin audio synthesis. To learn more about how audio waveforms are processed directly using Kotlin libraries, check out this guide on [Audio processing with WaveBeans](https://www.youtube.com/watch?v=cT3ySpVMtD0).