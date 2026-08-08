import java.util.Locale
import kotlin.math.*

/**
 * Esoteric Stained-Glass File Archiver & Encoder/Decoder
 *
 * Encodes arbitrary binary data into visually harmonious SVG Rose Window stained-glass patterns.
 * Data mapping per glass polygon tile (5 bytes per tile):
 *   - Bytes 0..2 : RGB Color Palette (Fill Color)
 *   - Byte 3     : Line Weight / Lead Came Thickness (Stroke Width)
 *   - Byte 4     : Tile Geometry Perturbation (Radial Outer Vertex Displacement)
 */
object StainedGlassArchiver {

    private const val CX = 500.0
    private const val CY = 500.0

    // Calculate ring index and sector layout for a given tile index
    private fun getTileGeometryParams(tileIndex: Int): Triple<Int, Int Int,> {
        var remaining = tileIndex
        var ring = 0
        while (true) {
            val sectorsInRing = 12 + ring * 6
            if (remaining < sectorsInRing) {
                return Triple(ring, remaining, sectorsInRing)
            }
            remaining -= sectorsInRing
            ring++
        }
    }

    /**
     * Losslessly encodes a byte array into a valid, glowing SVG stained-glass window pattern.
     */
    fun encode(data: ByteArray): String {
        val payloadSize = data.size
        // 4 bytes header for payload size + payload data
        val totalBytes = 4 + payloadSize
        val padding = if (totalBytes % 5 == 0) 0 else 5 - (totalBytes % 5)
        val paddedSize = totalBytes + padding

        val buffer = ByteArray(paddedSize)
        // Store Big-Endian 32-bit integer length header
        buffer[0] = (payloadSize ushr 24).toByte()
        buffer[1] = (payloadSize ushr 16).toByte()
        buffer[2] = (payloadSize ushr 8).toByte()
        buffer[3] = payloadSize.toByte()

        System.arraycopy(data, 0, buffer, 4, payloadSize)

        val numTiles = paddedSize / 5
        val svgBuilder = StringBuilder()

        // SVG Header & Filters for stained-glass luminescence
        svgBuilder.append("""
            <svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 1000 1000" width="1000" height="1000">
              <defs>
                <radialGradient id="glass-glow" cx="50%" cy="50%" r="50%">
                  <stop offset="0%" stop-color="#ffffff" stop-opacity="0.15"/>
                  <stop offset="70%" stop-color="#000000" stop-opacity="0.4"/>
                  <stop offset="100%" stop-color="#050505" stop-opacity="0.9"/>
                </radialGradient>
                <filter id="lead-emboss" x="-10%" y="-10%" width="120%" height="120%">
                  <feDropShadow dx="1" dy="2" stdDeviation="1.5" flood-color="#000000" flood-opacity="0.8"/>
                </filter>
              </defs>
              <rect width="1000" height="1000" fill="#0c0a09"/>
              <!-- Gothic Arch Outer Frame -->
              <circle cx="$CX" cy="$CY" r="475" fill="none" stroke="#1c1917" stroke-width="24"/>
              <circle cx="$CX" cy="$CY" r="460" fill="none" stroke="#292524" stroke-width="6"/>
              <g id="stained-glass-panes" filter="url(#lead-emboss)">
        """.trimIndent()).append("\n")

        // Build stained glass tiles encoding data
        for (i in 0 until numTiles) {
            val offset = i * 5
            val b0 = buffer[offset].toInt() and 0xFF     // Red
            val b1 = buffer[offset + 1].toInt() and 0xFF // Green
            val b2 = buffer[offset + 2].toInt() and 0xFF // Blue
            val b3 = buffer[offset + 3].toInt() and 0xFF // Stroke Width
            val b4 = buffer[offset + 4].toInt() and 0xFF // Geometry offset

            val (ring, sector, sectorsInRing) = getTileGeometryParams(i)

            val rIn = 40.0 + ring * 65.0
            val rBase = rIn + 50.0
            val rOut = rBase + b4 * 0.20 // Lossless geometry displacement

            val angleStep = (2.0 * PI) / sectorsInRing
            val a1 = sector * angleStep
            val a2 = (sector + 1) * angleStep

            // Four vertices defining the glass polygon wedge
            val x1 = CX + rIn * cos(a1)
            val y1 = CY + rIn * sin(a1)
            val x2 = CX + rIn * cos(a2)
            val y2 = CY + rIn * sin(a2)
            val x3 = CX + rOut * cos(a2)
            val y3 = CY + rOut * sin(a2)
            val x4 = CX + rOut * cos(a1)
            val y4 = CY + rOut * sin(a1)

            val hexColor = String.format("%02X%02X%02X", b0, b1, b2)
            val strokeWidthStr = String.format(Locale.US, "%.2f", 0.80 + b3 * 0.05)
            val pathD = String.format(
                Locale.US,
                "M %.3f,%.3f L %.3f,%.3f L %.3f,%.3f L %.3f,%.3f Z",
                x1, y1, x2, y2, x3, y3, x4, y4
            )

            svgBuilder.append(
                """    <path d="$pathD" fill="#$hexColor" stroke="#12100e" stroke-width="$strokeWidthStr" stroke-linejoin="round" data-tile="$i"/>"""
            ).append("\n")
        }

        // Rosette Center Ornament & Glass Ambient Overlay
        svgBuilder.append("""
              </g>
              <!-- Center Rose Core -->
              <circle cx="$CX" cy="$CY" r="35" fill="#1c1917" stroke="#0c0a09" stroke-width="4"/>
              <circle cx="$CX" cy="$CY" r="28" fill="#d97706" opacity="0.85"/>
              <circle cx="$CX" cy="$CY" r="12" fill="#7c2d12"/>
              <!-- Vignette & Illumination Overlay -->
              <circle cx="$CX" cy="$CY" r="460" fill="url(#glass-glow)" style="mix-blend-mode: multiply;" pointer-events="none"/>
            </svg>
        """.trimIndent())

        return svgBuilder.toString()
    }

