import java.lang.management.ManagementFactory
import com.sun.management.OperatingSystemMXBean
import java.awt.*
import java.awt.geom.Path2D
import javax.swing.*
import kotlin.math.*

// Node in the functional tree layout representing an anatomical organ/segment
data class BodyNode(
    val id: String,
    val type: NodeType,
    val relativeSize: Float,
    val children: List<BodyNode> = emptyList()
)

enum class NodeType { CORE, BRANCH, SENSOR, FIN, GLOW_ORB }

// Gene parameters derived functionally from system metrics
data class OrganismPhenotype(
    val bodyScale: Float,
    val pulseSpeed: Float,
    val colorHue: Float,
    val branchAngle: Float,
    val complexity: Int,
    val vigor: Float,
    val energyColor: Color
)

// Main simulation canvas
class OrganismPanel : JPanel() {
    private var time = 0.0f
    private val osBean = ManagementFactory.getPlatformMXBean(OperatingSystemMXBean::class.java)

    init {
        preferredSize = Dimension(1000, 800)
        background = Color(10, 14, 26)

        // Smooth 60 FPS animation timer
        Timer(16) {
            time += 0.03f
            repaint()
        }.start()
    }

    override fun paintComponent(g: Graphics) {
        super.paintComponent(g)
        val g2 = g as Graphics2D
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)
        g2.setRenderingHint(RenderingHints.KEY_STROKE_CONTROL, RenderingHints.VALUE_STROKE_PURE)

        // 1. Fetch Real-time System Metrics
        val cpuLoad = (osBean.cpuLoad.takeIf { !it.isNaN() && it >= 0 } ?: 0.15).toFloat()
        val totalMem = Runtime.getRuntime().totalMemory()
        val freeMem = Runtime.getRuntime().freeMemory()
        val memUsage = ((totalMem - freeMem).toDouble() / totalMem).toFloat()

        // 2. Functional Genome Mapping (System Metrics -> Phenotype)
        val phenotype = expressGenome(cpuLoad, memUsage, time)

        // 3. Functional Layout Tree Generation
        val genomeTree = generateGenomeTree(phenotype.complexity)

        // 4. Render Organism at Canvas Center
        val centerX = width / 2.0
        val centerY = height / 2.0

        // Draw ambient glow under organism
        val glowRadius = (200 * phenotype.bodyScale).coerceAtLeast(20f)
        val radialGlow = RadialGradientPaint(
            centerX.toFloat(), centerY.toFloat(), glowRadius,
            floatArrayOf(0.0f, 1.0f),
            arrayOf(Color(phenotype.energyColor.red, phenotype.energyColor.green, phenotype.energyColor.blue, 60), Color(0, 0, 0, 0))
        )
        g2.paint = radialGlow
        g2.fillOval((centerX - glowRadius).toInt(), (centerY - glowRadius).toInt(), (glowRadius * 2).toInt(), (glowRadius * 2).toInt())

        // Render recursive functional layout (Symmetrical organism morphology)
        renderNode(g2, genomeTree, centerX, centerY, -Math.PI / 2, 70.0 * phenotype.bodyScale, phenotype, 0)
        renderNode(g2, genomeTree, centerX, centerY, Math.PI / 2, 70.0 * phenotype.bodyScale, phenotype, 0)

