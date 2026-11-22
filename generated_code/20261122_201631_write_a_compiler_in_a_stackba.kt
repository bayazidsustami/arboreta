import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

// Stack-based esoteric language "FOLD":
// '#' push literal digit/int, '+' add, '*' mul, ':' dup, '~' swap, '.' output trace event, '^' fold step.

data class TraceEvent(
    val step: Int,
    val op: Char,
    val stackSnapshot: List<Int>,
    val value: Int
)

data class Crease(
    val id: Int,
    val x1: Double,
    val y1: Double,
    val x2: Double,
    val y2: Double,
    val type: String, // "M" (mountain) or "V" (valley)
    val angleRad: Double,
    val torque: Double
)

data class ShadowProjection(
    val lightAngleDeg: Double,
    val stepIndex: Int,
    val encodedValue: Int,
    val shadowX: Double,
    val shadowY: Double,
    val shadowLength: Double
)

fun compileFoldToOrigami(source: String): Triple<List<TraceEvent>, List<Crease>, List<ShadowProjection>> {
    val stack = ArrayDeque<Int>()
    val trace = mutableListOf<TraceEvent>()
    var i = 0
    var stepCount = 0

    // Execute stack-based source code and record execution trace
    while (i < source.length) {
        val ch = source[i]
        when {
            ch.isWhitespace() -> {
                i++
                continue
            }
            ch == '#' -> {
                val start = i + 1
                var end = start
                if (end < source.length && (source[end] == '-' || source[end].isDigit())) {
                    end++
                    while (end < source.length && source[end].isDigit()) end++
                }
                check(end > start) { "Invalid literal at index $i" }
                val lit = source.substring(start, end).toInt()
                stack.addLast(lit)
                stepCount++
                trace += TraceEvent(stepCount, '#', stack.toList(), lit)
                i = end
            }
            ch == '+' -> {
                check(stack.size >= 2) { "Stack underflow on '+' at index $i" }
                val b = stack.removeLast()
                val a = stack.removeLast()
                val res = a + b
                stack.addLast(res)
                stepCount++
                trace += TraceEvent(stepCount, '+', stack.toList(), res)
                i++
            }
            ch == '*' -> {
                check(stack.size >= 2) { "Stack underflow on '*' at index $i" }
                val b = stack.removeLast()
                val a = stack.removeLast()
                val res = a * b
                stack.addLast(res)
                stepCount++
                trace += TraceEvent(stepCount, '*', stack.toList(), res)
                i++
            }
            ch == ':' -> {
                check(stack.isNotEmpty()) { "Stack underflow on ':' at index $i" }
                val top = stack.last()
                stack.addLast(top)
                stepCount++
                trace += TraceEvent(stepCount, ':', stack.toList(), top)
                i++
            }
            ch == '~' -> {
                check(stack.size >= 2) { "Stack underflow on '~' at index $i" }
                val b = stack.removeLast()
                val a = stack.removeLast()
                stack.addLast(b)
                stack.addLast(a)
                stepCount++
                trace += TraceEvent(stepCount, '~', stack.toList(), b)
                i++
            }
            ch == '.' || ch == '^' -> {
                check(stack.isNotEmpty()) { "Stack underflow on '$ch' at index $i" }
                val top = stack.last()
                stepCount++
                trace += TraceEvent(stepCount, ch, stack.toList(), top)
                i++
            }
            else -> error("Unexpected token '$ch' at index $i")
        }
    }

    // Generate self-balancing origami crease pattern where opposing creases offset torque around origin (0,0)
    val n = trace.size.coerceAtLeast(1)
    val creases = mutableListOf<Crease>()
    var cumulativeTorque = 0.0

    trace.forEachIndexed { idx, ev ->
        val baseAngle = (2.0 * PI * idx) / n
        val radius = 40.0 + ((ev.value.coerceAtLeast(-50) + 50) % 60)
        val rawTorque = radius * sin(baseAngle) * if (idx % 2 == 0) 1.0 else -1.0

        // Counter-balance torque so net moment stays near equilibrium
        val balancingCorrection = -cumulativeTorque * 0.5
        val adjustedTorque = rawTorque + balancingCorrection
        cumulativeTorque += adjustedTorque

        val creaseType = if (adjustedTorque >= 0.0) "M" else "V"
        val cx = cos(baseAngle) * 120.0
        val cy = sin(baseAngle) * 120.0
        val dx = cos(baseAngle + PI / 2.0) * (radius * 0.5)
        val dy = sin(baseAngle + PI / 2.0) * (radius * 0.5)

        creases += Crease(
            id = idx + 1,
            x1 = cx - dx,
            y1 = cy - dy,
            x2 = cx + dx,
            y2 = cy + dy,
            type = creaseType,
            angleRad = baseAngle,
            torque = adjustedTorque
        )
    }

    // Compute 3D folded shadow cast by a rotating light source encoding each trace step
    val shadows = trace.mapIndexed { idx, ev ->
        val lightAngleDeg = (360.0 * idx) / n
        val theta = lightAngleDeg * PI / 180.0
        val foldElevationZ = 15.0 + (idx + 1) * 6.0 // 3D folded facet height
        val encodedMagnitude = kotlin.math.abs(ev.value) + ev.op.code * 0.1
        val projFactor = cos(theta) * 0.65 + sin(theta) * 0.35
        val shadowX = (idx - n / 2.0) * 18.0 + cos(theta) * foldElevationZ
        val shadowY = sin(theta) * foldElevationZ + (ev.stackSnapshot.size * 7.5)
        val shadowLength = 12.0 + (encodedMagnitude % 45.0) * (0.4 + 0.6 * kotlin.math.abs(projFactor))

        ShadowProjection(
            lightAngleDeg = lightAngleDeg,
            stepIndex = ev.step,
            encodedValue = ev.value,
            shadowX = shadowX,
            shadowY = shadowY,
            shadowLength = shadowLength
        )
    }

    return Triple(trace, creases, shadows)
}

