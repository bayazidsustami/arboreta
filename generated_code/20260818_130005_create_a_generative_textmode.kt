import java.io.File
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/**
 * Generative Text-Mode Astrolabe Star Chart Renderer
 * Transforms source code into an astronomical constellation map using Unicode symbols.
 * Represents control flow (branches), memory allocations (nodes), and complexity (brightness/rings).
 */

enum class StarType(val symbol: String, val category: String) {
    ALLOCATION("✧", "Memory Allocation"),
    BRANCH("✦", "Control Flow Branch"),
    COMPLEXITY_RING("✵", "Cyclic Complexity Anchor"),
    FUNC_NODE("✺", "Function Scope"),
    NEBULA("░", "Code Density Field")
}

data class CelestialNode(
    val id: Int,
    val type: StarType,
    val x: Int,
    val y: Int,
    val connections: MutableList<Int> = mutableListOf(),
    val magnitude: Double = 1.0
)

class AstrolabeRenderer(val width: Int = 80, val height: Int = 40) {
    private val canvas = Array(height) { CharArray(width) { ' ' } }
    private val astrolabeBorders = mapOf(
        "N" to "▲", "S" to "▼", "E" to "►", "W" to "◄",
        "CENTER" to "☉", "RING" to "○", "CROSS" to "┼"
    )

    fun render(code: String): String {
        val nodes = analyzeCodeToStars(code)
        drawAstrolabeFrame()
        drawConstellations(nodes)
        return canvas.joinToString("\n") { String(it) }
    }

    private fun analyzeCodeToStars(code: String): List<CelestialNode> {
        val nodes = mutableListOf<CelestialNode>()
        val lines = code.lines()
        var currentScope = 0
        val center X = width / 2
        val centerY = height / 2

        lines.forEachIndexed { lineIdx, line ->
            val angle = (lineIdx.toDouble() / lines.size.coerceAtLeast(1)) * 2 * Math.PI
            val baseRadius = 8 + (lineIdx % 12)

            // Detect Control Flow
            if (line.contains("if") || line.contains("for") || line.contains("while") || line.contains("switch")) {
                val x = (centerX + (baseRadius + 2) * cos(angle)).toInt().coerceIn(2, width - 3)
                val y = (centerY + (baseRadius / 2 + 1) * sin(angle)).toInt().coerceIn(2, height - 3)
                nodes.add(CelestialNode(nodes.size, StarType.BRANCH, x, y, magnitude = 1.5))
            }

            // Detect Memory Allocations
            if (line.contains("malloc") || line.contains("calloc") || line.contains("new") || line.contains("struct")) {
                val x = (centerX + (baseRadius - 3) * cos(angle + 0.5)).toInt().coerceIn(2, width - 3)
                val y = (centerY + ((baseRadius - 3) / 2) * sin(angle + 0.5)).toInt().coerceIn(2, height - 3)
                nodes.add(CelestialNode(nodes.size, StarType.ALLOCATION, x, y, magnitude = 2.0))
            }

            // Track Cyclomatic Complexity (Braces / Nesting)
            val openBraces = line.count { it == '{' }
            val closeBraces = line.count { it == '}' }
            currentScope += openBraces - closeBraces

            if (currentScope > 2) {
                val ringRadius = (currentScope * 3).coerceAtMost(height / 2 - 2)
                val x = (centerX + ringRadius * cos(angle * 2)).toInt().coerceIn(2, width - 3)
                val y = (centerY + (ringRadius / 2) * sin(angle * 2)).toInt().coerceIn(2, height - 3)
                nodes.add(CelestialNode(nodes.size, StarType.COMPLEXITY_RING, x, y, magnitude = currentScope.toDouble()))
            }
        }

        // Generate Control Flow Constellation Edges
        for (i in 0 until nodes.size - 1) {
            if (abs(nodes[i].x - nodes[i + 1].x) < 25) {
                nodes[i].connections.add(nodes[i + 1].id)
            }
        }

        return nodes
    }

