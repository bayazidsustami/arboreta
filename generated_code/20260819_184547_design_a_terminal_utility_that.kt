import javax.sound.sampled.AudioFormat
import javax.sound.sampled.AudioSystem
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.random.Random

class Complex(val re: Double, val im: Double) {
    operator fun plus(b: Complex) = Complex(re + b.re, im + b.im)
    operator fun minus(b: Complex) = Complex(re - b.re, im - b.im)
    operator fun times(b: Complex) = Complex(re * b.re - im * b.im, re * b.im + im * b.re)
    fun magnitude(): Double = sqrt(re * re + im * im)
}

fun fft(x: Array<Complex>): Array<Complex> {
    val n = x.size
    if (n <= 1) return x
    val even = fft(Array(n / 2) { x[2 * it] })
    val odd = fft(Array(n / 2) { x[2 * it + 1] })
    val y = Array(n) { Complex(0.0, 0.0) }
    for (k in 0 until n / 2) {
        val angle = -2 * Math.PI * k / n
        val w = Complex(cos(angle), sin(angle)) * odd[k]
        y[k] = even[k] + w
        y[k + n / 2] = even[k] - w
    }
    return y
}

fun main(args: Array<String>) {
    val sampleRate = 44100.0
    val durationSec = 30
    val totalSamples = (sampleRate * durationSec).toInt()
    
    // Synthesize harmonic audio buffer if no audio file supplied or supported
    val audioBytes = ByteArray(totalSamples * 2)
    for (i in 0 until totalSamples) {
        val t = i / sampleRate
        val f0 = 110.0 + 55.0 * sin(2 * Math.PI * 0.1 * t)
        val wave = 0.5 * sin(2 * Math.PI * f0 * t) +
                   0.3 * sin(2 * Math.PI * f0 * 2.0 * t) +
                   0.2 * sin(2 * Math.PI * f0 * 3.5 * t)
        val sample = (wave * 32767).toInt().coerceIn(-32768, 32767)
        audioBytes[i * 2] = (sample and 0xFF).toByte()
        audioBytes[i * 2 + 1] = ((sample shr 8) and 0xFF).toByte()
    }

    val width = 80
    val height = 30
    val fftSize = 1024
    
    // Cellular automaton grid state
    var grid = Array(height) { IntArray(width) { if (Random.nextDouble() < 0.2) Random.nextInt(1, 4) else 0 } }
    val dnaChars = charArrayOf(' ', '.', '*', 'O', '@', '#')
    
    print("\u001B[2J\u001B[?25l") // Clear screen and hide cursor
    
    val frameIntervalMs = 50L
    val samplesPerFrame = (sampleRate * (frameIntervalMs / 1000.0)).toInt()
    var samplePointer = 0

    while (samplePointer + fftSize < totalSamples) {
        val window = Array(fftSize) {
            val idx = samplePointer + it
            val b1 = audioBytes[idx * 2].toInt() and 0xFF
            val b2 = audioBytes[idx * 2 + 1].toInt()
            val pcm = (b2 shl 8) or b1
            Complex(pcm / 32768.0, 0.0)
        }
        
        val spectrum = fft(window)
        
        // Extract low, mid, high harmonic overtone energies
        var lowEnergy = 0.0
        var midEnergy = 0.0
        var highEnergy = 0.0
        
        for (i in 0 until fftSize / 2) {
             me = spectrum[i].magnitude()
            when {
                i < 10 -> lowEnergy += me
                i < 60 -> midEnergy += me
                i < 200 -> highEnergy += me
            }
        }
        
        val birthThreshold = (2 - (highEnergy / 500.0).coerceIn(0.0, 1.5)).toInt().coerceAtLeast(1)
        val mutationRate = (midEnergy / 1000.0).coerceIn(0.01, 0.5)
        val aggro = lowEnergy > 1500.0

        val nextGrid = Array(height) { IntArray(width) }

        for (y in 0 until height) {
            for (x in 0 until width) {
                var neighbors = 0
                var neighborStateSum = 0
                
                for (dy in -1..1) {
                    for (dx in -1..1) {
                        if (dx == 0 && dy == 0) continue
                        val ny = (y + dy + height) % height
                        val nx = (x + dx + width) % width
                        if (grid[ny][nx] > 0) {
                            neighbors++
                            neighborStateSum += grid[ny][nx]
                        }
                    }
                }

                val current = grid[y][x]
                if (current > 0) {
                    // Overpopulation or starvation drives mortality
                    if (neighbors < 2 || neighbors > (if (aggro) 4 else 3)) {
                        nextGrid[y][x] = 0
                    } else {
                        // Mutation based on mid-frequency spectral intensity
                        nextGrid[y][x] = if (Random.nextDouble() < mutationRate) {
                            (current % (dnaChars.size - 1)) + 1
                        } else current
                    }
                } else {
                    // Reproduction driven by high overtones
                    if (neighbors >= birthThreshold && neighbors <= 3) {
                        val avgState = if (neighbors > 0) neighborStateSum / neighbors else 1
                        nextGrid[y][x] = avgState.coerceIn(1, dnaChars.size - 1)
                    }
                }
            }
        }

        grid = nextGrid

        // Render ASCII Automaton Frame
        val sb = StringBuilder("\u001B[H")
        for (y in 0 until height) {
            for (x in 0 until width) {
                val state = grid[y][x]
                sb.append(dnaChars[state.coerceIn(0, dnaChars.size - 1)])
            }
            sb.append("\n")
        }
        print(sb.toString())

        samplePointer += samplesPerFrame
        Thread.sleep(frameIntervalMs)
    }
    
    print("\u001B[?25h") // Restore cursor
}
main(emptyArray())