fun renderOrigamiAndShadowSvg(creases: List<Crease>, shadows: List<ShadowProjection>): String {
    val sb = StringBuilder()
    sb.appendLine("""<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="-200 -200 400 400" width="400" height="400">""")
    sb.appendLine("""  <rect x="-200" y="-200" width="400" height="400" fill="#faf7f0"/>""")
    sb.appendLine("""  <circle cx="0" cy="0" r="150" fill="none" stroke="#d8d0c0" stroke-dasharray="4 4"/>""")

    for (c in creases) {
        val strokeColor = if (c.type == "M") "#c0392b" else "#2471a3"
        val dash = if (c.type == "M") "" else """ stroke-dasharray="5 3""""
        sb.appendLine(
            """  <line x1="${"%.1f".format(c.x1)}" y1="${"%.1f".format(c.y1)}" x2="${"%.1f".format(c.x2)}" y2="${"%.1f".format(c.y2)}" stroke="$strokeColor" stroke-width="2"$dash/>"""
        )
    }

    for (s in shadows) {
        val rad = s.lightAngleDeg * PI / 180.0
        val sx2 = s.shadowX + cos(rad) * s.shadowLength
        val sy2 = s.shadowY + sin(rad) * s.shadowLength
        sb.appendLine(
            """  <line x1="${"%.1f".format(s.shadowX)}" y1="${"%.1f".format(s.shadowY)}" x2="${"%.1f".format(sx2)}" y2="${"%.1f".format(sy2)}" stroke="#2c3e50" stroke-opacity="0.55" stroke-width="3"/>"""
        )
    }

    sb.appendLine("</svg>")
    return sb.toString()
}

fun main() {
    val program = "#3 #4 + : * #2 ~ . ^"
    val (trace, creases, shadows) = compileFoldToOrigami(program)

    println("=== FOLD EXECUTION TRACE ===")
    for (t in trace) {
        println("Step ${t.step}: op='${t.op}' val=${t.value} stack=${t.stackSnapshot}")
    }

    val netTorque = creases.sumOf { it.torque }
    println("\n=== SELF-BALANCING CREASE PATTERN (Net Torque: ${"%.4f".format(netTorque)}) ===")
    for (c in creases) {
        println(
            "Crease #${c.id} [${c.type}]: (${ "%.1f".format(c.x1) }, ${ "%.1f".format(c.y1) }) -> " +
                "(${ "%.1f".format(c.x2) }, ${ "%.1f".format(c.y2) }) torque=${ "%.2f".format(c.torque) }"
        )
    }

    println("\n=== ROTATING LIGHT SHADOW TRACE ENCODING ===")
    for (s in shadows) {
        println(
            "Light ${"%.1f".format(s.lightAngleDeg)} deg | Trace Step ${s.stepIndex} (val=${s.encodedValue}) -> " +
                "Shadow anchor=(${ "%.1f".format(s.shadowX) }, ${ "%.1f".format(s.shadowY) }) len=${ "%.1f".format(s.shadowLength) }"
        )
    }

    println("\n=== SVG OUTPUT ===")
    print(renderOrigamiAndShadowSvg(creases, shadows))
}