    /**
     * Losslessly decodes binary data from a stained-glass SVG pattern string.
     */
    fun decode(svg: String): ByteArray {
        val pathRegex = """<path\s+d="M\s+[\d.-]+,[\d.-]+\s+L\s+[\d.-]+,[\d.-]+\s+L\s+([\d.-]+),([\d.-]+)[^"]*"\s+fill="#([0-9A-Fa-f]{6})"\s+stroke="[^"]*"\s+stroke-width="([\d.]+)"[^>]*/>""".toRegex()
        val matches = pathRegex.findAll(svg).toList()

        val extractedBytes = ByteArray(matches.size * 5)

        for ((i, match) in matches.withIndex()) {
            val (x3Str, y3Str, hexColor, strokeWidthStr) = match.destructured

            // Decode Color Palette (Bytes 0, 1, 2)
            val colorVal = hexColor.toInt(16)
            val b0 = (colorVal ushr 16) and 0xFF
            val b1 = (colorVal ushr 8) and 0xFF
            val b2 = colorVal and 0xFF

            // Decode Line Weight (Byte 3)
            val strokeW = strokeWidthStr.toDouble()
            val b3 = round((strokeW - 0.80) / 0.05).toInt().coerceIn(0, 255)

            // Decode Tile Geometry Offset (Byte 4)
            val x3 = x3Str.toDouble()
            val y3 = y3Str.toDouble()
            val rOut = sqrt((x3 - CX).pow(2) + (y3 - CY).pow(2))

            val (ring, _, _) = getTileGeometryParams(i)
            val rIn = 40.0 + ring * 65.0
            val rBase = rIn + 50.0
            val b4 = round((rOut - rBase) / 0.20).toInt().coerceIn(0, 255)

            val offset = i * 5
            extractedBytes[offset]     = b0.toByte()
            extractedBytes[offset + 1] = b1.toByte()
            extractedBytes[offset + 2] = b2.toByte()
            extractedBytes[offset + 3] = b3.toByte()
            extractedBytes[offset + 4] = b4.toByte()
        }

        // Parse Big-Endian length header
        val payloadSize = ((extractedBytes[0].toInt() and 0xFF) shl 24) or
                          ((extractedBytes[1].toInt() and 0xFF) shl 16) or
                          ((extractedBytes[2].toInt() and 0xFF) shl 8) or
                          (extractedBytes[3].toInt() and 0xFF)

        val payload = ByteArray(payloadSize)
        System.arraycopy(extractedBytes, 4, payload, 0, payloadSize)
        return payload
    }
}

fun main() {
    val sampleMessage = "Esoteric Stained-Glass Archiver: Losslessly encoding bytes into Gothic Rose Windows!"
    val originalData = sampleMessage.toByteArray(Charsets.UTF_8)

    // 1. Encode binary data into SVG Stained Glass
    val svgOutput = StainedGlassArchiver.encode(originalData)

    // 2. Decode SVG back to binary data
    val decodedData = StainedGlassArchiver.decode(svgOutput)
    val restoredMessage = String(decodedData, Charsets.UTF_8)

    // 3. Roundtrip Verification
    val isLossless = originalData.contentEquals(decodedData)

    println("=== STAINED GLASS ESOTERIC ARCHIVER ===")
    println("Original Data Size : ${originalData.size} bytes")
    println("SVG XML Generated  : ${svgOutput.length} characters")
    println("Restored Message   : \"$restoredMessage\"")
    println("Roundtrip Verified : ${if (isLossless) "SUCCESS (100% Lossless)" else "FAILED"}")
}
main()