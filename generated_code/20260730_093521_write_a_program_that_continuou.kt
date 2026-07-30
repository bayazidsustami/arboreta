import java.awt.Color
import java.awt.Dimension
import java.awt.Graphics
import java.awt.image.BufferedImage
import java.io.File
import javax.swing.JFrame
import javax.swing.JPanel
import javax.swing.SwingUtilities
import javax.swing.Timer
import kotlin.math.*

/**
 * Surrealist AST Raymarched Labyrinth
 * 
 * Self-parsing Kotlin application that inspects its own code structure
 * (cyclomatic complexity & nesting depth of functions) to procedurally
 * drive the signed distance field (SDF), volumetric lighting, and procedural
 * texturing of a 3D raymarched surrealist maze.
 */

data class FunctionAstNode(
    val name: String,
    val cyclomaticComplexity: Int,
    val maxNestingDepth: Int,
    val lineCount: Int
)

class AstAnalyzer(private val sourceCode: String) {
    fun extractFunctionMetrics(): List<FunctionAstNode> {
        val lines = sourceCode.lines()
        val nodes = mutableListOf<FunctionAstNode>()
        
        var currentFunName: String? = null
        var currentComplexity = 1
        var currentDepth = 0
        var maxDepth = 0
        var startLine = 0
        var braceBalance = 0

        val decisionKeywords = listOf("if", "else if", "when", "for", "while", "catch", "&&", "||", "?:")

        lines.forEachIndexed { index, line ->
            val trimmed = line.trim()
            
            // Match function signature
            val funMatch = Regex("""fun\s+([a-zA-Z0-9_<>, ]+)\s*\(""").find(trimmed)
            if (funMatch != null && currentFunName == null) {
                currentFunName = funMatch.groupValues[1].take(15)
                currentComplexity = 1
                currentDepth = 0
                maxDepth = 0
                startLine = index
                braceBalance = 0
            }

            if (currentFunName != null) {
                decisionKeywords.forEach { kw ->
                    if (line.contains(kw)) currentComplexity++
                }

                val openBraces = line.count { it == '{' }
                val closeBraces = line.count { it == '}' }
                
                braceBalance += openBraces - closeBraces
                currentDepth += openBraces
                if (currentDepth > maxDepth) maxDepth = currentDepth
                currentDepth -= closeBraces

                if (braceBalance <= 0 && (openBraces > 0 || closeBraces > 0)) {
                    nodes.add(
                        FunctionAstNode(
                            name = currentFunName!!,
                            cyclomaticComplexity = currentComplexity,
                            maxNestingDepth = maxDepth,
                            lineCount = index - startLine + 1
                        )
                    )
                    currentFunName = null
                }
            }
        }

        // Fallback default node if no function detected
        if (nodes.isEmpty()) {
            nodes.add(FunctionAstNode("default", 5, 3, 100))
        }

        return nodes
    }
}

class RaymarchedLabyrinthPanel : JPanel() {
    private val widthRes = 320
    private val heightRes = 240
    private val image = BufferedImage(widthRes, heightRes, BufferedImage.TYPE_INT_RGB)
    
    private var time = 0.0
    private var astNodes: List<FunctionAstNode> = emptyList()
    private var sourceText = ""

    init {
        preferredSize = Dimension(960, 720)
        loadSelfSource()
        parseAst()

        // 60 FPS Animation loop
        Timer(16) {
            time += 0.03
            renderFrame()
            repaint()
        }.start()
    }

    private fun loadSelfSource() {
        sourceText = try {
            val classPath = System.getProperty("user.dir")
            val candidateFiles = File(classPath).walkTopDown()
                .filter { it.extension == "kt" }
                .toList()
            
            if (candidateFiles.isNotEmpty()) candidateFiles.first().readText()
            else getFallbackSource()
        } catch (e: Exception) {
            getFallbackSource()
        }
    }

    private fun parseAst() {
        astNodes = AstAnalyzer(sourceText).extractFunctionMetrics()
    }

