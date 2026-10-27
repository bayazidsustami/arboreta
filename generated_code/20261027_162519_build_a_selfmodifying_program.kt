import java.io.File
import kotlin.math.sin
import kotlin.math.abs

// A self-modifying melancholic thermal haiku generator in Kotlin.
// It reads CPU thermal state, rewrites its own source to log the thermal memory,
// and crafts a transient, sorrowful verse whose syllable structure mirrors the hardware's fever.

fun getCpuTemperature(): Int {
    try {
        val thermalFile = File("/sys/class/thermal/thermal_zone0/temp")
        if (thermalFile.exists()) {
            val milliC = thermalFile.readText().trim().toInt()
            return milliC / 1000
        }
    } catch (_: Exception) {}
    
    // Fallback simulation based on system time and sine wave if thermal zone is unavailable
    val timeSec = System.currentTimeMillis() / 1000.0
    return 45 + (abs(sin(timeSec / 10.0) * 15)).toInt()
}

fun countSyllables(word: String): Int {
    val vowels = "aeiouy"
    var count = 0
    var prevIsVowel = false
    val lower = word.lowercase()
    for (i in lower.indices) {
        val isVowel = vowels.contains(lower[i])
        if (isVowel && !prevIsVowel) {
            count++
        }
        prevIsVowel = isVowel
    }
    if (lower.endsWith("e") && count > 1) count--
    return maxOf(1, count)
}

fun generateLine(targetSyllables: Int): String {
    val melancholicPool = listOf(
        "cold", "silence", "ash", "dark", "void", "ghost", "tears", "rust", 
        "iron", "breath", "pain", "night", "fade", "loss", "dust", "frost",
        "heavy", "broken", "fading", "hollow", "bleeding", "silent", "frozen",
        "shattered", "waning", "somber", "endless", "bitter", "memory"
    )
    val selected = mutableListOf<String>()
    var currentSyllables = 0
    
    while (currentSyllables < targetSyllables) {
        val candidate = melancholicPool.random()
        val syl = countSyllables(candidate)
        if (currentSyllables + syl <= targetSyllables) {
            selected.add(candidate)
            currentSyllables += syl
        } else if (selected.isEmpty()) {
            selected.add(candidate)
            currentSyllables += syl
        }
    }
    return selected.joinToString(" ")
}

fun selfModify(temp: Int) {
    try {
        val scriptPath = System.getProperty("sun.java.command")?.split(" ")?.first()
        if (scriptPath != null) {
            val scriptFile = File(scriptPath)
            if (scriptFile.exists() && scriptFile.canWrite()) {
                var content = scriptFile.readText()
                val marker = "// LAST_RECORDED_TEMP:"
                if (content.contains(marker)) {
                    content = content.replace(Regex("$marker.*"), "$marker $temp")
                    scriptFile.writeText(content)
                }
            }
        }
    } catch (_: Exception) {}
}

// LAST_RECORDED_TEMP: 45

fun main() {
    val temp = getCpuTemperature()
    selfModify(temp)

    // Map temperature to a dynamic haiku structure modulated by thermal deviation
    val baseTemp = 50
    val delta = temp - baseTemp
    
    val line1 = 5 + (delta / 10).coerceIn(-1, 1)
    val line2 = 7 + (delta / 5).coerceIn(-2, 2)
    val line3 = 5 + (delta / 10).coerceIn(-1, 1)

    println("CPU Temperature: ${temp}°C")
    println("Thermal Haiku (${line1}-${line2}-${line3}):")
    println(generateLine(line1))
    println(generateLine(line2))
    println(generateLine(line3))
}