import java.awt.Color
import java.awt.Graphics2D
import java.awt.RenderingHints
import java.awt.image.BufferedImage
import java.io.File
import java.lang.management.ManagementFactory
import javax.imageio.ImageIO
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

// 1. GENE DATA STRUCTURE: Encapsulates fractal tree structural parameters
data class TreeGene(
    val depth: Int,
    val branchAngle: Double,
    val lengthRatio: Double,
    val initialLength: Double,
    val colorHueStart: Float,
    val colorHueEnd: Float
) {
    // Computes fitness based on how balanced, deep, and visually spread out the tree is
    fun fitness(): Double {
        val depthScore = depth.toDouble() / 10.0
        val angleScore = 1.0 - Math.abs(branchAngle - Math.PI / 6.0) / (Math.PI / 2.0)
        val ratioScore = 1.0 - Math.abs(lengthRatio - 0.7) / 0.5
        return (depthScore + angleScore + ratioScore) / 3.0
    }

    // Mutates gene properties using a dynamic mutation rate linked to live memory usage
    fun mutate(mutationRate: Double): TreeGene {
        fun mutateVal(valIn: Double, min: Double, max: Double): Double {
            return if (Random.nextDouble() < mutationRate) {
                (valIn + Random.nextDouble(-0.1, 0.1) * (max - min)).coerceIn(min, max)
            } else valIn
        }

        val newDepth = if (Random.nextDouble() < mutationRate) {
            (depth + Random.nextInt(-1, 2)).coerceIn(3, 9)
        } else depth

        return TreeGene(
            depth = newDepth,
            branchAngle = mutateVal(branchAngle, 0.1, Math.PI / 2),
            lengthRatio = mutateVal(lengthRatio, 0.5, 0.85),
            initialLength = mutateVal(initialLength, 60.0, 140.0),
            colorHueStart = mutateVal(colorHueStart.toDouble(), 0.0, 1.0).toFloat(),
            colorHueEnd = mutateVal(colorHueEnd.toDouble(), 0.0, 1.0).toFloat()
        )
    }

    // Code generator: Generates executable Kotlin code for rendering this specific fractal
    fun toRenderFunction(): String {
        return """
        fun drawFractal(g: Graphics2D, x: Double, y: Double, angle: Double, length: Double, currentDepth: Int) {
            if (currentDepth <= 0 || length < 2) return
            
            val progress = 1.0 - (currentDepth.toDouble() / $depth.0)
            val hue = ${colorHueStart}f + progress.toFloat() * (${colorHueEnd}f - ${colorHueStart}f)
            g.color = Color.getHSBColor(hue.coerceIn(0f, 1f), 0.85f, 0.9f)
            g.stroke = java.awt.BasicStroke(Math.max(1f, currentDepth.toFloat() * 1.2f))
            
            val x2 = x + length * sin(angle)
            val y2 = y - length * cos(angle)
            g.drawLine(x.toInt(), y.toInt(), x2.toInt(), y2.toInt())
            
            drawFractal(g, x2, y2, angle + $branchAngle, length * $lengthRatio, currentDepth - 1)
            drawFractal(g, x2, y2, angle - $branchAngle, length * $lengthRatio, currentDepth - 1)
        }
        """.trimIndent()
    }
}

// 2. LIVE MEMORY DRIVER: Calculates current heap memory usage ratio [0.0 to 1.0]
fun getDynamicMutationRate(): Double {
    val memoryMXBean = ManagementFactory.getMemoryMXBean()
    val heapUsage = memoryMXBean.heapMemoryUsage
    val used = heapUsage.used.toDouble()
    val max = heapUsage.max.toDouble()
    val usageRatio = used / max
    // Base mutation rate scales from 5% up to 80% based on memory pressure
    return (0.05 + usageRatio * 0.75).coerceIn(0.01, 0.95)
}

