import java.lang.management.ManagementFactory
import java.nio.ByteBuffer
import kotlin.math.*

fun main() {
    // Hide cursor and clear terminal screen
    print("\u001B[?25l\u001B[2J")

    // Allocate execution memory buffer and seed with dynamic bytecode/heap telemetry
    val memSize = 2048
    val memory = ByteBuffer.allocateDirect(memSize)
    
    val runtime = Runtime.getRuntime()
    var frame = 0.0

    // High-contrast ASCII density ramp for rendering non-Euclidean structures
    val asciiPalette = " .'`^\",:;Il!i><~+_-?][}{1)(|\\/tfjrxnuvczXYUJCLQ0OZmwqpdbkHAO*#MW&8%B@$"

    try {
        while (true) {
            // Self-referential step: Overwrite memory with raw runtime telemetry & memory addresses
            memory.clear()
            val freeMem = runtime.freeMemory()
            val totalMem = runtime.totalMemory()
            val threadId = Thread.currentThread().id
            val uptime = ManagementFactory.getRuntimeMXBean().uptime

            for (i in 0 until memSize step 32) {
                memory.putLong((freeMem xor (i.toLong() shl 8)) + frame.toLong())
                memory.putLong((totalMem rotl (i % 16)) xor uptime)
                memory.putLong(threadId * i + System.nanoTime())
                memory.putLong((i.toLong() * 0x9E3779B97F4A7C15L) xor frame.toLong())
            }

            // Audio Signal Synthesis: Read back raw memory bytes as audio PCM wave signals
            memory.flip()
            val audioSamples = DoubleArray(128)
            for (i in audioSamples.indices) {
                val rawByte = memory.get(i % memSize).toInt()
                // Normalize audio signal [-1.0, 1.0] with FM synthesis modulation based on bytecode noise
                audioSamples[i] = (rawByte / 128.0) * sin(i * 0.15 + frame * 0.2)
            }

            val width = 80
            val height = 40
            val buffer = StringBuilder(width * height + height + 32)
            buffer.append("\u001B[H") // Reset cursor to top-left

            // Non-Euclidean ASCII Fractal Ray-Marcher / Distortion Generator
            val time = frame * 0.08
            for (y in 0 until height) {
                val ny = (y.toDouble() / height - 0.5) * 2.0
                for (x in 0 until width) {
                    val nx = (x.toDouble() / width - 0.5) * 3.5 // Aspect ratio adjustment

                    // Non-Euclidean polar warp driven by memory-derived audio interference patterns
                    val sampleIdx = abs((x + y * width) % audioSamples.size)
                    val audioMod = audioSamples[sampleIdx]
                    
                    val radius = hypot(nx, ny) + audioMod * 0.3
                    val angle = atan2(ny, nx) + sin(radius * 8.0 - time) * 0.5

                    // Non-Euclidean fractal iteration (HyperbolicJulia-style distortion)
                    var zx = radius * cos(angle)
                    var zy = radius * sin(angle)
                    var cx = cos(time * 0.5) + audioMod * 0.2
                    var cy = sin(time * 0.3) - audioMod * 0.2

                    var iter = 0
                    val maxIter = 32
                    while (zx * zx + zy * zy < 4.0 && iter < maxIter) {
                        val tmp = zx * zx - zy * zy + cx
                        zy = 2.0 * abs(zx * zy) + cy // Non-Euclidean folding
                        zx = tmp
                        iter++
                    }

                    // Map fractal interference + binary memory signal to ASCII palette
                    val rawVal = (iter.toDouble() / maxIter) + abs(audioMod)
                    val paletteIdx = (rawVal * (asciiPalette.length - 1))
                        .toInt()
                        .coerceIn(0, asciiPalette.length - 1)

                    buffer.append(asciiPalette[paletteIdx])
                }
                buffer.append('\n')
            }

            // Render output frame
            print(buffer.toString())
            frame += 1.0
            Thread.sleep(30)
        }
    } finally {
        // Restore terminal cursor on exit
        print("\u001B[?25h")
    }
}

private infix fun Long.rotl(b: Int): Long = (this shl b) or (this ushr (64 - b))