    private fun getFallbackSource(): String {
        return """
            fun raymarch(ro: Vec3, rd: Vec3): Color {
                if (depth > max) return black
                when(type) { 1 -> loop(); 2 -> recurse() }
                for(i in 0..10) { if(hit) break }
            }
            fun sdfRoom(p: Vec3): Double {
                if(p.x > 0) return min(p.y, p.z)
            }
        """.trimIndent()
    }

    // --- Vector Math Utilities ---
    private data class Vec3(val x: Double, val y: Double, val z: Double) {
        operator fun plus(v: Vec3) = Vec3(x + v.x, y + v.y, z + v.z)
        operator fun minus(v: Vec3) = Vec3(x - v.x, y - v.y, z - v.z)
        operator fun times(s: Double) = Vec3(x * s, y * s, z * s)
        fun length() = sqrt(x * x + y * y + z * z)
        fun normalize(): Vec3 {
            val l = length()
            return if (l == 0.0) Vec3(0.0, 0.0, 0.0) else Vec3(x / l, y / l, z / l)
        }
        fun mod(m: Double) = Vec3(
            (x % m + m) % m - m * 0.5,
            (y % m + m) % m - m * 0.5,
            (z % m + m) % m - m * 0.5
        )
    }

    // --- Procedural Signed Distance Fields (SDF) driven by AST Metrics ---
    private fun mapSDF(p: Vec3): Double {
        val totalComplexity = astNodes.sumOf { it.cyclomaticComplexity }.toDouble().coerceAtLeast(1.0)
        val avgNesting = astNodes.map { it.maxNestingDepth }.average().coerceAtLeast(1.0)
        val funcCount = astNodes.size.toDouble().coerceAtLeast(1.0)

        // Cell repetition size dictated by complexity
        val cellSize = 6.0 + (totalComplexity % 4.0)
        val repeatedP = p.mod(cellSize)

        // Wall & Corridor Geometry derived from nesting depth
        val wallThickness = 0.2 + (avgNesting * 0.1)
        val roomBox = max(abs(repeatedP.x), max(abs(repeatedP.y), abs(repeatedP.z))) - (cellSize * 0.45)
        
        // Surrealist Pillars sculpted by function count
        val pillarRadius = 0.15 + (funcCount * 0.03)
        val pillar = sqrt(repeatedP.x * repeatedP.x + repeatedP.z * repeatedP.z) - pillarRadius

        // Dynamic twist factor calculated from individual node metrics
        val twistStrength = sin(p.y * 0.3 + time) * (avgNesting * 0.15)
        val c = cos(twistStrength)
        val s = sin(twistStrength)
        val twistedX = c * repeatedP.x - s * repeatedP.z
        val twistedZ = s * repeatedP.x + c * repeatedP.z
        val twistedDist = sqrt(twistedX * twistedX + twistedZ * twistedZ) - (pillarRadius * 1.2)

        // Combine SDF primitives
        val baseLabyrinth = max(roomBox, -pillar)
        val surrealDisplacement = sin(p.x * 0.5) * cos(p.y * 0.5) * sin(p.z * 0.5) * (totalComplexity * 0.02)

        return min(baseLabyrinth, twistedDist) + surrealDisplacement
    }

    private fun calcNormal(p: Vec3): Vec3 {
        val eps = 0.001
        val d = mapSDF(p)
        val nx = mapSDF(Vec3(p.x + eps, p.y, p.z)) - d
        val ny = mapSDF(Vec3(p.x, p.y + eps, p.z)) - d
        val nz = mapSDF(Vec3(p.x, p.y, p.z + eps)) - d
        return Vec3(nx, ny, nz).normalize()
    }

