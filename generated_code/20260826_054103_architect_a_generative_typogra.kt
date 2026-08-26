import java.io.File
import kotlin.math.*

// ---------------------------------------------------------------------------
// Generative Typography Engine: Compiles emotional valence/arousal into 
// procedural CSS keyframes and renders dynamically deforming SVG letterforms.
// ---------------------------------------------------------------------------

enum class Emotion(val valence: Double, val arousal: Double, val primaryColor: String, val glowColor: String) {
    JOY(0.9, 0.8, "#FFD700", "#FF8C00"),
    SERENITY(0.8, 0.2, "#00FA9A", "#00FFFF"),
    ANGER(-0.8, 0.9, "#FF1493", "#FF0000"),
    MELANCHOLY(-0.7, -0.6, "#4682B4", "#191970"),
    EUPHORIA(0.95, 0.95, "#FF00FF", "#7B68EE"),
    NEUTRAL(0.0, 0.0, "#E0E0E0", "#A9A9A9")
}

data class EmotionalProfile(
    val emotion: Emotion,
    val intensity: Double,
    val cadenceSpeed: Double, // Animation duration modifier (seconds)
    val warpFactor: Double    // Amplitude of SVG control point displacement
)

class EmotionAnalyzer {
    private val lexicon = mapOf(
        "happy" to Emotion.JOY, "joy" to Emotion.JOY, "bright" to Emotion.JOY, "sun" to Emotion.JOY,
        "calm" to Emotion.SERENITY, "peace" to Emotion.SERENITY, "soft" to Emotion.SERENITY, "still" to Emotion.SERENITY, "quiet" to Emotion.SERENITY,
        "fury" to Emotion.ANGER, "rage" to Emotion.ANGER, "burn" to Emotion.ANGER, "storm" to Emotion.ANGER, "fire" to Emotion.ANGER,
        "sad" to Emotion.MELANCHOLY, "gloom" to Emotion.MELANCHOLY, "dark" to Emotion.MELANCHOLY, "rain" to Emotion.MELANCHOLY, "cry" to Emotion.MELANCHOLY,
        "ecstasy" to Emotion.EUPHORIA, "wild" to Emotion.EUPHORIA, "magic" to Emotion.EUPHORIA, "dance" to Emotion.EUPHORIA
    )

    fun analyze(text: String): EmotionalProfile {
        val words = text.lowercase().split(Regex("\\s+"))
        var totalValence = 0.0
        var totalArousal = 0.0
        var matches = 0

        for (word in words) {
            lexicon[word]?.let {
                totalValence += it.valence
                totalArousal += it.arousal
                matches++
            }
        }

        if (matches == 0) return EmotionalProfile(Emotion.NEUTRAL, 0.5, 3.0, 5.0)

        val avgValence = totalValence / matches
        val avgArousal = totalArousal / matches

        // Find nearest emotion cluster
        val dominant = Emotion.values().minByOrNull { 
            hypot(it.valence - avgValence, it.arousal - avgArousal) 
        } ?: Emotion.NEUTRAL

        val intensity = min(1.0, max(0.2, hypot(avgValence, avgArousal)))
        val cadenceSpeed = (2.5 - (avgArousal * 1.8)).coerceIn(0.4, 4.0)
        val warpFactor = (intensity * 25.0) + 2.0

        return EmotionalProfile(dominant, intensity, cadenceSpeed, warpFactor)
    }
}

class ProceduralCSSGenerator {
    fun generateVariablesAndKeyframes(profile: EmotionalProfile): String {
        val color = profile.emotion.primaryColor
        val glow = profile.emotion.glowColor
        val duration = String.format("%.2fs", profile.cadenceSpeed)

        return """
        :root {
            --emo-primary: $color;
            --emo-glow: $glow;
            --emo-duration: $duration;
            --emo-warp: ${profile.warpFactor}px;
            --emo-scale: ${1.0 + (profile.intensity * 0.15)};
        }

        @keyframes emotionalCadence {
            0% {
                transform: scale(1.0) rotate(0deg);
                filter: drop-shadow(0 0 5px var(--emo-glow));
            }
            33% {
                transform: scale(var(--emo-scale)) rotate(${profile.emotion.arousal * 3}deg);
                filter: drop-shadow(0 0 ${15 * profile.intensity}px var(--emo-primary));
            }
            66% {
                transform: scale(${1.0 / (1.0 + profile.intensity * 0.1)}) rotate(${-profile.emotion.arousal * 2}deg);
                filter: drop-shadow(0 0 ${25 * profile.intensity}px var(--emo-glow));
            }
            100% {
                transform: scale(1.0) rotate(0deg);
                filter: drop-shadow(0 0 5px var(--emo-glow));
            }
        }

        .kinetic-letter {
            animation: emotionalCadence var(--emo-duration) infinite ease-in-out;
            transform-origin: center;
            display: inline-block;
        }
        """.trimIndent()
    }
}

