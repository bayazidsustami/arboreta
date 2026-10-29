import kotlin.math.sin
import kotlin.random.Random

/**
 * FrigoLang Interpreter: A programming language whose execution flow
 * and conditional branching are driven by simulated acoustic frequencies
 * of a kitchen refrigerator compressor hum.
 */

enum class Opcode {
    PUSH, PRINT, ADD, SUB, DUP, JUMP_IF_HUM, HLT
}

data class Instruction(val op: Opcode, val arg: Int = 0)

class RefrigeratorSensor {
    private var time = 0.0
    
    // Simulates the acoustic spectrum of an inverter compressor
    fun sampleFrequencyHz(): Double {
        time += 0.2
        val baseHum = 60.0
        val compressorLoad = 12.0 * sin(time * 0.3)
        val thermalClick = if (Random.nextDouble() < 0.08) 50.0 else 0.0
        return baseHum + compressorLoad + thermalClick + Random.nextDouble(-1.0, 1.0)
    }
}

class FrigoInterpreter(private val program: List<Instruction>) {
    private val sensor = RefrigeratorSensor()
    private val stack = ArrayDeque<Int>()
    private var ip = 0

    fun run() {
        println("=== Initializing FrigoLang Compressor Core ===")
        while (ip in program.indices) {
            val freq = sensor.sampleFrequencyHz()
            print("[Acoustic Freq: ${"%.2f".format(freq)} Hz] ")

            val instruction = program[ip]
            
            when (instruction.op) {
                Opcode.PUSH -> {
                    stack.addLast(instruction.arg)
                    println("Executing PUSH ${instruction.arg}")
                    ip++
                }
                Opcode.PRINT -> {
                    val value = stack.removeLastOrNull() ?: 0
                    println("-> FRIGO OUTPUT: $value")
                    ip++
                }
                Opcode.ADD -> {
                    val b = stack.removeLastOrNull() ?: 0
                    val a = stack.removeLastOrNull() ?: 0
                    stack.addLast(a + b)
                    println("Executing ADD ($a + $b)")
                    ip++
                }
                Opcode.SUB -> {
                    val b = stack.removeLastOrNull() ?: 0
                    val a = stack.removeLastOrNull() ?: 0
                    stack.addLast(a - b)
                    println("Executing SUB ($a - $b)")
                    ip++
                }
                Opcode.DUP -> {
                    val top = stack.lastOrNull() ?: 0
                    stack.addLast(top)
                    println("Executing DUP ($top)")
                    ip++
                }
                Opcode.JUMP_IF_HUM -> {
                    // If compressor frequency surges above 68Hz, acoustic branch triggers!
                    if (freq > 68.0) {
                        println("Compressor acoustic surge detected! Jumping to instruction ${instruction.arg}")
                        ip = instruction.arg
                    } else {
                        println("Steady hum. Continuing normally.")
                        ip++
                    }
                }
                Opcode.HLT -> {
                    println("Refrigerator cooling cycle complete. Halting.")
                    break
                }
            }

            // Simulate hardware tick interval matching compressor vibration
            Thread.sleep(120)
        }
    }
}

fun main() {
    val sampleProgram = listOf(
        Instruction(Opcode.PUSH, 15),
        Instruction(Opcode.PUSH, 25),
        Instruction(Opcode.ADD),
        Instruction(Opcode.DUP),
        Instruction(Opcode.PRINT),
        Instruction(Opcode.JUMP_IF_HUM, 0), // Loops back if compressor hum frequency spikes
        Instruction(Opcode.HLT)
    )

    val interpreter = FrigoInterpreter(sampleProgram)
    interpreter.run()
}