    private fun renderFrame() {
        // Camera Path traversing through the self-generated AST matrix
        val camX = sin(time * 0.4) * 8.0
        val camY = time * 1.5
        val camZ = cos(time * 0.4) * 8.0
        val ro = Vec3(camX, camY, camZ)

        // Target point
        val target = Vec3(sin(time * 0.4 + 0.5) * 8.0, camY + 2.0, cos(time * 0.4 + 0.5) * 8.0)
        val forward = (target - ro).normalize()
        val right = Vec3(0.0, 1.0, 0.0).let { up ->
            Vec3(
                forward.y * up.z - forward.z * up.y,
                forward.z * up.x - forward.x * up.z,
                forward.x * up.y - forward.y * up.x
            ).normalize()
        }
        val up = Vec3(
            right.y * forward.z - right.z * forward.y,
            right.z * forward.x - right.x * forward.z,
            right.x * forward.y - right.y * forward.x
        )

        val totalComplexity = astNodes.sumOf { it.cyclomaticComplexity }
        val maxNesting = astNodes.maxOfOrNull { it.maxNestingDepth } ?: 1

        for (y in 0 until heightRes) {
            val v = (1.0 - 2.0 * y / heightRes.toDouble()) * (heightRes.toDouble() / widthRes)
            for (x in 0 until widthRes) {
                val u = (2.0 * x / widthRes.toDouble()) - 1.0

                val rd = (right * u + up * v + forward).normalize()

                // Raymarching loop
                var t = 0.0
                var hit = false
                var p = ro
                val maxSteps = 48
                val maxDist = 30.0

                for (step in 0 until maxSteps) {
                    p = ro + rd * t
                    val dist = mapSDF(p)
                    if (dist < 0.005) {
                        hit = true
                        break
                    }
                    t += dist
                    if (t >= maxDist) break
                }

                val pixelColor = if (hit) {
                    val normal = calcNormal(p)
                    val lightDir = Vec3(sin(time), 1.0, cos(time)).normalize()
                    val diff = max(0.0, normal.x * lightDir.x + normal.y * lightDir.y + normal.z * lightDir.z)
                    
                    // Texture & Shading driven by AST metrics
                    val stripePattern = (sin(p.x * 2.0 + p.y * 2.0) * 0.5 + 0.5)
                    val r = ((sin(p.z * 0.2 + totalComplexity) * 0.5 + 0.5) * diff * 255).toInt().coerceIn(0, 255)
                    val g = ((stripePattern * (maxNesting / 10.0).coerceAtMost(1.0)) * diff * 255).toInt().coerceIn(0, 255)
                    val b = ((cos(p.y * 0.1) * 0.5 + 0.5) * diff * 255).toInt().coerceIn(0, 255)

                    // Depth Fog
                    val fogFactor = exp(-t * 0.08)
                    val fogR = (20 * (1 - fogFactor)).toInt()
                    val fogG = (10 * (1 - fogFactor)).toInt()
                    val fogB = (40 * (1 - fogFactor)).toInt()

                    Color(
                        (r * fogFactor + fogR).toInt().coerceIn(0, 255),
                        (g * fogFactor + fogG).toInt().coerceIn(0, 255),
                        (b * fogFactor + fogB).toInt().coerceIn(0, 255)
                    ).rgb
                } else {
                    // Deep surreal void
                    val voidG = (10 + sin(time + y * 0.05) * 10).toInt().coerceIn(0, 255)
                    Color(5, voidG, 25).rgb
                }

                image.setRGB(x, y, pixelColor)
            }
        }
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        g.drawImage(image, 0, 0, width, height, null)

        // Overlay AST Stats HUD
        g.color = Color(0, 255, 180, 220)
        g.drawString("AST RAYMARCHED LABYRINTH", 20, 30)
        g.color = Color.WHITE
        g.drawString("Functions Parsed: ${astNodes.size}", 20, 50)
        
        astNodes.take(5).forEachIndexed { i, node ->
            g.drawString(
                "fn ${node.name}() -> Complexity: ${node.cyclomaticComplexity} | Nesting: ${node.maxNestingDepth}",
                20, 70 + (i * 18)
            )
        }
    }
}

fun main() {
    SwingUtilities.invokeLater {
        val frame = JFrame("AST Procedural Raymarched Labyrinth")
        val panel = RaymarchedLabyrinthPanel()
        frame.add(panel)
        frame.pack()
        frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
        frame.setLocationRelativeTo(null)
        frame.isVisible = true
    }
}