class DeformableSVGFont {
    // Basic parametric cubic bezier path representation for letter primitives
    private val glyphPaths = mapOf(
        'A' to "M 10 90 Q 50 ${10} 90 90 M 25 60 L 75 60",
        'B' to "M 20 10 L 50 10 C 80 10 80 45 50 45 L 20 45 L 50 45 C 85 45 85 90 50 90 L 20 90 Z",
        'C' to "M 80 25 C 10 10 10 90 80 75",
        'D' to "M 20 10 L 50 10 C 90 10 90 90 50 90 L 20 90 Z",
        'E' to "M 80 10 L 20 10 L 20 90 L 80 90 M 20 50 L 70 50",
        'F' to "M 80 10 L 20 10 L 20 90 M 20 50 L 70 50",
        'G' to "M 80 25 C 10 10 10 90 80 75 L 80 50 L 50 50",
        'H' to "M 20 10 L 20 90 M 80 10 L 80 90 M 20 50 L 80 50",
        'I' to "M 30 10 L 70 10 M 50 10 L 50 90 M 30 90 L 70 90",
        'O' to "M 50 10 C 5 10 5 90 50 90 C 95 90 95 10 50 10 Z",
        'S' to "M 80 20 C 10 5 10 50 50 50 C 90 50 90 95 20 80",
        'T' to "M 10 10 L 90 10 M 50 10 L 50 90"
    )

    fun renderWordSVG(text: String, profile: EmotionalProfile): String {
        val uppercaseText = text.uppercase()
        val svgBuilder = StringBuilder()

        var currentX = 10.0
        val charWidth = 100.0

        for ((index, char) in uppercaseText.withIndex()) {
            val basePath = glyphPaths[char] ?: glyphPaths['O']!!
            val deformedPath = deformPath(basePath, profile, index)

            val delay = String.format("%.2fs", index * 0.1)

            svgBuilder.append("""
                <g transform="translate($currentX, 0)" class="kinetic-letter" style="animation-delay: $delay;">
                    <path d="$deformedPath" fill="none" stroke="var(--emo-primary)" stroke-width="${4.0 + profile.intensity * 3}" stroke-linecap="round" stroke-linejoin="round"/>
                </g>
            """.trimIndent())

            currentX += charWidth
        }

        val totalWidth = max(200.0, currentX)

        return """
        <svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 $totalWidth 120" width="100%" height="300">
            $svgBuilder
        </svg>
        """.trimIndent()
    }

    // Algorithmic modulation of control points based on emotional valence/arousal harmonics
    private val numberRegex = Regex("[-+]?\\d*\\.?\\d+")

    private fun deformPath(path: String, profile: EmotionalProfile, charOffset: Int): String {
        var count = 0
        return numberRegex.replace(path) { matchResult ->
            val valNum = matchResult.value.toDouble()
            val phase = (count + charOffset) * 1.3
            
            // Harmonic wave offset driven by arousal (frequency) and valence (directional shift)
            val harmonic = sin(phase + profile.emotion.arousal * 3.14) * cos(phase * 0.5 + profile.emotion.valence)
            val shift = harmonic * profile.warpFactor

            count++
            String.format("%.2f", valNum + shift)
        }
    }
}

fun main() {
    val sampleInputs = listOf(
        "A wild fire of fury and storm!",
        "Quiet calm sea under soft night sky",
        "Bright joy sun happy magic dance"
    )

    val analyzer = EmotionAnalyzer()
    val cssGen = ProceduralCSSGenerator()
    val fontGen = DeformableSVGFont()

    val htmlOutput = StringBuilder()
    htmlOutput.append("""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>Generative Emotional Typography</title>
            <style>
                body { background-color: #0b0c10; color: #fff; font-family: monospace; display: flex; flex-direction: column; align-items: center; padding: 40px; }
                .card { background: #1f2833; border-radius: 12px; padding: 24px; margin-bottom: 40px; width: 80%; box-shadow: 0 8px 32px rgba(0,0,0,0.5); }
                h2 { margin-top: 0; color: #66fcf1; }
            </style>
        </head>
        <body>
            <h1>Generative Kinetic Typography Engine</h1>
    """.trimIndent())

    for ((idx, input) in sampleInputs.withIndex()) {
        val profile = analyzer.analyze(input)
        val css = cssGen.generateVariablesAndKeyframes(profile)
        val svg = fontGen.renderWordSVG(input.filter { it.isLetter() }.take(6), profile)

        htmlOutput.append("""
            <div class="card">
                <h2>Input: "$input"</h2>
                <p><strong>Emotion:</strong> ${profile.emotion.name} | <strong>Valence:</strong> ${profile.emotion.valence} | <strong>Arousal:</strong> ${profile.emotion.arousal}</p>
                <style type="text/css">
                    #scope-$idx {
                        $css
                    }
                </style>
                <div id="scope-$idx">
                    $svg
                </div>
            </div>
        """.trimIndent())
    }

    htmlOutput.append("</body></html>")

    val file = File("generative_typography.html")
    file.writeText(htmlOutput.toString())
    println("Generative typography successfully outputted to: ${file.absolutePath}")
}