// 3. GENETIC ALGORITHM ENGINE
fun evolveTree(generations: Int = 50, popSize: Int = 20): TreeGene {
    var population = List(popSize) {
        TreeGene(
            depth = Random.nextInt(4, 8),
            branchAngle = Random.nextDouble(0.2, 0.8),
            lengthRatio = Random.nextDouble(0.55, 0.75),
            initialLength = Random.nextDouble(70.0, 120.0),
            colorHueStart = Random.nextFloat(),
            colorHueEnd = Random.nextFloat()
        )
    }

    println("Evolving Fractal Code over $generations generations...")

    for (gen in 1..generations) {
        val mutationRate = getDynamicMutationRate()
        population = population.sortedByDescending { it.fitness() }

        if (gen % 10 == 0 || gen == generations) {
            println("Gen $gen | Best Fitness: %.4f | Dynamic Mutation Rate (Memory Driven): %.2f%%"
                .format(population.first().fitness(), mutationRate * 100))
        }

        val elites = population.take(popSize / 4)
        val nextGen = elites.toMutableList()

        while (nextGen.size < popSize) {
            val parent = elites.random()
            nextGen.add(parent.mutate(mutationRate))
        }
        population = nextGen
    }

    return population.maxByOrNull { it.fitness() }!!
}

// 4. SELF-WRITING SCRIPT GENERATOR & RENDERER
fun main() {
    val bestGene = evolveTree(generations = 40, popSize = 30)

    // Render visual output to image
    val width = 800
    val height = 800
    val image = BufferedImage(width, height, BufferedImage.TYPE_INT_RGB)
    val g = image.createGraphics()
    g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)
    g.color = Color(15, 15, 25)
    g.fillRect(0, 0, width, height)

    // Embedded recursive renderer using evolved parameters
    fun renderTree(x: Double, y: Double, angle: Double, length: Double, currentDepth: Int) {
        if (currentDepth <= 0 || length < 2) return
        val progress = 1.0 - (currentDepth.toDouble() / bestGene.depth.toDouble())
        val hue = (bestGene.colorHueStart + progress * (bestGene.colorHueEnd - bestGene.colorHueStart)).toFloat()
        g.color = Color.getHSBColor(hue.coerceIn(0f, 1f), 0.85f, 0.9f)
        g.stroke = java.awt.BasicStroke(Math.max(1f, currentDepth.toFloat() * 1.2f))

        val x2 = x + length * sin(angle)
        val y2 = y - length * cos(angle)
        g.drawLine(x.toInt(), y.toInt(), x2.toInt(), y2.toInt())

        renderTree(x2, y2, angle + bestGene.branchAngle, length * bestGene.lengthRatio, currentDepth - 1)
        renderTree(x2, y2, angle - bestGene.branchAngle, length * bestGene.lengthRatio, currentDepth - 1)
    }

    renderTree(width / 2.0, height - 80.0, 0.0, bestGene.initialLength, bestGene.depth)
    g.dispose()

    val outputFile = File("EvolvedFractalTree.png")
    ImageIO.write(image, "png", outputFile)
    println("\n[Visual Output] Fractal rendered to: ${outputFile.absolutePath}")

    // Generate the self-written Kotlin code file
    val selfWrittenCode = """
    // ========================================================
    // AUTO-GENERATED EVOLVED FRACTAL TREE SCRIPT
    // Evolved parameters via Memory-Driven Genetic Algorithm
    // ========================================================
    import java.awt.*
    import java.awt.image.BufferedImage
    import java.io.File
    import javax.imageio.ImageIO
    import kotlin.math.*

    ${bestGene.toRenderFunction()}

    fun main() {
        val width = 800
        val height = 800
        val img = BufferedImage(width, height, BufferedImage.TYPE_INT_RGB)
        val g = img.createGraphics()
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)
        g.color = Color(10, 10, 20)
        g.fillRect(0, 0, width, height)

        drawFractal(g, 400.0, 720.0, 0.0, ${bestGene.initialLength}, ${bestGene.depth})
        g.dispose()

        val out = File("EvolvedTreeResult.png")
        ImageIO.write(img, "png", out)
        println("Generated fractal image successfully saved to: " + out.absolutePath)
    }
    """.trimIndent()

    val sourceFile = File("EvolvedTreeProgram.kt")
    sourceFile.writeText(selfWrittenCode)
    println("[Self-Writing] Evolved source code successfully written to: ${sourceFile.absolutePath}")
}