        // Render HUD Overlay
        renderHUD(g2, cpuLoad, memUsage)
    }

    // Pure function mapping system metrics to organism traits
    private fun expressGenome(cpu: Float, mem: Float, t: Float): OrganismPhenotype {
        val pulse = sin(t * (1.0f + cpu * 4.0f)) * 0.5f + 0.5f
        val hue = (0.55f + mem * 0.45f) % 1.0f // Blue/Cyan at low memory, Shift to Magenta/Red at high memory
        val energyCol = Color.getHSBColor(hue, 0.8f, 1.0f)

        return OrganismPhenotype(
            bodyScale = 0.8f + cpu * 0.6f + pulse * 0.05f,
            pulseSpeed = 1.0f + cpu * 5.0f,
            colorHue = hue,
            branchAngle = Math.toRadians(20.0 + mem * 50.0 + sin(t) * 10.0).toFloat(),
            complexity = (3 + (mem * 4).toInt()).coerceIn(3, 7),
            vigor = pulse,
            energyColor = energyCol
        )
    }

    // Generates a recursive genetic node structure
    private fun generateGenomeTree(depth: Int): BodyNode {
        if (depth <= 0) return BodyNode("leaf", NodeType.GLOW_ORB, 0.4f)
        
        val children = mutableListOf<BodyNode>()
        children.add(generateGenomeTree(depth - 1))
        if (depth % 2 == 0) {
            children.add(BodyNode("fin", NodeType.FIN, 0.6f))
        } else {
            children.add(generateGenomeTree(depth - 2))
        }
        
        return BodyNode("segment_$depth", if (depth > 4) NodeType.CORE else NodeType.BRANCH, 0.85f, children)
    }

    // Recursive Functional Renderer converting node tree into screen geometry
    private fun renderNode(
        g2: Graphics2D,
        node: BodyNode,
        x: Double,
        y: Double,
        angle: Double,
        length: Double,
        pheno: OrganismPhenotype,
        depth: Int
    ) {
        if (length < 3) return

        // Compute endpoint with wavy dynamic motion
        val wave = sin(time * pheno.pulseSpeed + depth) * 0.1
        val currentAngle = angle + wave
        val nextX = x + cos(currentAngle) * length
        val nextY = y + sin(currentAngle) * length

        // Dynamic stroke styling based on biological depth
        val alpha = (255 - depth * 25).coerceIn(60, 255)
        val baseColor = Color.getHSBColor((pheno.colorHue + depth * 0.03f) % 1.0f, 0.7f, 0.9f)
        g2.color = Color(baseColor.red, baseColor.green, baseColor.blue, alpha)

        val thickness = (length * 0.25f).toFloat().coerceAtLeast(1.5f)
        g2.stroke = BasicStroke(thickness, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND)

        // Draw bone/neural connection
        g2.draw(Path2D.Double().apply {
            moveTo(x, y)
            curveTo(
                x + cos(currentAngle) * length * 0.5,
                y + sin(currentAngle) * length * 0.5,
                nextX - cos(currentAngle) * length * 0.2,
                nextY - sin(currentAngle) * length * 0.2,
                nextX, nextY
            )
        })

        // Render anatomical structures based on node type
        when (node.type) {
            NodeType.FIN -> {
                val finPath = Path2D.Double().apply {
                    moveTo(x, y)
                    lineTo(x + cos(currentAngle + 1.2) * length * 0.8, y + sin(currentAngle + 1.2) * length * 0.8)
                    lineTo(nextX, nextY)
                    closePath()
                }
                g2.color = Color(pheno.energyColor.red, pheno.energyColor.green, pheno.energyColor.blue, 40)
                g2.fill(finPath)
            }
            NodeType.GLOW_ORB -> {
                val orbSize = (8.0 + pheno.vigor * 6.0)
                g2.color = pheno.energyColor
                g2.fillOval((nextX - orbSize / 2).toInt(), (nextY - orbSize / 2).toInt(), orbSize.toInt(), orbSize.toInt())
            }
            else -> {}
        }

        // Functional branching layout
        val childLength = length * node.relativeSize
        node.children.forEachIndexed { index, child ->
            val branchSign = if (index % 2 == 0) 1 else -1
            val branchSpread = pheno.branchAngle * branchSign
            renderNode(g2, child, nextX, nextY, currentAngle + branchSpread, childLength, pheno, depth + 1)
        }
    }

    // Render system diagnostic telemetry HUD
    private fun renderHUD(g2: Graphics2D, cpu: Float, mem: Float) {
        g2.color = Color(255, 255, 255, 200)
        g2.font = Font("Monospaced", Font.BOLD, 13)
        
        g2.drawString("GENETIC SYSTEM METRICS MONITOR", 20, 30)
        g2.font = Font("Monospaced", Font.PLAIN, 12)
        
        // CPU Bar (Metabolism)
        g2.drawString(String.format("CPU Load  (Metabolism Speed): %5.1f%%", cpu * 100), 20, 55)
        g2.color = Color(255, 255, 255, 40)
        g2.fillRect(20, 62, 200, 8)
        g2.color = Color.CYAN
        g2.fillRect(20, 62, (200 * cpu).toInt(), 8)

        // Memory Bar (Morphology Depth)
        g2.color = Color(255, 255, 255, 200)
        g2.drawString(String.format("RAM Usage (Somatic Complexity): %5.1f%%", mem * 100), 20, 90)
        g2.color = Color(255, 255, 255, 40)
        g2.fillRect(20, 97, 200, 8)
        g2.color = Color.MAGENTA
        g2.fillRect(20, 97, (200 * mem).toInt(), 8)
    }
}

fun main() {
    SwingUtilities.invokeLater {
        val frame = JFrame("Artificial Organism - Functional Genetic Simulation")
        frame.defaultCloseOperation = JFrame.EXIT_ON_CLOSE
        frame.isResizable = false
        frame.add(OrganismPanel())
        frame.pack()
        frame.setLocationRelativeTo(null)
        frame.isVisible = true
    }
}