    private fun drawAstrolabeFrame() {
        val cx = width / 2
        val cy = height / 2

        // Draw Outer Astrolabe Ring & Axis
        for (y in 0 until height) {
            for (x in 0 until width) {
                val dx = (x - cx).toDouble()
                val dy = (y - cy).toDouble() * 2.0 // Adjust aspect ratio
                val dist = Math.sqrt(dx * dx + dy * dy)

                if (dist > 18.0 && dist < 19.5) {
                    canvas[y][x] = '◯'
                } else if (x == cx && y % 4 == 0) {
                    canvas[y][x] = '│'
                } else if (y == cy && x % 8 == 0) {
                    canvas[y][x] = '─'
                }
            }
        }

        // Astrolabe Cardinal Markers
        if (cy - 10 >= 0) canvas[cy - 10][cx] = '▲'
        if (cy + 10 < height) canvas[cy + 10][cx] = '▼'
        if (cx - 19 >= 0) canvas[cy][cx - 19] = '◄'
        if (cx + 19 < width) canvas[cy][cx + 19] = '►'
        canvas[cy][cx] = '☸'
    }

    private fun drawConstellations(nodes: List<CelestialNode>) {
        val nodeMap = nodes.associateBy { it.id }

        // Draw Lines (Constellation Paths)
        for (node in nodes) {
            for (targetId in node.connections) {
                val target = nodeMap[targetId] ?: continue
                drawLine(node.x, node.y, target.x, target.y)
            }
        }

        // Draw Star Nodes
        for (node in nodes) {
            val charToDraw = node.type.symbol[0]
            if (node.y in 0 until height && node.x in 0 until width) {
                canvas[node.y][node.x] = charToDraw
            }
        }
    }

    private fun drawLine(x0: Int, y0: Int, x1: Int, y1: Int) {
        var x = x0
        var y = y0
        val dx = abs(x1 - x0)
        val dy = abs(y1 - y0)
        val sx = if (x0 < x1) 1 else -1
        val sy = if (y0 < y1) 1 else -1
        var err = dx - dy

        while (true) {
            if (y in 0 until height && x in 0 until width) {
                if (canvas[y][x] == ' ') {
                    canvas[y][x] = '·'
                }
            }
            if (x == x1 && y == y1) break
            val e2 = 2 * err
            if (e2 > -dy) {
                err -= dy
                x += sx
            }
            if (e2 < dx) {
                err += dx
                y += sy
            }
        }
    }
}

fun main() {
    val sampleCSourceCode = """
        #include <stdio.h>
        #include <stdlib.h>

        typedef struct Node {
            int data;
            struct Node* next;
        } Node;

        Node* create_node(int val) {
            Node* ptr = (Node*)malloc(sizeof(Node));
            if (!ptr) return NULL;
            ptr->data = val;
            ptr->next = NULL;
            return ptr;
        }

        void process_list(Node* head) {
            Node* curr = head;
            while (curr != NULL) {
                if (curr->data % 2 == 0) {
                    for (int i = 0; i < curr->data; i++) {
                        printf("Even index depth execution: %d\n", i);
                    }
                } else {
                    if (curr->data > 100) {
                        void* buffer = calloc(10, sizeof(int));
                        free(buffer);
                    }
                }
                curr = curr->next;
            }
        }

        int main() {
            Node* root = create_node(42);
            process_list(root);
            return 0;
        }
    """.trimIndent()

    val renderer = AstrolabeRenderer(width = 78, height = 36)
    val starChart = renderer.render(sampleCSourceCode)

    println("=============================================================================")
    println("              ASTROLABE GENERATIVE STAR CHART RENDERER                       ")
    println("=============================================================================")
    println(starChart)
    println("=============================================================================")
    println(" Legend: ✦ Branch  ✧ Allocation  ✵ Complexity Ring  · Constellation Line     ")
    println("=============================================================================")
}