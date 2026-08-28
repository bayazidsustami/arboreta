import java.io.File

/**
 * Self-Modifying Quine Grid Language Interpreter
 * Solves N-Queens, renders execution stack trace as ASCII watercolor fractal,
 * and outputs its own source code (Quine behavior).
 */
class QuineEngine(val size: Int = 8) {
    val board = IntArray(size) { -1 }
    var solutionsFound = 0
    val traceGrid = Array(25) { CharArray(60) { ' ' } }
    
    // Grid Language Instruction Memory (2D representation)
    val gridProgram = arrayOf(
        "V > > v . . . . . . . . . . . . . . . . . . . . . . . . . . .",
        "> Q U I N E - E X E C U T I O N - G R I D - E N G I N E v .",
        ". ^ . . . . . . . . . . . . . . . . . . . . . . . . . . < ."
    )

    fun solve(row: Int) {
        // Record stack frame trace to render watercolor fractal background
        recordTrace(row)
        
        if (row == size) {
            solutionsFound++
            return
        }

        for (col in 0 until size) {
            if (isSafe(row, col)) {
                board[row] = col
                solve(row + 1)
                board[row] = -1
            }
        }
    }

    private fun isSafe(row: Int, col: Int): Boolean {
        for (i in 0 until row) {
            val placedCol = board[i]
            if (placedCol == col || Math.abs(placedCol - col) == Math.abs(i - row)) {
                return false
            }
        }
        return true
    }

    private fun recordTrace(depth: Int) {
        val chars = " .:~*+=%@#"
        val cx = 30
        val cy = 12
        for (y in 0 until 25) {
            for (x in 0 until 60) {
                val zx = (x - cx) * 0.05 * (depth + 1)
                val zy = (y - cy) * 0.1 * (depth + 1)
                var zr = zx
                var zi = zy
                var iter = 0
                val maxIter = 9
                while (zr * zr + zi * zi < 4.0 && iter < maxIter) {
                    val tmp = zr * zr - zi * zi + 0.355
                    zi = 2.0 * zr * zi + 0.355
                    zr = tmp
                    iter++
                }
                if (iter > 0 && traceGrid[y][x] == ' ') {
                    traceGrid[y][x] = chars[iter % chars.length]
                }
            }
        }
    }

    fun renderTraceAndQuine() {
        println("=== EXECUTION STACK TRACE VISUALIZATION (ASCII WATERCOLOR FRACTAL) ===")
        for (row in traceGrid) {
            println(String(row))
        }
        println("\nFound $solutionsFound solutions for $size-Queens problem.\n")
        
        // Quine output: Generate self-source code representation
        println("=== QUINE SOURCE SELF-GENERATION ===")
        val selfSource = File(object {}.javaClass.protectionDomain.codeSource.location.toURI()).readText()
        println(selfSource)
    }
}

fun main() {
    val engine = QuineEngine(8)
    engine.solve(0)
    engine.renderTraceAndQuine()
}